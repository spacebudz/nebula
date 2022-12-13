// WIP!!
use aiken/context.{
  Address, AssetName, Datum, DatumHash, Hash, Input, Output, OutputReference,
  PolicyId, PublicKeyCredential, PublicKeyHash, ScriptContext, ScriptCredential,
  ScriptPurpose, Spend, Transaction, Value,
}
use aiken/map.{Map}
use aiken/list
use aiken/bytearray

pub type ListingDetails {
  owner: Address,
  requested_lovelace: Int,
  private_listing: Option<Address>,
}

pub type BiddingDetails {
  owner: Address,
  requested_option: BidOption,
}

pub type RoyaltyInfo {
  recipients: List<RoyaltyRecipient>,
  min_ada: Int,
}

pub type RoyaltyRecipient {
  address: Address,
  fee: Int,
  fixed_fee: Int,
}

pub type Metadata =
  Map<Data, Data>

pub type DatumMetadata {
  metadata: Metadata,
  version: Int,
}

pub type BidOption {
  SpecificValue(Value)
  SpecificPolicyIdWithConstaints(
    PolicyId,
    List<ByteArray>,
    List<#(Int, ByteArray)>,
  )
}

pub type RoyaltyToken =
  #(PolicyId, AssetName)

pub type TradeDatum {
  Listing(ListingDetails)
  Bid(BiddingDetails)
}

pub type TradeAction {
  Sell
  Buy
  Cancel
}

type PaymentDatum {
  output_reference: OutputReference,
}

// CIP-0067
const label_length = 4

const label_100 = #[0, 6, 67, 176]

// 'ScriptOwner' in UTF-8
const script_owner = #[83, 99, 114, 105, 112, 116, 79, 119, 110, 101, 114]

pub fn get_own_input(ctx: ScriptContext) -> Input {
  assert Spend(output_reference) = ctx.purpose
  let tx = ctx.transaction
  assert Some(input) =
    list.find(
      tx.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  input
}

pub fn flatten_value(value: Value) -> List<#(PolicyId, AssetName, Int)> {
  list.foldl(
    map.to_list(value),
    fn(policies, acc) {
      let #(policy_id, assets) = policies
      list.concat(
        acc,
        list.map(
          map.to_list(assets),
          fn(asset) {
            let #(asset_name, amount) = asset
            #(policy_id, asset_name, amount)
          },
        ),
      )
    },
    [],
  )
}

pub fn value_of(value: Value, policy_id: PolicyId, asset_name: AssetName) -> Int {
  when map.get(value, policy_id) is {
    Some(assets) ->
      when map.get(assets, asset_name) is {
        Some(amount) -> amount
        None -> 0
      }
    None -> 0
  }
}

