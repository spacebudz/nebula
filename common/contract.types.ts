import { Data } from "../deps.ts";

export const Credential = Data.Enum([
  Data.Object({ PublicKeyCredential: Data.Tuple([Data.String]) }),
  Data.Object({ ScriptCredential: Data.Tuple([Data.String]) }),
]);
export type Credential = Data.Static<typeof Credential>;

export const Address = Data.Object({
  paymentCredential: Credential,
  stakeCredential: Data.Nullable(Data.Enum([
    Data.Object({ Inline: Data.Tuple([Credential]) }),
    Data.Object({
      Pointer: Data.Tuple([Data.Object({
        slotNumber: Data.BigInt,
        transactionIndex: Data.BigInt,
        certificateIndex: Data.BigInt,
      })]),
    }),
  ])),
});
export type Address = Data.Static<typeof Address>;

export const Value = Data.Map(Data.String, Data.Map(Data.String, Data.BigInt));
export type Value = Data.Static<typeof Value>;

export const TraitOption = Data.Enum([
  Data.Object({ Included: Data.Tuple([Data.String]) }),
  Data.Object({ Excluded: Data.Tuple([Data.String]) }),
]);
export type TraitOption = Data.Static<typeof TraitOption>;

export const BidOption = Data.Enum([
  Data.Object({ SpecificValue: Data.Tuple([Value]) }),
  Data.Object({
    SpecificSymbolWithConstraints: Data.Tuple([
      Data.String,
      Data.Array(Data.String),
      Data.Array(TraitOption),
    ]),
  }),
]);
export type BidOption = Data.Static<typeof BidOption>;

export const OutRef = Data.Object({
  txHash: Data.Object({ hash: Data.String }),
  outputIndex: Data.BigInt,
});
export type OutRef = Data.Static<typeof OutRef>;

export const ListingDetails = Data.Object({
  owner: Address,
  requestedLovelace: Data.BigInt,
  privateListing: Data.Nullable(Address),
});
export type ListingDetails = Data.Static<typeof ListingDetails>;

export const BiddingDetails = Data.Object({
  owner: Address,
  requestedOption: BidOption,
});
export type BiddingDetails = Data.Static<typeof BiddingDetails>;

export const RoyaltyRecipient = Data.Object({
  address: Address,
  fee: Data.BigInt,
  maxFee: Data.Nullable(Data.BigInt),
});
export type RoyaltyRecipient = Data.Static<typeof RoyaltyRecipient>;

export const RoyaltyInfo = Data.Object({
  recipients: Data.Array(RoyaltyRecipient),
});
export type RoyaltyInfo = Data.Static<typeof RoyaltyInfo>;

export const RoyaltyToken = Data.Object({
  policyId: Data.String,
  assetName: Data.String,
});
export type RoyaltyToken = Data.Static<typeof RoyaltyToken>;

export const PaymentDatum = Data.Object({
  outRef: OutRef,
});
export type PaymentDatum = Data.Static<typeof PaymentDatum>;

export const TradeAction = Data.Enum([
  Data.Literal("Sell"),
  Data.Literal("Buy"),
  Data.Literal("Cancel"),
]);
export type TradeAction = Data.Static<typeof TradeAction>;

export const TradeDatum = Data.Enum([
  Data.Object({ Listing: Data.Tuple([ListingDetails]) }),
  Data.Object({ Bid: Data.Tuple([BiddingDetails]) }),
]);
export type TradeDatum = Data.Static<typeof TradeDatum>;

export const TradeParams = Data.Tuple([
  Data.Nullable(Data.String),
  RoyaltyToken,
]);
export type TradeParams = Data.Static<typeof TradeParams>;
