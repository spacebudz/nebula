use aiken/dict
use aiken/interval.{Interval, IntervalBound, PositiveInfinity}
use aiken/transaction.{Transaction, TransactionId}
use aiken/transaction/value

pub fn tx_1() -> Transaction {
  let tx =
    Transaction {
      inputs: [],
      reference_inputs: [],
      outputs: [],
      fee: value.zero(),
      mint: value.zero(),
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
      extra_signatories: [],
      redeemers: dict.new(),
      datums: dict.new(),
      id: TransactionId { hash: #[] },
    }
  tx
}
