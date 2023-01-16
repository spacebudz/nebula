use aiken/builtin
use aiken/bytearray
use aiken/dict.{Dict}
use aiken/hash.{Blake2b_224, Blake2b_256, Hash}
use aiken/list
use aiken/transaction.{
  DatumHash, InlineDatum, Input, NoDatum, Output, OutputReference, ScriptContext,
  ScriptPurpose, Spend, Transaction,
}
use aiken/transaction/credential.{
  Address, PublicKeyCredential, ScriptCredential, VerificationKey,
}
use aiken/transaction/value.{AssetName, PolicyId, Value}

type PublicKeyHash =
  Hash<Blake2b_224, VerificationKey>

type ListingDetails {
  owner: Address,
  requested_lovelace: Int,
  private_listing: Option<Address>,
}

type BiddingDetails {
  owner: Address,
  requested_option: BidOption,
}

type RoyaltyInfo {
  recipients: List<RoyaltyRecipient>,
  min_ada: Int,
}

type RoyaltyRecipient {
  address: Address,
  fee: Int,
  fixed_fee: Int,
}

type Metadata =
  Dict<ByteArray, Data>

type DatumMetadata {
  metadata: Metadata,
  version: Int,
}

type BidOption {
  SpecificValue(Value)
  SpecificPolicyIdWithConstraints(
    PolicyId,
    List<ByteArray>,
    List<(Int, ByteArray)>,
  )
}

type RoyaltyToken {
  policy_id: PolicyId,
  asset_name: AssetName,
}

type TradeDatum {
  Listing(ListingDetails)
  Bid(BiddingDetails)
}

type TradeAction {
  Sell
  Buy
  Cancel
}

type PaymentDatum {
  output_reference: OutputReference,
}

type MetadataKeys {
  type_key: ByteArray,
  traits_key: ByteArray,
}

// CIP-0067
const label_length = 4

const label_100 = #[0, 6, 67, 176]

// '(2)ScriptOwner' in UTF-8
// Has 2 as label (private use)
const script_owner = #[0,
  0,
  32,
  224,
  83,
  99,
  114,
  105,
  112,
  116,
  79,
  119,
  110,
  101,
  114,
]

fn get_own_input(ctx: ScriptContext) -> Input {
  assert Spend(output_reference) = ctx.purpose
  let tx = ctx.transaction
  assert Some(input) =
    list.find(
      tx.inputs,
      fn(input) { input.output_reference == output_reference },
    )
  input
}

pub fn without_lovelace(value: Value) -> Value {
  // dict.delete(value.inner, #[]) TODO
  value
}

/// This is a special signing function. 
/// Signer can not only be a pub key hash, but also a script.
/// For pub key hashes it's trivial, but as script owner you need to lock a special
/// NFT with the asset name 'ScriptOwner' at the UTxO. You decide the script logic behind the minting policy.
/// Only if you can successfully burn the NFT then the Nebula contract allows you to redeem the value in case of a Cancel operation.
/// Note: Collisions with other assets having the name 'ScriptOwner' should be avoided!
fn tx_signed_by_address(tx: Transaction, owner: Address, value: Value) -> Bool {
  when owner.payment_credential is {
    PublicKeyCredential(keyhash) -> list.has(tx.extra_signatories, keyhash)
    ScriptCredential(scripthash) ->
      when
        list.find(
          value.flatten(value),
          fn(asset) {
            let (_, asset_name, _) = asset
            asset_name == script_owner
          },
        )
      is {
        Some((policy_id, asset_name, _)) ->
          value.quantity_of(tx.mint, policy_id, asset_name) < 0
        None -> False
      }
  }
}

/// We assume outputs are unique because of datum tagging.
/// We also assume the datum is inline
fn value_paid_to_with_datum(
  tx: Transaction,
  address: Address,
  datum: Data,
) -> Value {
  assert [output] =
    list.filter(
      tx.outputs,
      fn(output) {
        output.address == address && output.datum == InlineDatum(datum)
      },
    )
  output.value
}

