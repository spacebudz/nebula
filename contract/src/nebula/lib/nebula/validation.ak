use aiken/builtin
use aiken/bytearray
use aiken/dict
use aiken/list
use aiken/transaction.{
  DatumHash, InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
  TransactionId,
}
use aiken/transaction/credential.{PublicKeyCredential}
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
        utils.value_paid_to_with_datum(tx, fee_recipient.address, payment_datum))
         >= adjusted_fee
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
            PublicKeyCredential(key1) -> key == key1
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
  when
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
  is {
    Some(royalty_input) -> {
      let royalty_info = when royalty_input.output.datum is {
        InlineDatum(datum) -> {
          assert royalty_info: RoyaltyInfo = datum
          // let (0, [raw_recipients, raw_version, ..]) =
          //   builtin.un_constr_data(datum)
          // assert recipients: List<RoyaltyRecipient> = raw_recipients
          royalty_info
        }
        DatumHash(h) -> {
          assert Some(datum) = dict.get(tx.datums, h)
          assert royalty_info: RoyaltyInfo = datum
          // let (0, [raw_recipients, raw_version, ..]) =
          //   builtin.un_constr_data(datum)
          // assert recipients: List<RoyaltyRecipient> = raw_recipients
          royalty_info
        }
        _ -> error
      }
      checked_fee_recipients(
        tx,
        royalty_info.recipients,
        payment_datum,
        accepted_lovelace,
        accepted_lovelace,
      )
    }
    _ -> error
  }
  // TODO: Re-nable
  // assert Some(royalty_input) =
  //   list.find(
  //     tx.reference_inputs,
  //     fn(input) {
  //       value.quantity_of(
  //         input.output.value,
  //         royalty_token.policy_id,
  //         royalty_token.asset_name,
  //       ) == 1
  //     },
  //   )
  // assert InlineDatum(datum) = royalty_input.output.datum
  // let royalty_info: RoyaltyInfo = datum
  // checked_fee_recipients(
  //   tx,
  //   royalty_info,
  //   payment_datum,
  //   accepted_lovelace,
  //   accepted_lovelace,
  // )
}

test paid_fee_1() {
  let payment_datum =
    PaymentDatum {
    output_reference: OutputReference {
      transaction_id: TransactionId { hash: #"00" },
      output_index: 0,
    }}
    
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
      utils.value_paid_to_with_datum(tx, bidding_details.owner, payment_datum))
      
    SpecificPolicyIdWithConstraints(policy_id, types, traits) -> {
      let requested_value =
        utils.value_paid_to_with_datum(tx, bidding_details.owner, payment_datum)
      when
        list.find(
          value.flatten(requested_value),
          fn(asset) {
            let (p, _, _) = asset
            p == policy_id
          },
        )
      is {
        Some((sell_policy_id, sell_asset_name, _)) -> {
          assert Some(metadata_input) =
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
          let datum_metadata: DatumMetadata = when
            metadata_input.output.datum
          is {
            NoDatum -> error
            DatumHash(h) -> {
              assert Some(datum) = dict.get(tx.datums, h)
              datum
            }
            InlineDatum(datum) -> datum
          }
          let metadata_type: ByteArray = {
            assert Some(t) =
              dict.get(datum_metadata.metadata, constants.type_key)
            builtin.un_b_data(t)
          }
          let metadata_traits: List<ByteArray> = {
            assert Some(t) =
              dict.get(datum_metadata.metadata, constants.traits_key)
            list.map(builtin.un_list_data(t), fn(d) { builtin.un_b_data(d) })
          }
          let has_type = when types is {
            [] -> True
            l ->
              list.any(
                l,
                fn(requested_type) { requested_type == metadata_type },
              )
          }
          let has_traits = when traits is {
            [] -> True
            l ->
              list.all(
                l,
                fn(requested_trait) {
                  when requested_trait is {
                    Included(trait) ->
                      list.any(
                        metadata_traits,
                        fn(m_trait) { m_trait == trait },
                      )
                    Excluded(trait) ->
                      !list.any(
                        metadata_traits,
                        fn(m_trait) { m_trait == trait },
                      )
                  }
                },
              )
          }
          has_type && has_traits && policy_id == sell_policy_id
        }
        _ -> False
      }
    }
  }
  // TODO: Re-nable
  // let requested_value =
  //   value_paid_to_with_datum(tx, bidding_details.owner, payment_datum)
  // assert Some((sell_policy_id, sell_asset_name, _)) =
  //   list.find(
  //     value.flatten(requested_value),
  //     fn(asset) {
  //       let (p, _, _) = asset
  //       p == policy_id
  //     },
  //   )
  // assert Some(metadata_input) =
  //   list.find(
  //     tx.reference_inputs,
  //     fn(input) {
  //       value.quantity_of(
  //         input.output.value,
  //         sell_policy_id,
  //         bytearray.concat(
  //           label_100,
  //           bytearray.drop(sell_asset_name, label_length),
  //         ),
  //       ) == 1
  //     },
  //   )
  // let datum_metadata: DatumMetadata = when metadata_input.output.datum is {
  //   NoDatum -> error
  //   DatumHash(h) -> {
  //     assert Some(datum) = dict.get(tx.datums, h)
  //     datum
  //   }
  //   InlineDatum(datum) -> datum
  // }
  // let metadata_type: ByteArray = {
  //   assert Some(t) =
  //     dict.get(datum_metadata.metadata, metadata_keys.type_key)
  //   builtin.un_b_data(t)
  // }
  // let metadata_traits: List<ByteArray> = {
  //   assert Some(t) =
  //     dict.get(datum_metadata.metadata, metadata_keys.traits_key)
  //   list.map(builtin.un_list_data(t), fn(d) { builtin.un_b_data(d) })
  // }
  // let has_type = when types is {
  //   [] -> True
  //   l -> list.any(l, fn(requested_type) { requested_type == metadata_type })
  // }
  // let has_traits = when traits is {
  //   [] -> True
  //   l ->
  //     list.all(
  //       l,
  //       fn(requested_trait) {
  //         let (negation, trait) = requested_trait
  //         if negation < 0 {
  //           !list.any(metadata_traits, fn(m_trait) { m_trait == trait })
  //         } else {
  //           list.any(metadata_traits, fn(m_trait) { m_trait == trait })
  //         }
  //       },
  //     )
  // }
  // has_type && has_traits && policy_id == sell_policy_id
}

