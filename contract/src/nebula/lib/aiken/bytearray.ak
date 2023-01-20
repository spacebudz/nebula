use aiken/builtin

/// Combine two `ByteArray` together.
///
/// ```aiken
/// use aiken/bytearray
///
/// bytearray.concat(left: #[1,2,3], right: #[4,5,6])
/// // #[1,2,3,4,5,6]
/// ```
pub fn concat(left: ByteArray, right: ByteArray) -> ByteArray {
  builtin.append_bytearray(left, right)
}

test concat_1() {
  concat(#[], #[]) == #[]
}

test concat_2() {
  concat(#[], #[1]) == #[1]
}

test concat_3() {
  concat(#[1, 2], #[]) == #[1, 2]
}

test concat_4() {
  concat(#[1, 2], #[3, 4]) == #[1, 2, 3, 4]
}

/// Returns the suffix of a `ByteArray` after `n` elements.
///
/// ```aiken
/// use aiken/bytearray
///
/// bytearray.drop(#[1,2,3], n: 2)
/// // #[3]
/// ```
pub fn drop(self: ByteArray, n: Int) -> ByteArray {
  builtin.slice_bytearray(n, builtin.length_of_bytearray(self) - n, self)
}

test drop_1() {
  let x = #[1, 2, 3, 4, 5, 6, 7]
  drop(x, 2) == #[3, 4, 5, 6, 7]
}

test drop_2() {
  let x = #[1, 2, 3, 4, 5, 6, 7]
  drop(x, 0) == x
}

test drop_3() {
  let x = #[1]
  drop(x, 1) == #[]
}

test drop_4() {
  let x = #[]
  drop(x, 2) == #[]
}

/// Returns the number of bytes in a `ByteArray`.
///
/// ```aiken
/// use aiken/bytearray
///
/// bytearray.length(#[1,2,3])
/// // 3
/// ```
pub fn length(self: ByteArray) -> Int {
  builtin.length_of_bytearray(self)
}

test length_1() {
  length(#[]) == 0
}

test length_2() {
  length(#[1, 2, 3]) == 3
}

/// Returns `True` when the given `ByteArray` is empty.
pub fn is_empty(self: ByteArray) -> Bool {
  builtin.length_of_bytearray(self) == 0
}

test is_empty_1() {
  is_empty(#[]) == True
}

test is_empty_2() {
  is_empty(#[1]) == False
}

/// Convert a `String` into a `ByteArray`.
pub fn from_string(str: String) -> ByteArray {
  builtin.encode_utf8(str)
}

test from_string_1() {
  from_string("") == #[]
}

test from_string_2() {
  from_string("ABC") == #[65, 66, 67]
}

/// Add a byte element in front of a `ByteArray`.
///
/// > **Note:**
/// > When the given byte is greater than 255, it wraps-around. So 256 is mapped to 0, 257 to 1, and so forth.
pub fn push(self: ByteArray, byte: Int) -> ByteArray {
  builtin.cons_bytearray(byte, self)
}

test push_1() {
  push(#[], 0) == #[0]
}

test push_2() {
  push(#[2, 3], 1) == #[1, 2, 3]
}

test push_3() {
  let x = 257
  push(#[2, 3], x) == #[1, 2, 3]
}

/// Extract a `ByteArray` as a slice of another `ByteArray`.
///
/// Indexes are 0-based and inclusive.
///
/// ```aiken
/// use aiken/bytearray
///
/// bytearray.slice(#[0,1,2,3,4,5,6], start: 1, end: 3)
/// // #[1,2,3]
/// ```
pub fn slice(self: ByteArray, start: Int, end: Int) -> ByteArray {
  builtin.slice_bytearray(start, end, self)
}

test slice_1() {
  slice(#[], 1, 2) == #[]
}

test slice_2() {
  slice(#[1, 2, 3], 1, 2) == #[2, 3]
}

test slice_3() {
  slice(#[1, 2, 3], 0, 42) == #[1, 2, 3]
}

/// Returns the n-length prefix of a `ByteArray`.
///
/// ```aiken
/// use aiken/bytearray
///
/// bytearray.take(#[1,2,3], n: 2)
/// // #[1,2]
/// ```
pub fn take(self: ByteArray, n: Int) -> ByteArray {
  builtin.slice_bytearray(0, n, self)
}

test take_1() {
  let x = #[1, 2, 3, 4, 5, 6, 7]
  take(x, 2) == #[1, 2]
}

test take_2() {
  let x = #[1, 2, 3, 4, 5, 6, 7]
  take(x, 0) == #[]
}

test take_3() {
  let x = #[1]
  take(x, 1) == x
}

test take_4() {
  let x = #[1, 2, 3]
  take(x, 0) == #[]
}

/// Convert a `ByteArray` into a `String`.
pub fn to_string(self: ByteArray) -> String {
  builtin.decode_utf8(self)
}

test to_string_1() {
  to_string(#[]) == ""
}

test to_string_2() {
  to_string(#[65, 66, 67]) == "ABC"
}
