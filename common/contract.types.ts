import { Data } from "../deps.ts";

const PolicyId = Data.Bytes({ minLength: 28, maxLength: 28 });

const CredentialSchema = Data.Enum([
  Data.Object({
    VerificationKeyCredential: Data.Tuple([
      Data.Bytes({ minLength: 28, maxLength: 28 }),
    ]),
  }),
  Data.Object({
    ScriptCredential: Data.Tuple([
      Data.Bytes({ minLength: 28, maxLength: 28 }),
    ]),
  }),
]);
export type Credential = Data.Static<typeof CredentialSchema>;
export const Credential = CredentialSchema as unknown as Credential;

const AddressSchema = Data.Object({
  paymentCredential: CredentialSchema,
  stakeCredential: Data.Nullable(Data.Enum([
    Data.Object({ Inline: Data.Tuple([CredentialSchema]) }),
    Data.Object({
      Pointer: Data.Object({
        slotNumber: Data.Integer(),
        transactionIndex: Data.Integer(),
        certificateIndex: Data.Integer(),
      }),
    }),
  ])),
});
export type Address = Data.Static<typeof AddressSchema>;
export const Address = AddressSchema as unknown as Address;

export const Value = Data.Map(
  PolicyId,
  Data.Map(Data.Bytes(), Data.Integer()),
);
export type Value = Data.Static<typeof Value>;

const OutRefSchema = Data.Object({
  transactionId: Data.Object({
    hash: Data.Bytes({ minLength: 32, maxLength: 32 }),
  }),
  outputIndex: Data.Integer(),
});
export type OutRef = Data.Static<typeof OutRefSchema>;
export const OutRef = OutRefSchema as unknown as OutRef;

const RoyaltyRecipientSchmema = Data.Object({
  address: AddressSchema,
  fee: Data.Integer({ minimum: 1 }),
  minFee: Data.Nullable(Data.Integer()),
  maxFee: Data.Nullable(Data.Integer()),
});
export type RoyaltyRecipient = Data.Static<typeof RoyaltyRecipientSchmema>;
export const RoyaltyRecipient =
  RoyaltyRecipientSchmema as unknown as RoyaltyRecipient;

const RoyaltyInfoSchema = Data.Object({
  recipients: Data.Array(RoyaltyRecipientSchmema),
  version: Data.Integer({ minimum: 1, maximum: 1 }),
  extra: Data.Any(),
});
export type RoyaltyInfo = Data.Static<typeof RoyaltyInfoSchema>;
export const RoyaltyInfo = RoyaltyInfoSchema as unknown as RoyaltyInfo;

const PaymentDatumSchema = Data.Object({
  outRef: OutRefSchema,
});
export type PaymentDatum = Data.Static<typeof PaymentDatumSchema>;
export const PaymentDatum = PaymentDatumSchema as unknown as PaymentDatum;
