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
