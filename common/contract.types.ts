import { Data } from "../deps.ts";

const PolicyId = Data.Bytes(28);

export const Credential = Data.Enum({
  VerificationKeyCredential: [
    Data.Bytes(28),
  ],
}, {
  ScriptCredential: [
    Data.Bytes(28),
  ],
});
export type Credential = typeof Credential;

export const Address = Data.Object({
  paymentCredential: Credential,
  stakeCredential: Data.Nullable(Data.Enum(
    { Inline: [Credential] },
    {
      Pointer: {
        slotNumber: Data.Integer(),
        transactionIndex: Data.Integer(),
        certificateIndex: Data.Integer(),
      },
    },
  )),
});
export type Address = typeof Address;

export const Value = Data.Map(
  PolicyId,
  Data.Map(Data.Bytes(), Data.Integer()),
);
export type Value = typeof Value;

export const OutRef = Data.Object({
  transactionId: Data.Object({
    hash: Data.Bytes(32),
  }),
  outputIndex: Data.Integer(),
});
export type OutRef = typeof OutRef;

export const RoyaltyRecipient = Data.Object({
  address: Address,
  fee: Data.Integer(),
  minFee: Data.Nullable(Data.Integer()),
  maxFee: Data.Nullable(Data.Integer()),
});
export type RoyaltyRecipient = typeof RoyaltyRecipient;

export const RoyaltyInfo = Data.Object({
  recipients: Data.Array(RoyaltyRecipient),
  version: Data.Integer(),
  extra: Data.Any(),
});
export type RoyaltyInfo = typeof RoyaltyInfo;

export const PaymentDatum = Data.Object({
  outRef: OutRef,
});
export type PaymentDatum = typeof PaymentDatum;