pub fn exclude_lovelace(value: Value) -> Value {
  map.remove(value, #[])
}

pub fn tx_signed_by_address(
  tx: Transaction,
  owner: Address,
  value: Value,
) -> Bool {
  when owner.payment_credential is {
    PublicKeyCredential(keyhash) -> list.is_elem(tx.extra_signatories, keyhash)
    ScriptCredential(scripthash) -> {
      let mint = tx.mint
      when
        list.find(
          flatten_value(value),
          fn(asset) {
            let #(_, asset_name, _) = asset
            asset_name == script_owner
          },
        )
      is {
        Some(asset) -> {
          let #(policy_id, asset_name, _) = asset
          value_of(mint, policy_id, asset_name) < 0
        }
        None -> False
      }
    }
  }
}

pub fn lovelace_of(value: Value) -> Int {
  value_of(value, #[], #[])
}

// We assume inputs are unique because of datum tagging.
pub fn value_paid_to_address_with_datum(
  outputs: List<Output>,
  address: Address,
  datum: Data,
) -> Value {
  let datum_option = Datum(datum)
  when
    list.find(
      outputs,
      fn(output) { output.address == address && output.datum == datum_option },
    )
  is {
    Some(output) -> output.value
    None -> map.new()
  }
}

pub fn checked_fee_recipients(
  outputs: List<Output>,
  fee_recipients: List<RoyaltyRecipient>,
  payment_datum: Data,
  min_ada: Int,
  accepted_lovelace: Int,
  remaining_lovelace: Int,
) -> Option<Int> {
  when fee_recipients is {
    [] -> Some(remaining_lovelace)
    [fee_recipient, ..remaining_recipients] -> {
      let fee_to_pay = accepted_lovelace * 10 / fee_recipient.fee
      let adjusted_fee =
        if fee_to_pay < min_ada {
          fee_recipient.fixed_fee
        } else {
          fee_to_pay
        }
      let new_lovelace = remaining_lovelace - adjusted_fee
      if
          lovelace_of(
          value_paid_to_address_with_datum(
            outputs,
            fee_recipient.address,
            payment_datum,
          ))
           >= adjusted_fee && new_lovelace > 0
        {
        checked_fee_recipients(
        outputs,
        remaining_recipients,
        payment_datum,
        min_ada,
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
  outputs: List<Output>,
  protocol_key: Option<PublicKeyHash>,
) -> Bool {
  when protocol_key is {
    Some(key) ->
      list.any(
        tx.outputs,
        fn(output) {
          when output.address.payment_credential is {
            PublicKeyCredential(key_) -> key == key_
            _ -> False
          }
        },
      )
    None -> True
  }
}

pub fn paid_fee(
  reference_inputs: List<Input>,
  outputs: List<Output>,
  payment_datum: Data,
  accepted_lovelace: Int,
  royalty_token: RoyaltyToken,
  protocol_key: Option<PublicKeyHash>,
) -> Option<Int> {
  let #(royalty_policy_id, royalty_asset_name) = royalty_token
  assert Some(royalty_input) =
    list.find(
      reference_inputs,
      fn(input) {
        value_of(input.output.value, royalty_policy_id, royalty_asset_name) == 1
      },
    )
  assert Datum(datum) = royalty_input.output.datum
  let royalty_info: RoyaltyInfo = datum
  checked_fee_recipients(
    royalty_info.recipients,
    payment_datum,
    outputs,
    royalty_info.min_ada,
    accepted_lovelace,
    accepted_lovelace,
  )
}

pub fn paid_buyer(
  reference_inputs: List<Input>,
  outputs: List<Output>,
  datums: Map<Hash<Data>, Data>,
  payment_datum: Data,
  bidding_details: BiddingDetails,
  metadata_keys: #(ByteArray, ByteArray),
) -> Bool {
  when bidding_details.requested_option is {
    SpecificValue(requested_value) ->
      exclude_lovelace(requested_value) == exclude_lovelace(
      value_paid_to_address_with_datum(
        outputs,
        bidding_details.owner,
        payment_datum,
      ))
      
    SpecificPolicyIdWithConstaints(policy_id, types, traits) -> {
      let requested_value =
        value_paid_to_address_with_datum(
          outputs,
          bidding_details.owner,
          payment_datum,
        )
      let #(sell_policy_id, sell_asset_name, _) =
        list.find(
          flatten_value(requested_value),
          fn(asset) {
            let #(p, _, _) = asset
            p == policy_id
          },
        )
      let metadata_input =
        list.find(
          reference_inputs,
          fn(input) {
            value_of(
              input.output.value,
              sell_policy_id,
              bytearray.concat(
                label_100,
                bytearray.drop(sell_asset_name, label_length),
              ),
            ) == 1
          },
        )
      let datum_metadata: DatumMetadata = when metadata_input.datum is {
        NoDatum -> todo
        DatumHash(h) -> {
          assert Some(datum) = map.get(datums, h)
          datum
        }
        Datum(datum) -> datum
      }
      let #(type_key, traits_key) = metadata_keys
      let metadata_type: ByteArray = {
        assert Some(t) = map.get(datum_metadata, type_key)
        t
      }
      let metadata_traits: List<ByteArray> = {
        assert Some(t) = map.get(datum_metadata, traits_key)
        t
      }
      let has_type = when types is {
        [] -> True
        l -> list.any(l, fn(requested_type) { requested_type == metadata_type })
      }
      let has_traits =
        list.all(
          traits,
          fn(requested_trait) {
            let #(negation, trait) = requested_trait
            if negation < 0 {
              !list.any(metadata_traits, fn(m_trait) { m_trait == trait })
            } else {
              list.any(metadata_traits, fn(m_trait) { m_trait == trait })
            }
          },
        )
      has_type && has_traits && policy_id == sell_policy_id
    }
  }
}

pub fn paid_seller(
  outputs: List<Output>,
  payment_datum: Data,
  listing_details: ListingDetails,
  remaining_lovelace: Int,
) -> Bool {
  lovelace_of(
  value_paid_to_address_with_datum(outputs, listing_details.owner, datum))
   >= remaining_lovelace
}

pub fn spend(
  protocol_key: Option<PublicKeyHash>,
  metadata_keys: #(ByteArray, ByteArray),
  royalty_token: RoyaltyToken,
  datum: TradeDatum,
  action: TradeAction,
  ctx: ScriptContext,
) -> Bool {
  let tx = ctx.transaction
  let inputs = tx.inputs
  let outputs = tx.outputs
  let reference_inputs = tx.reference_inputs
  let own_input = get_own_input(ctx)
  let own_value = own_input.output.value
  let payment_datum: Data =
    PaymentDatum { output_reference: own_input.output_reference }
  when action is {
    Sell -> {
      assert Bid(bidding_details) = datum
      let accepted_lovelace = lovelace_of(own_value)
      assert Some(_) =
        paid_fee(
          reference_inputs,
          outputs,
          payment_datum,
          accepted_lovelace,
          royalty_token,
        )
      paid_protocol(outputs, protocol_key) && paid_buyer(
        reference_inputs,
        outputs,
        tx.datums,
        payment_datum,
        bidding_details,
        metadata_keys,
      )
    }
    Buy -> {
      assert Listing(listing_details) = datum
      let accepted_lovelace = listing_details.requested_lovelace
      assert Some(remaining_lovelace) =
        paid_fee(
          reference_inputs,
          outputs,
          payment_datum,
          accepted_lovelace,
          royalty_token,
          protocol_key,
        )
      let checked_private_listing = when listing_details.private_listing is {
        Some(owner) -> tx_signed_by_address(tx, owner, own_value)
        None -> True
      }
      paid_protocol(outputs, protocol_key) && checked_private_listing && paid_seller(
        outputs,
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
      tx_signed_by_address(tx, owner, own_value)
    }
  }
}
