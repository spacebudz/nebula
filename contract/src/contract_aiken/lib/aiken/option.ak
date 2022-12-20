/// Provide a default value, turning an optional value into a normal value.
pub fn or_else(opt: Option<a>, default: a) -> a {
  when opt is {
    None -> default
    Some(a) -> a
  }
}

test or_else_1() {
  or_else(None, "aiken") == "aiken"
}

// TODO: acceptance test 018
//
// test or_else_2() {
//   or_else(Some(42), 14) == 42
// }

/// Apply a function to the inner value of an Option
pub fn map(opt: Option<a>, f: fn(a) -> result) -> Option<result> {
  when opt is {
    None -> None
    Some(a) -> Some(f(a))
  }
}

// TODO: acceptance_test 019
// Change all '14' to 'Nil'
test map_1() {
  map(None, fn(_) { 14 }) == None
}

// TODO: acceptance test 020
//
// test map_2() {
//   map(Some(14), fn(n) { n + 1 }) == Some(15)
// }

/// Combine two 'Option' together.
pub fn map2(
  opt_a: Option<a>,
  opt_b: Option<b>,
  f: fn(a, b) -> result,
) -> Option<result> {
  when opt_a is {
    None -> None
    Some(a) ->
      when opt_b is {
        None -> None
        Some(b) -> Some(f(a, b))
      }
  }
}

test map2_1() {
  map2(None, Some(42), fn(_, _) { 14 }) == None
}

test map2_2() {
  map2(Some(42), None, fn(_, _) { 14 }) == None
}

// TODO: acceptance_test 020
//
// test map2_3() {
//   map2(Some(14), Some(42), fn(a, b) { #(a, b) }) == Some(#(14, 42))
// }

pub fn map3(
  opt_a: Option<a>,
  opt_b: Option<b>,
  opt_c: Option<c>,
  f: fn(a, b, c) -> result,
) -> Option<result> {
  when opt_a is {
    None -> None
    Some(a) ->
      when opt_b is {
        None -> None
        Some(b) ->
          when opt_c is {
            None -> None
            Some(c) -> Some(f(a, b, c))
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

// TODO: acceptance_test 020
//
// test map3_3() {
//   map3(Some(14), Some(42), Some(1337), fn(a, b, c) { c - (a + b) }) == Some(1281)
// }

/// Chain together many computations that may fail.
pub fn and_then(opt: Option<a>, f: fn(a) -> Option<result>) -> Option<result> {
  when opt is {
    None -> None
    Some(a) -> f(a)
  }
}

// TODO: acceptance_test 010

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
// TODO: acceptance_test 020
//
// test and_then_2() {
//   let result =
//     Some(14)
//     |> and_then(try_decrement)
//   result == Some(13)
// }
//
// test and_then_3() {
//   let result =
//     Some(0)
//     |> and_then(try_decrement)
//   result == None
// }
