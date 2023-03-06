// CIP-0067
pub const label_length = 4

pub const label_100 = #"000643b0"

pub const label_500 = #"001f4d70"

pub const label_600 = #"00258a50"

//  type_key and traits_key are reserved keywords in the metadata (datum). Any projects that wants to make use of collection offers/bids needs to follow these keywords.
//  type_key expected a UTF-8 encoded string (ByteArray) and traits_key an array of UTF-8 encoded strings (List<ByteArray>)
//  Your NFTs need to be CIP-0068 compliant.
// 
//  Example metadata:
//  ```json
//   {
//     "image": "ipfs://..",
//     "name": "SpaceBud #650",
//     "type": "Bear",
//     "traits": ["Chestplate", "Belt", "..."]
//   }
//  ```
pub const type_key = #"74797065"

pub const traits_key = #"747261697473"
