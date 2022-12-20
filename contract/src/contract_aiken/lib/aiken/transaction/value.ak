use aiken/assoc_list.{AssocList}
use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{Script}

/// A type-alias for a `PolicyId`. A `PolicyId` is always 28-byte long
pub type PolicyId =
  Hash<Blake2b_224, Script>

/// A type-alias for 'AssetName`, which are free-form byte-arrays between
/// 0 and 32 bytes.
pub type AssetName =
  ByteArray

/// An output `Value`, as a key-value pairs of key-value pairs.
///
/// The first level represents policies id (or simply, scripts hashes),
/// and the second layer represents assets within that policy with their
/// respective quantities.
pub type Value =
  AssocList<PolicyId, AssocList<AssetName, Int>>
