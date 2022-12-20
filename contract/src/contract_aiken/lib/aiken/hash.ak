/// A self-documenting type-alias with a phantom-type for readability.
///
/// On-chain, any hash digest value is represented as a plain 'ByteArray'.
/// Though in practice, hashes come from different sources and have
/// different semantics.
///
/// Hence, while this type-alias doesn't provide any strong type-guarantees,
/// it helps writing functions signatures with more meaningful types than mere
/// 'ByteArray'.
///
/// Compare for example:
///
/// ```aiken
/// pub type Credential {
///   PublicKeyCredential(ByteArray)
///   ScriptCredential(ByteArray)
/// }
/// ```
///
/// with
///
/// ```aiken
/// use aiken.hash.{Hash, HashAlgorithm}
///
/// pub type Credential {
///   PublicKeyCredential(Hash<Blake2b_224, VerificationKey>)
///   ScriptCredential(Hash<Blake2b_224, Script>)
/// }
/// ```
///
/// Both are strictly equivalent, but the second reads much better.
pub type Hash<alg, a> =
  ByteArray

/// A blake2b-224 hash algorithm.
pub type Blake2b_224 =
  Nil

/// A blake2b-256 hash algorithm.
pub type Blake2b_256 =
  Nil

/// A SHA-256 hash algorithm.
pub type Sha256 =
  Nil

/// A SHA-512 hash algorithm.
pub type Sha512 =
  Nil
