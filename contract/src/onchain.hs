module Onchain (tradeSerialized, oneShotSerialized) where

import Cardano.Api
import Cardano.Api.Shelley (PlutusScript (..))
import Codec.Serialise (serialise)
import qualified Data.ByteString.Base16 as B16
import qualified Data.ByteString.Char8 as C
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString.Short as SBS
import qualified Plutus.Script.Utils.V2.Scripts as Scripts
import qualified Plutus.Script.Utils.V2.Typed.Scripts.Validators as Scripts
import qualified Plutus.Script.Utils.V2.Typed.Scripts.MonetaryPolicies as Scripts
import qualified Plutus.V2.Ledger.Api as Api
import Plutus.V2.Ledger.Contexts as Api
import Plutus.V1.Ledger.Value as V
import Ledger.Value as V
import qualified PlutusTx
import PlutusTx.Prelude
import Prelude (String)
import qualified PlutusTx.AssocMap as M

-- | Data and Redeemer ------------------------------------------------------------------

data ListingDetails = ListingDetails {
                        ldOwner               :: Owner
                      , requestedLovelace     :: Integer
                      , privateListing        :: Maybe Owner
}

data BiddingDetails = BiddingDetails {
                        bdOwner               :: Owner
                      , requestedOption       :: BidOption
}

data RoyaltyInfo = RoyaltyInfo {
                        recipients            :: [RoyaltyRecipient]
                      , minAda                :: Integer -- The threshold that decides to pay fee as percentage or fixed.
}

data RoyaltyRecipient = RoyaltyRecipient {
                        recipient             :: Api.Address
                      , fee                   :: Integer -- Percentage
                      , fixedFee              :: Integer -- Fallback fixed amount in case percentage is below minimum ada requirement  
}

type Metadata = M.Map BuiltinByteString BuiltinData
data DatumMetadata = DatumMetadata {
                        metadata              :: Metadata
                      , version               :: Integer
}

-- | Example SpaceBudz metadata:
-- {
--   image: "ipfs://...",
--   name: "SpaceBud #...",
--   traits: [
--     "Chestplate"
--   ],
--   type: "Cat",
--   imageHash: "<sha256>"
-- }

data BidOption = SpecificValue V.Value | SpecificSymbolWithConstraints Api.CurrencySymbol [BuiltinByteString] [(Integer, BuiltinByteString)]

type Owner = Api.Address

type RoyaltyToken = V.AssetClass

data TradeDatum = Listing ListingDetails | Bid BiddingDetails

data TradeAction = Sell | Buy | Cancel

data PaymentDatum = PaymentDatum Api.TxOutRef

labelLength = 4

type Label = BuiltinByteString

-- | Validators ------------------------------------------------------------------

