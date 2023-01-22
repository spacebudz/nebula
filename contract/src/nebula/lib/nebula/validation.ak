use aiken/builtin
use aiken/bytearray
use aiken/dict
use aiken/list
use aiken/transaction.{DatumHash, InlineDatum, NoDatum, Transaction}
use aiken/transaction/credential.{PublicKeyCredential}
use aiken/transaction/value
use nebula/constants
use nebula/fixture
use nebula/types.{
  BiddingDetails, DatumMetadata, Excluded, Included, ListingDetails,
  PublicKeyHash, RoyaltyInfo, RoyaltyRecipient, RoyaltyToken,
  SpecificPolicyIdWithConstraints, SpecificValue,
}
use nebula/utils

pub fn checked_fee_recipients(
  tx: Transaction,
  royalty_recipients: List<RoyaltyRecipient>,
  payment_datum: Data,
  accepted_lovelace: Int,
  remaining_lovelace: Int,
) -> Option<Int> {
  when royalty_recipients is {
    [] -> Some(remaining_lovelace)
    [fee_recipient, ..remaining_recipients] -> {
      let fee_to_pay = accepted_lovelace * 10 / fee_recipient.fee
      let adjusted_fee =
        utils.adjust_upper_bound(fee_to_pay, fee_recipient.max_fee)
      let new_lovelace = remaining_lovelace - adjusted_fee
      let has_paid =
        value.lovelace_of(
        utils.value_paid_to_with_datum(tx, fee_recipient.address, payment_datum))
         >= adjusted_fee && new_lovelace > 0
      if has_paid {
        checked_fee_recipients(
          tx,
          remaining_recipients,
          payment_datum,
          accepted_lovelace,
          new_lovelace,
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
  payment_datum: Data,
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
    Some(royalty_input) ->
      when royalty_input.output.datum is {
        InlineDatum(datum) -> {
          let royalty_info: RoyaltyInfo = datum
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

pub fn paid_buyer(
  tx: Transaction,
  payment_datum: Data,
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

pub fn paid_seller(
  tx: Transaction,
  payment_datum: Data,
  listing_details: ListingDetails,
  remaining_lovelace: Int,
) -> Bool {
  value.lovelace_of(
  utils.value_paid_to_with_datum(tx, listing_details.owner, payment_datum))
   >= remaining_lovelace
}

test paid_seller_1() {
  let tx = fixture.tx_1()
  // TODO
  tx == tx
}
