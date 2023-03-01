use aiken/bytearray
use aiken/dict.{Dict}
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction, TransactionId,
}
use aiken/transaction/credential.{VerificationKeyCredential}
use aiken/transaction/value
use nebula/constants
use nebula/fixture
use nebula/types.{
  BiddingDetails, DatumMetadata, Excluded, Included, ListingDetails,
  PaymentDatum, PublicKeyHash, RoyaltyInfo, RoyaltyRecipient, RoyaltyToken,
  SpecificPolicyIdWithConstraints, SpecificValue,
}
use nebula/utils

pub fn checked_fee_recipients(
  tx: Transaction,
  royalty_recipients: List<RoyaltyRecipient>,
  payment_datum: PaymentDatum,
  accepted_lovelace: Int,
  remaining_lovelace: Int,
) -> Option<Int> {
  when royalty_recipients is {
    [] -> Some(remaining_lovelace)
    [fee_recipient, ..remaining_recipients] -> {
      let fee_to_pay = accepted_lovelace * 10 / fee_recipient.fee
      // Check if the variable fee stays within the boundaries of minFee and maxFee (if applied)
      let adjusted_fee =
        fee_to_pay
        |> utils.adjust_lower_bound(fee_recipient.min_fee)
        |> utils.adjust_upper_bound(fee_recipient.max_fee)
      let has_paid =
        value.lovelace_of(
          utils.value_paid_to_with_datum(
            tx,
            fee_recipient.address,
            payment_datum,
          ),
        ) >= adjusted_fee
      if has_paid {
        checked_fee_recipients(
          tx,
          remaining_recipients,
          payment_datum,
          accepted_lovelace,
          remaining_lovelace - adjusted_fee,
        )
      } else {
        None
      }
    }
  }
}

pub fn paid_protocol(
  tx: Transaction,
  protocol_key: Option<PublicKeyHash>,
) -> Bool {
  when protocol_key is {
    Some(key) ->
      list.any(
        tx.outputs,
        fn(output) {
          when output.address.payment_credential is {
            VerificationKeyCredential(key1) -> key == key1
            _ -> False
          }
        },
      )
    None -> True
  }
}

pub fn paid_fee(
  tx: Transaction,
  payment_datum: PaymentDatum,
  accepted_lovelace: Int,
  royalty_token: RoyaltyToken,
) -> Option<Int> {
  expect Some(royalty_input) =
    list.find(
      tx.reference_inputs,
      fn(input) {
        value.quantity_of(
          input.output.value,
          royalty_token.policy_id,
          royalty_token.asset_name,
        ) == 1
      },
    )
  expect royalty_info: RoyaltyInfo =
    utils.get_data(tx, royalty_input.output.datum)
  checked_fee_recipients(
    tx,
    royalty_info.recipients,
    payment_datum,
    accepted_lovelace,
    accepted_lovelace,
  )
}

