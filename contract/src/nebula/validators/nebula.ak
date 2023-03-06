use aiken/transaction.{ScriptContext}
use aiken/transaction/value
use nebula/types.{
  Bid, Buy, Cancel, Listing, PaymentDatum, PublicKeyHash, RoyaltyToken, Sell,
  TradeAction, TradeDatum,
}
use nebula/utils.{get_own_input, tx_signed_by_address}
use nebula/validation.{paid_buyer, paid_fee, paid_protocol, paid_seller}

validator spend(
  protocol_key: Option<PublicKeyHash>,
  royalty_token: RoyaltyToken,
) {
  fn(datum: TradeDatum, action: TradeAction, ctx: ScriptContext) -> Bool {
    let tx = ctx.transaction
    let own_input = get_own_input(ctx)
    let payment_datum =
      PaymentDatum { output_reference: own_input.output_reference }

    when action is {
      Sell -> {
        expect Bid(bidding_details) = datum
        let accepted_lovelace = value.lovelace_of(own_input.output.value)
        expect Some(_) =
          paid_fee(tx, payment_datum, accepted_lovelace, royalty_token)
        paid_protocol(tx, protocol_key) && paid_buyer(
          tx,
          payment_datum,
          bidding_details,
        )
      }
      Buy -> {
        expect Listing(listing_details) = datum
        let accepted_lovelace = listing_details.requested_lovelace
        expect Some(remaining_lovelace) =
          paid_fee(tx, payment_datum, accepted_lovelace, royalty_token)
        let checked_private_listing = when listing_details.private_listing is {
          Some(owner) -> tx_signed_by_address(tx, owner)
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
        tx_signed_by_address(tx, owner)
      }
    }
  }
}
