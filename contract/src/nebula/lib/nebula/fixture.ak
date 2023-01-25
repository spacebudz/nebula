// This file creates some fixtures we can use for testing

use aiken/dict
use aiken/interval.{Interval, IntervalBound, PositiveInfinity}
use aiken/transaction.{Input, Output, Transaction, TransactionId}
use aiken/transaction/credential.{Address,
  PublicKeyCredential, ScriptCredential}
use aiken/transaction/value
use nebula/constants

pub fn keyhash_address(keyhash: ByteArray) {
  Address {
    payment_credential: PublicKeyCredential(keyhash),
    stake_credential: None,
  }
}

pub fn scripthash_address(scripthash: ByteArray) {
  Address {
    payment_credential: ScriptCredential(scripthash),
    stake_credential: None,
  }
}

pub fn tx(reference_inputs: List<Input>, outputs: List<Output>) -> Transaction {
  let tx =
    Transaction {
      inputs: [],
      reference_inputs,
      outputs,
      fee: value.zero(),
      mint: value.from_asset(#[0, 0, 0], constants.script_owner, -1),
      certificates: [],
      withdrawals: dict.new(),
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: PositiveInfinity,
          is_inclusive: True,
        },
        upper_bound: IntervalBound {
          bound_type: PositiveInfinity,
          is_inclusive: True,
        },
      },
      extra_signatories: [#[0, 1, 2, 3, 4, 5, 6]],
      redeemers: dict.new(),
      datums: dict.new(),
      id: TransactionId { hash: #[] },
    }
  tx
}