// test paid_buyer_1() {
//   let payment_datum =
//     PaymentDatum {
//     output_reference: OutputReference {
//       transaction_id: TransactionId { hash: #"00" },
//       output_index: 0,
//     }}
//   let output =
//     Output {
//       address: fixture.keyhash_address(#"010203"),
//       value: value.from_asset(#"010203", #"010203", 1),
//       datum: InlineDatum(payment_datum),
//       reference_script: None,
//     }
//   let tx = fixture.tx([], [output])
//   let bidding_details =
//     BiddingDetails {
//       owner: fixture.keyhash_address(#"010203"),
//       requested_option: SpecificValue(value.from_asset(#"010203", #"010203", 1)),
//     }
//   paid_buyer(tx, payment_datum, bidding_details)
// }

// TODO
// test paid_buyer_2() {
//   let payment_datum =
//     PaymentDatum {
//     output_reference: OutputReference {
//       transaction_id: TransactionId { hash: #"00" },
//       output_index: 0,
//     }}
//   let output =
//     Output {
//       address: fixture.keyhash_address(#"010203"),
//       value: value.from_asset(#"010203", #"000de140427564", 1),
//       datum: InlineDatum(payment_datum),
//       reference_script: None,
//     }
//   let datum_metadata =
//     DatumMetadata {
//       metadata: dict.new()
//       |> dict.insert(#"74797065", builtin.b_data(#"446f67"))
//       |> dict.insert(
//         #"747261697473",
//         builtin.list_data([builtin.b_data(#"417865")]),
//       ),
//       version: 1,
//     }
//   let reference_input =
//     Input {
//       output_reference: OutputReference {
//         transaction_id: TransactionId { hash: #"00" },
//         output_index: 0,
//       },
//       output: Output {
//         address: fixture.keyhash_address(#"010203"),
//         value: value.from_asset(#"010203", #"000643b0427564", 1),
//         datum: InlineDatum(datum_metadata),
//         reference_script: None,
//       },
//     }
//   let tx = fixture.tx([reference_input], [output])
//   let bidding_details =
//     BiddingDetails {
//       owner: fixture.keyhash_address(#"010203"),
//       requested_option: SpecificPolicyIdWithConstraints(
//         #"010203",
//         [#"446f67"],
//         [Included(#"417865")],
//       ),
//     }
//   paid_buyer(tx, payment_datum, bidding_details)
// }

pub fn paid_seller(
  tx: Transaction,
  payment_datum: PaymentDatum,
  listing_details: ListingDetails,
  remaining_lovelace: Int,
) -> Bool {
  value.lovelace_of(
  utils.value_paid_to_with_datum(tx, listing_details.owner, payment_datum))
   >= remaining_lovelace
}

test paid_seller_1() {
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
    }}
    
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
