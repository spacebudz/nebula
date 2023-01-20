/// Provide a default value, turning an optional value into a normal value.
pub fn or_else(self: Option<a>, default: a) -> a {
  when self is {
    None -> default
    Some(a) -> a
  }
}

test or_else_1() {
  or_else(None, "aiken") == "aiken"
}

test or_else_2() {
  or_else(Some(42), 14) == 42
}

/// Apply a function to the inner value of an Option
pub fn map(self: Option<a>, with: fn(a) -> result) -> Option<result> {
  when self is {
    None -> None
    Some(a) -> Some(with(a))
  }
}

test map_1() {
  map(None, fn(_) { Void }) == None
}

test map_2() {
  map(Some(14), fn(n) { n + 1 }) == Some(15)
}

/// Combine two 'Option' together.
pub fn map2(
  opt_a: Option<a>,
  opt_b: Option<b>,
  with: fn(a, b) -> result,
) -> Option<result> {
  when opt_a is {
    None -> None
    Some(a) ->
      when opt_b is {
        None -> None
        Some(b) -> Some(with(a, b))
      }
  }
}

test map2_1() {
  map2(None, Some(42), fn(_, _) { 14 }) == None
}

test map2_2() {
  map2(Some(42), None, fn(_, _) { 14 }) == None
}

test map2_3() {
  map2(Some(14), Some(42), fn(a, b) { (a, b) }) == Some((14, 42))
}

pub fn map3(
  opt_a: Option<a>,
  opt_b: Option<b>,
  opt_c: Option<c>,
  with: fn(a, b, c) -> result,
) -> Option<result> {
  when opt_a is {
    None -> None
    Some(a) ->
      when opt_b is {
        None -> None
        Some(b) ->
          when opt_c is {
            None -> None
            Some(c) -> Some(with(a, b, c))
          }
      }
  }
}

test map3_1() {
  map3(None, Some(42), None, fn(_, _, _) { 14 }) == None
}

test map3_2() {
  map3(Some(42), None, None, fn(_, _, _) { 14 }) == None
}

test map3_3() {
  map3(Some(14), Some(42), Some(1337), fn(a, b, c) { c - a + b }) == Some(1365)
}

/// Chain together many computations that may fail.
pub fn and_then(
  self: Option<a>,
  then: fn(a) -> Option<result>,
) -> Option<result> {
  when self is {
    None -> None
    Some(a) -> then(a)
  }
}

fn try_decrement(n: Int) -> Option<Int> {
  if n > 0 {
    Some(n - 1)
  } else {
    None
  }
}

test and_then_1() {
  let result =
    None
    |> and_then(try_decrement)
  result == None
}

test and_then_2() {
  let result =
    Some(14)
    |> and_then(try_decrement)
  result == Some(13)
}

test and_then_3() {
  let result =
    Some(0)
    |> and_then(try_decrement)
  result == None
}

/// Converts from `Option<Option<a>>` to `Option<a>`.
///
/// # Examples
///
/// Basic usage:
///
/// ```aiken
/// use aiken/option
///
/// let x: Option<Option<Int>> = Some(Some(6))
/// Some(6) == flatten(x)
///
/// let x: Option<Option<Int>> = Some(None)
/// None == flatten(x)
///
/// let x: Option<Option<Int>> = None
/// None == flatten(x)
/// ```
///
/// Flattening only removes one level of nesting at a time:
///
/// ```aiken
/// let x: Option<Option<Option<Int>>> = Some(Some(Some(6)))
/// Some(Some(6)) == flatten(x)
/// Some(6) == { x |> flatten |> flatten }
/// ```
pub fn flatten(opt: Option<Option<a>>) -> Option<a> {
  when opt is {
    Some(inner) -> inner
    None -> None
  }
}

test flatten_1() {
  let x: Option<Option<Int>> = Some(Some(6))
  Some(6) == flatten(x)
}

test flatten_2() {
  let x: Option<Option<Int>> = Some(None)
  None == flatten(x)
}

test flatten_3() {
  let x: Option<Option<Int>> = None
  None == flatten(x)
}

test flatten_4() {
  let x: Option<Option<Option<Int>>> = Some(Some(Some(6)))

  let result =
    x
    |> flatten
    |> flatten

  Some(6) == result
}
