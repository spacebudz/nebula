use aiken/hash.{Blake2b_224, Hash}

/// A general structure for representing an on-chain `Credential`.
///
/// Credentials are always one of two kinds: a direct public/private key
/// pair, or a script (native or Plutus).
pub type Credential {
  PublicKeyCredential(Hash<Blake2b_224, VerificationKey>)
  ScriptCredential(Hash<Blake2b_224, Script>)
}

/// A Cardano `Address` typically holding one or two credential references.
///
/// Note that legacy bootstrap addresses (a.k.a. 'Byron addresses') are
/// completely excluded from Plutus contexts. Thus, from an on-chain
/// perspective only exists addresses of type 00, 01, ..., 07 as detailed
/// in [CIP-0019 :: Shelley Addresses](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0019/#shelley-addresses).
pub type Address {
  payment_credential: PaymentCredential,
  stake_credential: Option<StakeCredential>,
}

/// Represent a type of object that can be represented either inline (by hash)
/// or via a reference (i.e. a pointer to an on-chain location).
///
/// This is mainly use for capturing pointers to a stake credential
/// registration certificate in in the case of so-called pointer addresses.
pub type Referenced<a> {
  Inline(a)
  Pointer { slot_number: Int, transaction_index: Int, certificate_index: Int }
}

pub type VerificationKey =
  Nil

pub type Script =
  Nil

/// A `StakeCredential` represents the delegation and rewards withdrawal conditions
/// associated with some stake address / account.
///
/// A `StakeCredential` is either provided inline, or, by reference using an
/// on-chain pointer.
///
/// Read more about pointers in [CIP-0019 :: Pointers](https://github.com/cardano-foundation/CIPs/tree/master/CIP-0019/#pointers).
pub type StakeCredential =
  Referenced<Credential>

/// A 'PaymentCredential' represents the spending conditions associated with
/// some output. Hence,
///
/// - a `PublicKeyCredential` captures an output locked by a public/private key pair;
/// - and a `ScriptCredential` captures an output locked by a native or Plutus script.
///
pub type PaymentCredential =
  Credential

/// A unique stake pool identifier, as a hash of its owner verification key.
pub type PoolId =
  Hash<Blake2b_224, VerificationKey>
