use aiken/transaction.{ScriptContext}
use aiken/transaction/value
use nebula/types.{
  Bid, Buy, Cancel, Listing, MetadataKeys, NebulaAction, NebulaDatum,
  PaymentDatum, PublicKeyHash, RoyaltyToken, Sell,
}
use nebula/utils.{get_own_input, tx_signed_by_address}
use nebula/validation.{paid_buyer, paid_fee, paid_protocol, paid_seller}

fn spend(
  protocol_key: Option<PublicKeyHash>,
  metadata_keys: MetadataKeys,
  royalty_token: RoyaltyToken,
  datum: NebulaDatum,
  action: NebulaAction,
  ctx: ScriptContext,
) -> Bool {
  let tx = ctx.transaction
  let own_input = get_own_input(ctx)
  let payment_datum: Data =
    PaymentDatum { output_reference: own_input.output_reference }

  when action is {
    Sell ->
      when datum is {
        Bid(bidding_details) -> {
          let accepted_lovelace = value.lovelace_of(own_input.output.value)
          when
            paid_fee(tx, payment_datum, accepted_lovelace, royalty_token)
          is {
            Some(_) ->
              paid_protocol(tx, protocol_key) && paid_buyer(
                tx,
                payment_datum,
                bidding_details,
                metadata_keys,
              )
            None -> False
          }
        }
        _ -> False
      }
    // TODO: Re-nable
    // assert Bid(bidding_details) = datum
    // let accepted_lovelace = value.lovelace_of(own_input.output.value)
    // assert Some(_) =
    //   paid_fee(
    //     tx,
    //     payment_datum,
    //     accepted_lovelace,
    //     royalty_token,
    //     protocol_key,
    //   )
    // paid_protocol(tx, protocol_key) && paid_buyer(
    //   tx,
    //   payment_datum,
    //   bidding_details,
    //   metadata_keys,
    // )
    Buy -> {
      assert Listing(listing_details) = datum
      let accepted_lovelace = listing_details.requested_lovelace
      assert Some(remaining_lovelace) =
        paid_fee(tx, payment_datum, accepted_lovelace, royalty_token)
      let checked_private_listing = when listing_details.private_listing is {
        Some(owner) -> tx_signed_by_address(tx, owner, own_input.output.value)
        None -> True
      }
      paid_protocol(tx, protocol_key) && checked_private_listing && paid_seller(
        tx,
        payment_datum,
        listing_details,
        remaining_lovelace,
      )
    }
    Cancel -> {
      let owner = when datum is {
        Listing(listing_details) -> listing_details.owner
        Bid(bidding_details) -> bidding_details.owner
      }
      tx_signed_by_address(tx, owner, own_input.output.value)
    }
  }
}
