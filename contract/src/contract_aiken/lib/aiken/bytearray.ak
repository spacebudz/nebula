use aiken/builtin

/// Extract a ByteArray as a slice of another ByteArray.
pub fn slice(bytes: ByteArray, start: Int, end: Int) -> ByteArray {
  builtin.slice_bytearray(start, end, bytes)
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

/// Returns the number of bytes in a ByteArray.
pub fn length(bytes: ByteArray) -> Int {
  builtin.length_of_bytearray(bytes)
}

test length_1() {
  length(#[]) == 0
}

test length_2() {
  length(#[1, 2, 3]) == 3
}

/// Returns `True` is the given ByteArray is empty.
pub fn is_empty(bytes: ByteArray) -> Bool {
  builtin.length_of_bytearray(bytes) == 0
}

test is_empty_1() {
  is_empty(#[]) == True
}

test is_empty_2() {
  is_empty(#[1]) == False
}

/// Combine two ByteArray together.
pub fn concat(left front: ByteArray, right back: ByteArray) -> ByteArray {
  builtin.append_bytearray(front, back)
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

/// Add a byte element in front of a ByteArray.
///
/// Note: when the given byte is greater than 255, it wraps-around. So `256` is mapped to `0`, `257` to 1, and so forth.
pub fn prepend(rest: ByteArray, byte: Int) -> ByteArray {
  builtin.cons_bytearray(byte, rest)
}

test prepend_1() {
  prepend(#[], 0) == #[0]
}

test prepend_2() {
  prepend(#[2, 3], 1) == #[1, 2, 3]
}

test prepend_3() {
  let x = 257
  prepend(#[2, 3], x) == #[1, 2, 3]
}

/// Returns the suffix of a ByteArray after n elements.
pub fn drop(bytes: ByteArray, n: Int) -> ByteArray {
  builtin.slice_bytearray(n, builtin.length_of_bytearray(bytes) - n, bytes)
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

/// Returns the n length prefix of a ByteArray.
pub fn take(bytes: ByteArray, n: Int) -> ByteArray {
  builtin.slice_bytearray(0, n, bytes)
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
