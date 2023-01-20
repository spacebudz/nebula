use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{PoolId, StakeCredential, VerificationKey}

/// An on-chain certificate attesting of some operation. Publishing
/// certificates / triggers different kind of rules; most of the time,
/// they require signatures from / specific keys.
pub type Certificate {
  CredentialRegistration { delegator: StakeCredential }
  CredentialDeregistration { delegator: StakeCredential }
  CredentialDelegation { delegator: StakeCredential, delegatee: PoolId }
  PoolRegistration { pool_id: PoolId, vrf: Hash<Blake2b_224, VerificationKey> }
  PoolDeregistration { pool_id: PoolId, epoch: Int }
  Governance
  TreasuryMovement
}
