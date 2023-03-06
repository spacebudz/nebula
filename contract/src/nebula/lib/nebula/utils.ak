use aiken/dict
use aiken/list
use aiken/transaction.{
  Datum, DatumHash, InlineDatum, Input, NoDatum, Output, OutputReference,
  ScriptContext, Spend, Transaction, TransactionId,
}
use aiken/transaction/credential.{
  Address, ScriptCredential, VerificationKeyCredential,
}
use aiken/transaction/value.{Value}
use nebula/fixture
use nebula/types.{PaymentDatum, ScriptHash}

pub fn get_own_input(ctx: ScriptContext) -> Input {
  expect Spend(output_reference) = ctx.purpose
  expect Some(input) =
    list.find(
      ctx.transaction.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  input
}

pub fn get_data(tx: Transaction, datum: Datum) -> Data {
  when datum is {
    NoDatum -> error
    DatumHash(h) -> {
      expect Some(d) = dict.get(tx.datums, h)
      d
    }
    InlineDatum(d) -> d
  }
}

/// This is a special signing function. 
/// Signer can not only be a pub key address, but also a script address.
/// Unfortunately extra signatories can only be pub key hashes, that means we need a special mechanism 
/// to check whether a native or plutus script signed the transaction.
/// At first it sounds like a good idea to mint an ownership token, but when the other party accepts the bid or listing it will also receive the extra token.
/// This could lead to some unnecessary bloat after some time. So the better solution is to check for inputs.
/// If the transaction contains an input with the same script hash as the address in the datum we can assume the transaction was correctly signed.
/// Of course for plutus script addresses some constraints need to be added. 
pub fn tx_signed_by_address(tx: Transaction, owner: Address) -> Bool {
  when owner.payment_credential is {
    VerificationKeyCredential(keyhash) ->
      list.has(tx.extra_signatories, keyhash)
    ScriptCredential(scripthash) -> signed_with_input(tx, scripthash)
  }
}

fn signed_with_input(tx: Transaction, scripthash: ScriptHash) -> Bool {
  when
    list.find(
      tx.inputs,
      fn(input) {
        when input.output.address.payment_credential is {
          VerificationKeyCredential(_) -> False
          ScriptCredential(scripthash1) -> scripthash == scripthash1
        }
      },
    )
  is {
    Some(_) -> True
    None -> False
  }
}

test tx_signed_by_address_1() {
  tx_signed_by_address(
    fixture.tx([], []),
    fixture.keyhash_address(#"00010203040506"),
  )
}

test tx_signed_by_address_2() {
  tx_signed_by_address(
    fixture.tx([], []),
    fixture.scripthash_address(#"010203"),
  )
}

test tx_signed_by_address_3() {
  !tx_signed_by_address(
    fixture.tx([], []),
    fixture.scripthash_address(#"010204"),
  )
}

/// We expect outputs to be unique. Each output is tagged with a datum.
/// We also expect the datum to be inline
pub fn value_paid_to_with_datum(
  tx: Transaction,
  address: Address,
  payment_datum: PaymentDatum,
) -> Value {
  when
    list.filter(
      tx.outputs,
      fn(output) {
        output.address == address && output.datum == InlineDatum(payment_datum)
      },
    )
  is {
    [output] -> output.value
    _ -> error
  }
}

test value_paid_to_with_datum_1() {
  let payment_datum =
    PaymentDatum {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
    }
  let output =
    Output {
      address: fixture.keyhash_address(#"010203"),
      value: value.from_lovelace(10000),
      datum: InlineDatum(payment_datum),
      reference_script: None,
    }
  value_paid_to_with_datum(
    fixture.tx([], [output]),
    fixture.keyhash_address(#"010203"),
    payment_datum,
  ) == value.from_lovelace(10000)
}

test value_paid_to_with_datum_2() {
  let payment_datum =
    PaymentDatum {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
    }
  let output =
    Output {
      address: fixture.keyhash_address(#"010203"),
      value: value.from_lovelace(999),
      datum: InlineDatum(payment_datum),
      reference_script: None,
    }
  value_paid_to_with_datum(
    fixture.tx([], [output]),
    fixture.keyhash_address(#"010203"),
    payment_datum,
  ) != value.from_lovelace(10000)
}

pub fn adjust_lower_bound(fee: Int, lower_bound: Option<Int>) -> Int {
  when lower_bound is {
    Some(min_fee) ->
      if fee < min_fee {
        min_fee
      } else {
        fee
      }
    None -> fee
  }
}

test adjust_lower_bound_1() {
  adjust_lower_bound(0, None) == 0
}

test adjust_lower_bound_2() {
  adjust_lower_bound(0, Some(100)) == 100
}

test adjust_lower_bound_3() {
  adjust_lower_bound(110, Some(100)) == 110
}

pub fn adjust_upper_bound(fee: Int, upper_bound: Option<Int>) -> Int {
  when upper_bound is {
    Some(max_fee) ->
      if fee > max_fee {
        max_fee
      } else {
        fee
      }
    None -> fee
  }
}

test adjust_upper_bound_1() {
  adjust_upper_bound(100, None) == 100
}

test adjust_upper_bound_2() {
  adjust_upper_bound(0, Some(100)) == 0
}

test adjust_upper_bound_3() {
  adjust_upper_bound(110, Some(100)) == 100
}

test adjusted_fee_1() {
  let adjusted_fee =
    100
    |> adjust_lower_bound(None)
    |> adjust_upper_bound(None)
  adjusted_fee == 100
}

test adjusted_fee_2() {
  let adjusted_fee =
    100
    |> adjust_lower_bound(Some(10))
    |> adjust_upper_bound(Some(60))
  adjusted_fee == 60
}

test adjusted_fee_3() {
  let adjusted_fee =
    1
    |> adjust_lower_bound(Some(10))
    |> adjust_upper_bound(Some(60))
  adjusted_fee == 10
}
