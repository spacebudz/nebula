use aiken/dict
use aiken/list
use aiken/transaction.{
  Datum, DatumHash, InlineDatum, Input, NoDatum, Output, OutputReference,
  ScriptContext, Spend, Transaction, TransactionId,
}
use aiken/transaction/credential.{Address,
  PublicKeyCredential, ScriptCredential}
use aiken/transaction/value.{Value}
use nebula/constants
use nebula/fixture
use nebula/types.{PaymentDatum}

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
/// Signer can not only be a pub key hash, but also a script.
/// For pub key hashes it's trivial, but as script owner you need to lock a special
/// NFT with the asset name 'ScriptOwner' at the UTxO. You decide the script logic behind the minting policy.
/// Only if you can successfully burn the NFT then the Nebula contract allows you to redeem the value in case of a Cancel operation.
/// Note: Collisions with other assets having the name 'ScriptOwner' should be avoided!
pub fn tx_signed_by_address(
  tx: Transaction,
  owner: Address,
  value: Value,
) -> Bool {
  when owner.payment_credential is {
    PublicKeyCredential(keyhash) -> list.has(tx.extra_signatories, keyhash)
    ScriptCredential(_) ->
      when
        list.find(
          value.flatten(value),
          fn(asset) {
            let (_, asset_name, _) = asset
            asset_name == constants.script_owner
          },
        )
      is {
        Some((policy_id, asset_name, _)) ->
          value.quantity_of(tx.mint, policy_id, asset_name) < 0
        None -> False
      }
  }
}

test tx_signed_by_address_1() {
  tx_signed_by_address(
    fixture.tx([], []),
    fixture.keyhash_address(#"00010203040506"),
    value.zero(),
  )
}

test tx_signed_by_address_2() {
  tx_signed_by_address(
    fixture.tx([], []),
    fixture.scripthash_address(#"010203"),
    value.from_asset(#"000000", constants.script_owner, 1),
  )
}

test tx_signed_by_address_3() {
  !tx_signed_by_address(
    fixture.tx([], []),
    fixture.scripthash_address(#"010203"),
    value.from_asset(#"000001", constants.script_owner, 1),
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
    }}
    
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
    }}
    
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
