// CIP-0067
pub const label_length = 4

pub const label_100 = #[0, 6, 67, 176]

// '(2)ScriptOwner' in UTF-8
// Has 2 as label (private use)
pub const script_owner = #[0,
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
pub const type_key = #[116, 121, 112, 101]

pub const traits_key = #[116, 114, 97, 105, 116, 115]