fn checked_fee_recipients(
  tx: Transaction,
  royalty_info: RoyaltyInfo,
  payment_datum: Data,
  accepted_lovelace: Int,
  remaining_lovelace: Int,
) -> Option<Int> {
  when royalty_info.recipients is {
    [] -> Some(remaining_lovelace)
    [fee_recipient, ..remaining_recipients] -> {
      let fee_to_pay = accepted_lovelace * 10 / fee_recipient.fee
      let adjusted_fee =
        if fee_to_pay < royalty_info.min_ada {
          fee_recipient.fixed_fee
        } else {
          fee_to_pay
        }
      let new_lovelace = remaining_lovelace - adjusted_fee
      let has_paid =
        value.lovelace_of(
        value_paid_to_with_datum(tx, fee_recipient.address, payment_datum))
         >= adjusted_fee && new_lovelace > 0
      if has_paid {
        checked_fee_recipients(
          tx,
          royalty_info,
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

fn paid_fee(
  tx: Transaction,
  payment_datum: Data,
  accepted_lovelace: Int,
  royalty_token: RoyaltyToken,
  protocol_key: Option<PublicKeyHash>,
) -> Option<Int> {
  let reference_inputs = tx.reference_inputs
  assert Some(royalty_input) =
    list.find(
      reference_inputs,
      fn(input) {
        value.quantity_of(
          input.output.value,
          royalty_token.policy_id,
          royalty_token.asset_name,
        ) == 1
      },
    )
  assert InlineDatum(datum) = royalty_input.output.datum
  let royalty_info: RoyaltyInfo = datum
  checked_fee_recipients(
    tx,
    royalty_info,
    payment_datum,
    accepted_lovelace,
    accepted_lovelace,
  )
}

fn paid_buyer(
  tx: Transaction,
  payment_datum: Data,
  bidding_details: BiddingDetails,
  metadata_keys: MetadataKeys,
) -> Bool {
  when bidding_details.requested_option is {
    SpecificValue(requested_value) ->
      without_lovelace(requested_value) == without_lovelace(
      value_paid_to_with_datum(tx, bidding_details.owner, payment_datum))
      
    SpecificPolicyIdWithConstraints(policy_id, types, traits) -> {
      let requested_value =
        value_paid_to_with_datum(tx, bidding_details.owner, payment_datum)
      assert Some((sell_policy_id, sell_asset_name, _)) =
        list.find(
          value.flatten(requested_value),
          fn(asset) {
            let (p, _, _) = asset
            p == policy_id
          },
        )
      assert Some(metadata_input) =
        list.find(
          tx.reference_inputs,
          fn(input) {
            value.quantity_of(
              input.output.value,
              sell_policy_id,
              bytearray.concat(
                label_100,
                bytearray.drop(sell_asset_name, label_length),
              ),
            ) == 1
          },
        )
      let datum_metadata: DatumMetadata = when metadata_input.output.datum is {
        NoDatum -> error
        DatumHash(h) -> {
          assert Some(datum) = dict.get(tx.datums, h)
          datum
        }
        InlineDatum(datum) -> datum
      }
      let metadata_type: ByteArray = {
        assert Some(t) =
          dict.get(datum_metadata.metadata, metadata_keys.type_key)
        builtin.un_b_data(t)
      }
      let metadata_traits: List<ByteArray> = {
        assert Some(t) =
          dict.get(datum_metadata.metadata, metadata_keys.traits_key)
        list.map(builtin.un_list_data(t), fn(d) { builtin.un_b_data(d) })
      }
      let has_type = when types is {
        [] -> True
        l -> list.any(l, fn(requested_type) { requested_type == metadata_type })
      }
      let has_traits = when traits is {
        [] -> True
        l ->
          list.all(
            l,
            fn(requested_trait) {
              let (negation, trait) = requested_trait
              if negation < 0 {
                !list.any(metadata_traits, fn(m_trait) { m_trait == trait })
              } else {
                list.any(metadata_traits, fn(m_trait) { m_trait == trait })
              }
            },
          )
      }
      has_type && has_traits && policy_id == sell_policy_id
    }
  }
}

fn paid_seller(
  tx: Transaction,
  payment_datum: Data,
  listing_details: ListingDetails,
  remaining_lovelace: Int,
) -> Bool {
  value.lovelace_of(
  value_paid_to_with_datum(tx, listing_details.owner, payment_datum))
   >= remaining_lovelace
}

fn spend(
  protocol_key: Option<PublicKeyHash>,
  metadata_keys: MetadataKeys,
  royalty_token: RoyaltyToken,
  datum: TradeDatum,
  action: TradeAction,
  ctx: ScriptContext,
) -> Bool {
  let tx = ctx.transaction
  let own_input = get_own_input(ctx)
  let payment_datum: Data =
    PaymentDatum { output_reference: own_input.output_reference }

  when action is {
    Sell -> {
      assert Bid(bidding_details) = datum
      let accepted_lovelace = value.lovelace_of(own_input.output.value)
      assert Some(_) =
        paid_fee(
          tx,
          payment_datum,
          accepted_lovelace,
          royalty_token,
          protocol_key,
        )
      paid_protocol(tx, protocol_key) && paid_buyer(
        tx,
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
          tx,
          payment_datum,
          accepted_lovelace,
          royalty_token,
          protocol_key,
        )
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
