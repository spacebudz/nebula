import { Data } from "../deps.js";
export const Credential = Data.Enum([
    Data.Object({ PublicKeyCredential: Data.Tuple([Data.String]) }),
    Data.Object({ ScriptCredential: Data.Tuple([Data.String]) }),
]);
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
export const Value = Data.Map(Data.String, Data.Map(Data.String, Data.BigInt));
export const BidOption = Data.Enum([
    Data.Object({ SpecificValue: Data.Tuple([Value]) }),
    Data.Object({
        SpecificSymbolWithConstraints: Data.Tuple([
            Data.String,
            Data.Array(Data.String),
            Data.Array(Data.Tuple([Data.BigInt, Data.String])),
        ]),
    }),
]);
export const OutRef = Data.Object({
    txHash: Data.Object({ hash: Data.String }),
    outputIndex: Data.BigInt,
});
export const ListingDetails = Data.Object({
    owner: Address,
    requestedLovelace: Data.BigInt,
    privateListing: Data.Nullable(Address),
});
export const BiddingDetails = Data.Object({
    owner: Address,
    requestedOption: BidOption,
});
export const RoyaltyRecipient = Data.Object({
    address: Address,
    fee: Data.BigInt,
    fixedFee: Data.BigInt,
});
export const RoyaltyInfo = Data.Object({
    recipients: Data.Array(RoyaltyRecipient),
    minAda: Data.BigInt,
});
export const RoyaltyToken = Data.Tuple([Data.String, Data.String]);
export const PaymentDatum = Data.Object({
    outRef: OutRef,
});
export const TradeAction = Data.Enum([
    Data.Literal("Sell"),
    Data.Literal("Buy"),
    Data.Literal("Cancel"),
]);
export const TradeDatum = Data.Enum([
    Data.Object({ Listing: Data.Tuple([ListingDetails]) }),
    Data.Object({ Bid: Data.Tuple([BiddingDetails]) }),
]);
export const TradeParams = Data.Tuple([
    Data.Nullable(Data.String),
    Data.Tuple([Data.String, Data.String]),
    Data.String,
    RoyaltyToken,
]);
