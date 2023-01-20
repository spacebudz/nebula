use aiken/builtin.{
  append_bytearray, decode_utf8, encode_utf8, length_of_bytearray,
}

/// Combine two `String` together.
///
/// ```aiken
/// use aiken.string
///
/// string.concat(left: "Hello", right: ", World!")
/// // "Hello, World!"
/// ```
pub fn concat(left: String, right: String) -> String {
  append_bytearray(encode_utf8(left), encode_utf8(right))
  |> decode_utf8
}

test concat_1() {
  concat("", "") == ""
}

test concat_2() {
  concat("", "foo") == concat("foo", "")
}

test concat_3() {
  concat(left: "Hello", right: ", World!") == "Hello, World!"
}

/// Convert a `ByteArray` into a `String`
pub fn from_bytearray(bytes: ByteArray) -> String {
  decode_utf8(bytes)
}

test from_bytearray_1() {
  from_bytearray(#[]) == ""
}

test from_bytearray_2() {
  from_bytearray(#[65, 66, 67]) == "ABC"
}

/// Convert an `Int` to its `String` representation.
///
/// ```aiken
/// use builtin/string
///
/// string.from_int(42)
/// // "42"
/// ```
pub fn from_int(n: Int) -> String {
  from_bytearray(do_from_int(n, #[]))
}

fn do_from_int(i: Int, digits: ByteArray) -> ByteArray {
  if i == 0 {
    if builtin.length_of_bytearray(digits) == 0 {
      #[48]
    } else {
      digits
    }
  } else {
    let r = builtin.remainder_integer(i, 10)
    let q = builtin.quotient_integer(i, 10)
    do_from_int(q, builtin.cons_bytearray(r + 48, digits))
  }
}

test from_int_1() {
  from_int(0) == "0"
}

test from_int_2() {
  from_int(5) == "5"
}

test from_int_3() {
  from_int(42) == "42"
}

test from_int_4() {
  from_int(200) == "200"
}

/// Join a list of strings, separated by a given _delimiter_.
///
/// ```aiken
/// use aiken/string
///
/// string.join(["a", "b", "c"], ",")
/// // "a,b,c"
/// ```
pub fn join(list: List<String>, delimiter: String) -> String {
  do_join(list, encode_utf8(delimiter), #[])
  |> decode_utf8
}

fn do_join(xs, delimiter, bytes) {
  when xs is {
    [] -> bytes
    [x, ..rest] ->
      do_join(
        rest,
        delimiter,
        if length_of_bytearray(bytes) == 0 {
          encode_utf8(x)
        } else {
          append_bytearray(bytes, append_bytearray(delimiter, encode_utf8(x)))
        },
      )
  }
}

test join_1() {
  join([], ",") == ""
}

test join_2() {
  join(["a", "b", "c"], ",") == "a,b,c"
}

/// Convert a `String` into a `ByteArray`
pub fn to_bytearray(self: String) -> ByteArray {
  encode_utf8(self)
}

test to_bytearray_1() {
  to_bytearray("") == #[]
}

test to_bytearray_2() {
  to_bytearray("ABC") == #[65, 66, 67]
}
