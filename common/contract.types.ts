import { Data } from "../deps.ts";

const PolicyId = Data.Bytes({ minLength: 28, maxLength: 28 });

export const Credential = Data.Enum([
  Data.Object({
    PublicKeyCredential: Data.Tuple([
      Data.Bytes({ minLength: 28, maxLength: 28 }),
    ]),
  }),
  Data.Object({
    ScriptCredential: Data.Tuple([
      Data.Bytes({ minLength: 28, maxLength: 28 }),
    ]),
  }),
]);
export type Credential = Data.Static<typeof Credential>;

export const Address = Data.Object({
  paymentCredential: Credential,
  stakeCredential: Data.Nullable(Data.Enum([
    Data.Object({ Inline: Data.Tuple([Credential]) }),
    Data.Object({
      Pointer: Data.Tuple([Data.Object({
        slotNumber: Data.Integer(),
        transactionIndex: Data.Integer(),
        certificateIndex: Data.Integer(),
      })]),
    }),
  ])),
});
export type Address = Data.Static<typeof Address>;

export const Value = Data.Map(
  PolicyId,
  Data.Map(Data.Bytes(), Data.Integer()),
);
export type Value = Data.Static<typeof Value>;

export const TraitOption = Data.Enum([
  Data.Object({ Included: Data.Tuple([Data.Bytes()]) }),
  Data.Object({ Excluded: Data.Tuple([Data.Bytes()]) }),
]);
export type TraitOption = Data.Static<typeof TraitOption>;

export const BidOption = Data.Enum([
  Data.Object({ SpecificValue: Data.Tuple([Value]) }),
  Data.Object({
    SpecificSymbolWithConstraints: Data.Tuple([
      PolicyId,
      Data.Array(Data.Bytes()),
      Data.Array(TraitOption),
    ]),
  }),
]);
export type BidOption = Data.Static<typeof BidOption>;

export const OutRef = Data.Object({
  txHash: Data.Object({ hash: Data.Bytes({ minLength: 32, maxLength: 32 }) }),
  outputIndex: Data.Integer(),
});
export type OutRef = Data.Static<typeof OutRef>;

export const ListingDetails = Data.Object({
  owner: Address,
  requestedLovelace: Data.Integer(),
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
  fee: Data.Integer({ minimum: 1 }),
  minFee: Data.Nullable(Data.Integer()),
  maxFee: Data.Nullable(Data.Integer()),
});
export type RoyaltyRecipient = Data.Static<typeof RoyaltyRecipient>;

export const RoyaltyInfo = Data.Object({
  recipients: Data.Array(RoyaltyRecipient),
  version: Data.Integer({ minimum: 1, maximum: 1 }),
  extra: Data.Any(),
});
export type RoyaltyInfo = Data.Static<typeof RoyaltyInfo>;

export const RoyaltyToken = Data.Object({
  policyId: PolicyId,
  assetName: Data.Bytes(),
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
  Data.Nullable(Data.Bytes({ minLength: 28, maxLength: 28 })),
  RoyaltyToken,
]);
export type TradeParams = Data.Static<typeof TradeParams>;