{-# INLINEABLE tradeValidate #-}
tradeValidate :: Maybe Api.PubKeyHash -> (BuiltinByteString, BuiltinByteString) -> Label -> RoyaltyToken -> TradeDatum -> TradeAction -> Api.ScriptContext -> Bool
tradeValidate protocolKey (typeKey, traitsKey) label100 royaltyToken datum action ctx = case datum of
  Bid biddingDetails               -> case action of
    Sell        -> paidFeeAndValue
    Cancel      -> txSignedByAddress txInfo ownValue (bdOwner biddingDetails) 

  Listing listingDetails  -> case action of
    Buy         -> checkedPrivateListing listingDetails && paidFeeAndValue 
    Cancel      -> txSignedByAddress txInfo ownValue (ldOwner listingDetails)
   
  where
    txInfo :: Api.TxInfo
    txInfo = Api.scriptContextTxInfo ctx

    txRefInputs :: [Api.TxInInfo]
    txRefInputs = Api.txInfoReferenceInputs txInfo

    ownValue :: V.Value
    ownOutRef :: Api.TxOutRef
    (ownValue, ownOutRef) = let 
                                Just i = Api.findOwnInput ctx
                                out = txInInfoResolved i
                                ref = txInInfoOutRef i
                            in  (txOutValue out, ref)

    checkedPrivateListing :: ListingDetails -> Bool
    checkedPrivateListing ld = case privateListing ld of 
                                Just owner -> txSignedByAddress txInfo ownValue owner 
                                Nothing -> True

    paidFeeAndValue :: Bool
    paidFeeAndValue = let
                        acceptedLovelace = case datum of
                          Bid _ -> V.valueOf ownValue V.adaSymbol V.adaToken
                          Listing tradeDetails -> requestedLovelace tradeDetails

                        [royaltyInput] = filter (\Api.TxInInfo {txInInfoResolved=r} -> V.assetClassValueOf (txOutValue r) royaltyToken == 1) txRefInputs

                        refOut = txInInfoResolved royaltyInput
                        
                        royaltyInfo = let (Api.OutputDatum (Api.Datum d)) = txOutDatum refOut in case PlutusTx.fromBuiltinData d of
                                        Just m -> m :: RoyaltyInfo

                        paymentDatum = Api.Datum (PlutusTx.toBuiltinData (PaymentDatum ownOutRef))

                        paidFee :: [RoyaltyRecipient] -> Integer -> Either () Integer 
                        paidFee [] l = Right l
                        paidFee (royalty:remainingRoyalties) lovelace = let 
                                                                          feeToPay = (acceptedLovelace * 10) `divide` fee royalty
                                                                          adjustedFee = if feeToPay < minAda royaltyInfo then fixedFee royalty else feeToPay
                                                                          newLovelace = lovelace - adjustedFee
                                                                        in
                                                                          if 
                                                                            V.valueOf (valuePaidToAddressWithData txInfo paymentDatum (recipient royalty)) V.adaSymbol V.adaToken >= adjustedFee && 
                                                                            newLovelace > 0
                                                                            then
                                                                              paidFee remainingRoyalties (newLovelace)
                                                                            else
                                                                              Left ()
                      in
                        (case protocolKey of Just key -> any (\output -> case txOutAddress output of Api.Address (Api.PubKeyCredential key') _ -> key == key'; _ -> False) (txInfoOutputs txInfo); _ -> True) &&
                        -- | Check if lovelace or NFT were paid to owner and fees were paid.
                        case paidFee (recipients royaltyInfo) acceptedLovelace of
                          Right remainingLovelace -> case datum of
                            Bid biddingDetails -> case requestedOption biddingDetails of
                                                    SpecificValue v -> V.noAdaValue (valuePaidToAddressWithData txInfo paymentDatum (bdOwner biddingDetails)) == V.noAdaValue v
                                                    SpecificSymbolWithConstraints cs sTypes sTraits -> let 
                                                                                                      v = valuePaidToAddressWithData txInfo paymentDatum (bdOwner biddingDetails)
                                                                                                      [(sellCs, sellTn, _)] = filter (\(cs',_,_) -> cs' == cs) (V.flattenValue v)

                                                                                                      -- | Metadata in projects can vary and projects may not use CIP-0068, which makes this feature unusable.
                                                                                                      [metadataInput] = filter (\Api.TxInInfo {txInInfoResolved=r} -> V.assetClassValueOf (txOutValue r) (V.AssetClass (sellCs, Api.TokenName(label100 <> dropByteString labelLength (unTokenName sellTn)))) == 1) txRefInputs
                                                                                                      datumMetadata = let (Api.OutputDatumHash h) = txOutDatum (txInInfoResolved metadataInput) in 
                                                                                                        case findDatum h txInfo of
                                                                                                          Just (Api.Datum d) -> case PlutusTx.fromBuiltinData d of
                                                                                                            Just m -> m :: DatumMetadata
                                                                                                      mType = let Just rawType = M.lookup typeKey (metadata datumMetadata) in (PlutusTx.unsafeFromBuiltinData rawType) :: BuiltinByteString
                                                                                                      mTraits = let Just rawTraits = M.lookup traitsKey (metadata datumMetadata) in (PlutusTx.unsafeFromBuiltinData rawTraits) :: [BuiltinByteString]
                                                                                                    in
                                                                                                      (case sTypes of [] -> True; _ -> any (\s -> mType == s) sTypes) &&
                                                                                                      all (\(negation, t) -> if negation == -1 then not (any (\t' -> t == t') mTraits) else any (\t' -> t == t') mTraits) sTraits &&
                                                                                                      sellCs == cs
                            Listing listingDetails -> V.valueOf (valuePaidToAddressWithData txInfo paymentDatum (ldOwner listingDetails)) V.adaSymbol V.adaToken >= remainingLovelace
                       
{-# INLINEABLE oneShotValidate #-}
oneShotValidate :: Api.TxOutRef -> () -> Api.ScriptContext -> Bool
oneShotValidate oref () ctx = Api.spendsOutput txInfo (Api.txOutRefId oref) (Api.txOutRefIdx oref)

  where
    txInfo :: Api.TxInfo
    txInfo = Api.scriptContextTxInfo ctx

-- | Utils ------------------------------------------------------------------

{-# INLINEABLE outputsAtAddressWithInlineDatum #-}
outputsAtAddressWithInlineDatum :: Api.Datum -> Api.Address -> Api.TxInfo -> [V.Value]
outputsAtAddressWithInlineDatum datum address p =
    let flt Api.TxOut{Api.txOutDatum=Api.OutputDatum datum', txOutAddress=address', txOutValue} | address == address' && datum == datum' = Just txOutValue
        flt _ = Nothing
    in mapMaybe flt (Api.txInfoOutputs p)

-- | We only keep track of the very first output filtered by a specific datum. The goal is to have a unique output.
-- This way we can save costs and also pretend bad actors from splitting outputs arbitrarily.   
{-# INLINABLE valuePaidToAddressWithData #-}
valuePaidToAddressWithData :: Api.TxInfo -> Api.Datum -> Api.Address -> V.Value
valuePaidToAddressWithData ptx datum address = let [v] = (outputsAtAddressWithInlineDatum datum address ptx) in v

{-# INLINABLE txSignedByAddress #-}
txSignedByAddress :: Api.TxInfo -> Api.Value -> Api.Address -> Bool
-- | Check if a transaction was signed by the given public key address.
txSignedByAddress Api.TxInfo{txInfoSignatories} _ (Api.Address (Api.PubKeyCredential k) _) = case find ((==) k) txInfoSignatories of
    Just _  -> True
    Nothing -> False
-- | Check if a transaction was signed by the given script address. The script input needs to contain a special token with the asset name 'ScriptOwner'.
-- The minting policy of this asset contains arbitrary logic. Whoever is able to to burn this asset following the validator rules can unlock the UTxO and cancel the bid/listing.
-- Note: We have to make sure there is only ONE asset in the output with the asset name 'ScriptOwner'!
txSignedByAddress Api.TxInfo{txInfoMint} ownValue (Api.Address (Api.ScriptCredential _) _) = case find(\(_,tn,_) -> tn == Api.TokenName "ScriptOwner") (flattenValue ownValue) of
  Just (cs, tn, _) -> V.valueOf txInfoMint cs tn < 0
  Nothing -> False

-- | Instantiate validators ------------------------------------------------------------------

tradeInstance :: Scripts.Validator
tradeInstance = Api.Validator $ Api.fromCompiledCode ($$(PlutusTx.compile [|| wrap ||]))
  where
    wrap k m l r = Scripts.mkUntypedValidator $ tradeValidate (PlutusTx.unsafeFromBuiltinData k) (PlutusTx.unsafeFromBuiltinData m) (PlutusTx.unsafeFromBuiltinData l) (PlutusTx.unsafeFromBuiltinData r)

oneShotInstance :: Scripts.MintingPolicy
oneShotInstance = Api.MintingPolicy $ Api.fromCompiledCode ($$(PlutusTx.compile [|| wrap ||]))
  where
    wrap oref = Scripts.mkUntypedMintingPolicy $ oneShotValidate (PlutusTx.unsafeFromBuiltinData oref)

-- | Serialization ------------------------------------------------------------------

tradeSerialized :: String
tradeSerialized = C.unpack $ B16.encode $ serialiseToCBOR 
                        ((PlutusScriptSerialised $ SBS.toShort . LBS.toStrict $ serialise $ Api.unValidatorScript tradeInstance) :: PlutusScript PlutusScriptV2)

oneShotSerialized :: String
oneShotSerialized = C.unpack $ B16.encode $ serialiseToCBOR 
                      ((PlutusScriptSerialised $ SBS.toShort . LBS.toStrict $ serialise $ Api.unMintingPolicyScript oneShotInstance) :: PlutusScript PlutusScriptV2)

-- | Lift ------------------------------------------------------------------

PlutusTx.makeLift ''ListingDetails
PlutusTx.makeIsDataIndexed ''ListingDetails [('ListingDetails, 0)]
PlutusTx.makeLift ''BiddingDetails
PlutusTx.makeIsDataIndexed ''BiddingDetails [('BiddingDetails, 0)]
PlutusTx.makeLift ''RoyaltyInfo
PlutusTx.makeIsDataIndexed ''RoyaltyInfo [('RoyaltyInfo, 0)]
PlutusTx.makeLift ''RoyaltyRecipient
PlutusTx.makeIsDataIndexed ''RoyaltyRecipient [('RoyaltyRecipient, 0)]
PlutusTx.makeLift ''TradeDatum
PlutusTx.makeIsDataIndexed ''TradeDatum [('Listing, 0), ('Bid, 1)]
PlutusTx.makeLift ''TradeAction
PlutusTx.makeIsDataIndexed ''TradeAction [('Sell, 0), ('Buy, 1), ('Cancel, 2)]
PlutusTx.makeLift ''PaymentDatum
PlutusTx.makeIsDataIndexed ''PaymentDatum [('PaymentDatum, 0)]
PlutusTx.makeLift ''DatumMetadata
PlutusTx.makeIsDataIndexed ''DatumMetadata [('DatumMetadata, 0)]
PlutusTx.makeLift ''BidOption
PlutusTx.makeIsDataIndexed ''BidOption [('SpecificValue, 0), ('SpecificSymbolWithConstraints, 1)]