use aiken/assoc_list.{AssocList}
use aiken/hash.{Blake2b_224, Blake2b_256, Hash}
use aiken/interval.{Interval}
use aiken/transaction/certificate.{Certificate}
use aiken/transaction/credential.{
  Address, Script, StakeCredential, VerificationKey,
}
use aiken/transaction/value.{PolicyId, Value}

/// A context given to a script by the Cardano ledger when being executed.
///
/// The context contains information about the entire transaction that contains
/// the script. The transaction may also contain other scripts; to distinguish
/// between multiple scripts, the `ScriptContext` also contains a `purpose`
/// which indicates which script (or, for what purpose) of the transaction is
/// being executed.
pub type ScriptContext {
  transaction: Transaction,
  purpose: ScriptPurpose,
}

/// Caracterizes the kind of script being executed.
///
/// - `Mint`:
///     refers to scripts executed as minting/burning policies, to insert
///     or remove assets from circulation. It's parameterized by the identifier
///     of the associated policy.
///
/// - `Spend`:
///     refers to scripts that are used as payment credentials for addresses in
///     transaction outputs. They govern the rule by which the output they
///     reference can be spent.
///
/// - `WithdrawFrom`:
///     is triggered to validate reward withdrawals from a reward account whose
///     associated credential is defined as a Plutus script. It identifies the
///     target reward account.
///
/// - `Publish`:
///     needed when delegating to a pool using stake credentials defined as a
///     Plutus script. This kind is also triggered when de-registering such
///     stake credentials. It embeds the certificate that's being validated.
///
pub type ScriptPurpose {
  Mint(PolicyId)
  Spend(OutputReference)
  WithdrawFrom(StakeCredential)
  Publish(Certificate)
}

/// A Cardano `Transaction`, as seen by Plutus scripts.
///
/// Note that this is a representation of a transaction, and not the 1:1
/// translation of the transaction as seen by the ledger. In particular,
/// Plutus scripts can't see inputs locked by bootstrap addresses, outputs
/// to bootstrap addresses or just transaction metadata.
pub type Transaction {
  inputs: List<Input>,
  reference_inputs: List<Input>,
  outputs: List<Output>,
  fee: Value,
  mint: Value,
  certificates: List<Certificate>,
  withdrawals: AssocList<StakeCredential, Int>,
  validity_range: ValidityRange,
  extra_signatories: List<Hash<Blake2b_224, VerificationKey>>,
  redeemers: AssocList<ScriptPurpose, Redeemer>,
  datums: AssocList<Hash<Blake2b_256, Data>, Data>,
  id: TransactionId,
}

/// An interval of POSIX time, measured in number milliseconds since 1970-01-01T00:00:00Z.
pub type ValidityRange =
  Interval<Int>

/// A unique transaction identifier, as the hash of a transaction body. Note that the transaction id
/// isn't a direct hash of the `Transaction` as visible on-chain. Rather, they correspond to hash
/// digests of transaction body as they are serialized on the network.
pub type TransactionId {
  hash: Hash<Blake2b_256, Transaction>,
}

/// An `Input` made of an output reference and, the resolved value associated with that output.
pub type Input {
  output_reference: OutputReference,
  output: Output,
}

/// An `OutputReference` is a unique reference to an output on-chain. The `output_index`
/// corresponds to the position in the output list of the transaction (identified by its id)
/// that produced that output
pub type OutputReference {
  transaction_id: TransactionId,
  output_index: Int,
}

/// A transaction `Output`, with an address, a value and optional datums and script references.
pub type Output {
  address: Address,
  value: Value,
  datum: Datum,
  reference_script: Option<Hash<Blake2b_224, Script>>,
}

/// An output `Datum`, which be either:
///
/// - None (`NoDatum`)
/// - A reference by hash (`DatumHash`)
/// - A plain inline Plutus data (`InlineDatum`)
pub type Datum {
  NoDatum
  DatumHash(Hash<Blake2b_256, Data>)
  InlineDatum(Data)
}

/// A type-alias for Redeemers, passed to scripts for validation. The `Data` is
/// opaque because it is user-defined and it is the script's responsability to
/// parse it into its expected form.
pub type Redeemer =
  Data