test paid_fee_1() {
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
      value: value.from_lovelace(500),
      datum: InlineDatum(payment_datum),
      reference_script: None,
    }
  let output_2 =
    Output {
      address: fixture.keyhash_address(#"040506"),
      value: value.from_lovelace(200),
      datum: InlineDatum(payment_datum),
      reference_script: None,
    }
  let royalty_token =
    RoyaltyToken { policy_id: #"01020304", asset_name: #"01020304" }
  let royalty_info =
    RoyaltyInfo {
      recipients: [
        RoyaltyRecipient {
          address: fixture.keyhash_address(#"010203"),
          fee: 20,
          min_fee: Some(200),
          max_fee: Some(800),
        },
        RoyaltyRecipient {
          address: fixture.keyhash_address(#"040506"),
          fee: 100,
          min_fee: Some(200),
          max_fee: Some(800),
        },
      ],
      version: 1,
      extra: None,
    }
  let reference_input =
    Input {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
      output: Output {
        address: fixture.keyhash_address(#"010203"),
        value: value.from_asset(
          royalty_token.policy_id,
          royalty_token.asset_name,
          1,
        ),
        datum: InlineDatum(royalty_info),
        reference_script: None,
      },
    }
  let tx = fixture.tx([reference_input], [output, output_2])
  paid_fee(tx, payment_datum, 1000, royalty_token) == Some(300)
}

pub fn paid_buyer(
  tx: Transaction,
  payment_datum: PaymentDatum,
  bidding_details: BiddingDetails,
) -> Bool {
  when bidding_details.requested_option is {
    SpecificValue(requested_value) ->
      value.without_lovelace(requested_value) == value.without_lovelace(
        utils.value_paid_to_with_datum(tx, bidding_details.owner, payment_datum),
      )
    SpecificPolicyIdWithConstraints(policy_id, [], None) -> {
      let requested_value =
        utils.value_paid_to_with_datum(tx, bidding_details.owner, payment_datum)
      expect Some((sell_policy_id, sell_asset_name, _)) =
        list.find(
          value.flatten(requested_value),
          fn(asset) {
            let (p, _, _) = asset
            p == policy_id
          },
        )
      let used_label = bytearray.take(sell_asset_name, constants.label_length)
      // A soft restriction on asset names. Reference, Royalty and Ip token are not allowed to be used here.
      // Other token types can technically be used, but should NOT be under the same policy id as the collection itself!
      let is_valid_name =
        used_label != constants.label_100 && used_label != constants.label_500 && used_label != constants.label_600
      policy_id == sell_policy_id && is_valid_name
    }
    SpecificPolicyIdWithConstraints(policy_id, types, traits) -> {
      let requested_value =
        utils.value_paid_to_with_datum(tx, bidding_details.owner, payment_datum)
      expect Some((sell_policy_id, sell_asset_name, _)) =
        list.find(
          value.flatten(requested_value),
          fn(asset) {
            let (p, _, _) = asset
            p == policy_id
          },
        )
      expect Some(metadata_input) =
        list.find(
          tx.reference_inputs,
          fn(input) {
            value.quantity_of(
              input.output.value,
              sell_policy_id,
              bytearray.concat(
                constants.label_100,
                bytearray.drop(sell_asset_name, constants.label_length),
              ),
            ) == 1
          },
        )
      expect datum_metadata: DatumMetadata =
        utils.get_data(tx, metadata_input.output.datum)
      expect metadata_type: ByteArray = {
        expect Some(t) = dict.get(datum_metadata.metadata, constants.type_key)
        t
      }
      expect metadata_traits: List<ByteArray> = {
        expect Some(t) = dict.get(datum_metadata.metadata, constants.traits_key)
        t
      }
      let has_type = when types is {
        [] -> True
        l -> list.any(l, fn(requested_type) { requested_type == metadata_type })
      }
      let has_traits = when traits is {
        None -> True
        Some([]) -> metadata_traits == []
        Some(l) ->
          list.all(
            l,
            fn(requested_trait) {
              when requested_trait is {
                Included(trait) ->
                  list.any(metadata_traits, fn(m_trait) { m_trait == trait })
                Excluded(trait) ->
                  !list.any(metadata_traits, fn(m_trait) { m_trait == trait })
              }
            },
          )
      }
      // A soft restriction on asset names. We only need to check if the Reference token itself is not used.
      let used_label = bytearray.take(sell_asset_name, constants.label_length)
      let is_valid_name = used_label != constants.label_100
      let used_correct_policy_id = policy_id == sell_policy_id
      has_type && has_traits && used_correct_policy_id && is_valid_name
    }
  }
}

test paid_buyer_1() {
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
      value: value.from_asset(#"010203", #"010203", 1),
      datum: InlineDatum(payment_datum),
      reference_script: None,
    }
  let tx = fixture.tx([], [output])
  let bidding_details =
    BiddingDetails {
      owner: fixture.keyhash_address(#"010203"),
      requested_option: SpecificValue(value.from_asset(#"010203", #"010203", 1)),
    }
  paid_buyer(tx, payment_datum, bidding_details)
}

test paid_buyer_2() {
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
      value: value.from_asset(#"010203", #"000de140427564", 1),
      datum: InlineDatum(payment_datum),
      reference_script: None,
    }
  let m = {
    let m: Dict<ByteArray, Data> = dict.new()
    m
    |> dict.insert(#"74797065", #"446f67", bytearray.compare)
    |> dict.insert(#"747261697473", [#"417865"], bytearray.compare)
  }
  let datum_metadata = DatumMetadata { metadata: m, version: 1, extra: None }
  let reference_input =
    Input {
      output_reference: OutputReference {
        transaction_id: TransactionId { hash: #"00" },
        output_index: 0,
      },
      output: Output {
        address: fixture.keyhash_address(#"010203"),
        value: value.from_asset(#"010203", #"000643b0427564", 1),
        datum: InlineDatum(datum_metadata),
        reference_script: None,
      },
    }
  let tx = fixture.tx([reference_input], [output])
  let bidding_details =
    BiddingDetails {
      owner: fixture.keyhash_address(#"010203"),
      requested_option: SpecificPolicyIdWithConstraints(
        #"010203",
        [#"446f67"],
        Some([Included(#"417865")]),
      ),
    }
  paid_buyer(tx, payment_datum, bidding_details)
}

pub fn paid_seller(
  tx: Transaction,
  payment_datum: PaymentDatum,
  listing_details: ListingDetails,
  remaining_lovelace: Int,
) -> Bool {
  value.lovelace_of(
    utils.value_paid_to_with_datum(tx, listing_details.owner, payment_datum),
  ) >= remaining_lovelace
}

test paid_seller_1() {
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
  let tx = fixture.tx([], [output])
  let listing_details =
    ListingDetails {
      owner: fixture.keyhash_address(#"010203"),
      requested_lovelace: 0,
      private_listing: None,
    }
  paid_seller(tx, payment_datum, listing_details, 10000)
}

test paid_seller_2() {
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
      value: value.from_lovelace(900),
      datum: InlineDatum(payment_datum),
      reference_script: None,
    }
  let tx = fixture.tx([], [output])
  let listing_details =
    ListingDetails {
      owner: fixture.keyhash_address(#"010203"),
      requested_lovelace: 0,
      private_listing: None,
    }
  !paid_seller(tx, payment_datum, listing_details, 10000)
}
