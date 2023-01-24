use aiken/dict.{Dict}
use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction.{OutputReference}
use aiken/transaction/credential.{Address, VerificationKey}
use aiken/transaction/value.{AssetName, PolicyId, Value}

pub type PublicKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type ListingDetails {
  owner: Address,
  requested_lovelace: Int,
  private_listing: Option<Address>,
}

pub type BiddingDetails {
  owner: Address,
  requested_option: BidOption,
}

// TODO: Fix aiken assert
pub type RoyaltyInfo {
  recipients: List<RoyaltyRecipient>,
}

pub type RoyaltyRecipient {
  address: Address,
  // percentage (fraction)
  fee: Int,
  min_fee: Option<Int>,
  // fixed
  max_fee: Option<Int>,
}

pub type Metadata =
  Dict<ByteArray, Data>

pub type DatumMetadata {
  metadata: Metadata,
  version: Int,
}

pub type TraitOption {
  Included(ByteArray)
  Excluded(ByteArray)
}

pub type BidOption {
  SpecificValue(Value)
  SpecificPolicyIdWithConstraints(PolicyId, List<ByteArray>, List<TraitOption>)
}

pub type RoyaltyToken {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type TradeDatum {
  Listing(ListingDetails)
  Bid(BiddingDetails)
}

pub type TradeAction {
  Sell
  Buy
  Cancel
}

pub type PaymentDatum {
  output_reference: OutputReference,
}
