use aiken/builtin

/// Merge two lists together.
pub fn concat(left: List<a>, right: List<a>) -> List<a> {
  foldr(left, fn(x, xs) { [x, ..xs] }, right)
}

test concat_1() {
  concat([1, 2, 3], [4, 5, 6]) == [1, 2, 3, 4, 5, 6]
}

test concat_2() {
  concat([1, 2, 3], []) == [1, 2, 3]
}

test concat_3() {
  concat([], [1, 2, 3]) == [1, 2, 3]
}

/// Construct a list filled with n copies of a value.
pub fn repeat(x: a, n: Int) -> List<a> {
  if n <= 0 {
    []
  } else {
    [x, ..repeat(x, n - 1)]
  }
}

test repeat_1() {
  repeat(42, 0) == []
}

test repeat_2() {
  repeat(14, 3) == [14, 14, 14]
}

/// Construct a list of a integer from a given range.
pub fn range(from: Int, to: Int) -> List<Int> {
  if from > to {
    []
  } else {
    [from, ..range(from + 1, to)]
  }
}

test range_1() {
  range(0, 3) == [0, 1, 2, 3]
}

test range_2() {
  todo
  // range(-1, 1) == [-1, 0, 1]
}

/// Combine two lists together.
///
/// Note: if one list is longer, the extra elements are dropped.
pub fn zip(xs: List<a>, ys: List<b>) -> List<#(a, b)> {
  when xs is {
    [] -> []
    [x, ..rest_x] ->
      when ys is {
        [] -> []
        [y, ..rest_y] -> [#(x, y), ..zip(rest_x, rest_y)]
      }
  }
}

test zip_1() {
  zip([], [1, 2, 3]) == []
}

test zip_2() {
  zip([1, 2, 3], []) == []
}

test zip_3() {
  zip([1, 2], ["a", "b", "c"]) == [#(1, "a"), #(2, "b")]
}

/// Decompose a list of tuples into a tuple of lists.
pub fn unzip(xs: List<#(a, b)>) -> #(List<a>, List<b>) {
  when xs is {
    [] -> #([], [])
    [#(a, b), ..rest] -> {
      let #(a_tail, b_tail) = unzip(rest)
      #([a, ..a_tail], [b, ..b_tail])
    }
  }
}

// TODO: acceptance_test 015
//
//test unzip_1() {
//  unzip([]) == #([], [])
//}
//
//test unzip_2() {
//  unzip([#(1, "a"), #(2, "b")]) == #([1, 2], ["a", "b"])
//}
/// Get the number of elements in the given list.
pub fn reverse(xs: List<a>) -> List<a> {
  foldl(xs, fn(x, rest) { [x, ..rest] }, [])
}

test reverse_1() {
  reverse([]) == []
}

test reverse_2() {
  reverse([1, 2, 3]) == [3, 2, 1]
}

/// Figures out whether a list contain the given element.
pub fn is_elem(xs: List<a>, x: a) -> Bool {
  when xs is {
    [] -> False
    [y, ..rest] ->
      if x == y {
        True
      } else {
        is_elem(rest, x)
      }
  }
}

/// Get the first element of a list
pub fn head(xs: List<a>) -> Option<a> {
  when xs is {
    [] -> None
    _ -> Some(builtin.head_list(xs))
  }
}

test head_1() {
  head([1, 2, 3]) == Some(1)
}

test head_2() {
  head([]) == None
}

/// Get elements of a list after the first one, if any
pub fn tail(xs: List<a>) -> Option<List<a>> {
  when xs is {
    [] -> None
    [_, ..rest] -> Some(rest)
  }
}

test tail_1() {
  tail([1, 2, 3]) == Some([2, 3])
}

test tail_2() {
  tail([]) == None
}

/// Get the first `n` elements of a list.
pub fn take(xs: List<a>, n: Int) -> List<a> {
  if n <= 0 {
    []
  } else {
    when xs is {
    [] -> []
    [x, ..rest] -> [x, ..take(rest, n - 1)]
  }
  }
}

test take_1() {
  take([], 42) == []
}

test take_2() {
  take([1, 2, 3], 2) == [1, 2]
}

/// Drop the first `n` elements of a list.
pub fn drop(xs: List<a>, n: Int) -> List<a> {
  if n <= 0 {
    xs
  } else {
    when xs is {
    [] -> []
    [_x, ..rest] -> drop(rest, n - 1)
  }
  }
}

test drop_1() {
  drop([], 42) == []
}

test drop_2() {
  drop([1, 2, 3], 2) == [3]
}

/// Get the number of elements in the given list.
pub fn length(xs: List<a>) -> Int {
  when xs is {
    [] -> 0
    [_, ..rest] -> 1 + length(rest)
  }
}

test length_1() {
  length([]) == 0
}

test length_2() {
  length([1, 2, 3]) == 3
}

test is_elem_1() {
  is_elem([1, 2, 3], 1) == True
}

test is_elem_2() {
  is_elem([1, 2, 3], 14) == False
}

test is_elem_3() {
  is_elem([], 14) == False
}

/// Determine if all elements of the list satisfy the given predicate.
///
/// Note: an empty list always satisfies the predicate.
pub fn all(xs: List<a>, predicate: fn(a) -> Bool) -> Bool {
  when xs is {
    [] -> True
    [x, ..rest] -> predicate(x) && all(rest, predicate)
  }
}

test all_1() {
  all([1, 2, 3], fn(n) { n > 0 }) == True
}

test all_2() {
  all([1, 2, 3], fn(n) { n > 42 }) == False
}

test all_3() {
  all([], fn(n) { n == 42 }) == True
}

/// Determine if at least one element of the list satisfies the given predicate.
///
/// Note: an empty list always satisfies the predicate.
pub fn any(xs: List<a>, predicate: fn(a) -> Bool) -> Bool {
  when xs is {
    [] -> False
    // TODO: compare cost with an if-then-else approach that only recurses if the predicate is false.
    [x, ..rest] -> predicate(x) || any(rest, predicate)
  }
}

test any_1() {
  any([1, 2, 3], fn(n) { n > 0 }) == True
}

test any_2() {
  any([1, 2, 3], fn(n) { n > 42 }) == False
}

test any_3() {
  any([], fn(n) { n == 42 }) == False
}

/// Apply a function to each element of a list.
pub fn map(xs: List<a>, f: fn(a) -> result) -> List<result> {
  when xs is {
    [] -> []
    [x, ..rest] -> [f(x), ..map(rest, f)]
  }
}

test map_1() {
  map([], fn(n) { n + 1 }) == []
}

// TODO: acceptance_test 020
//
// test map_2() {
//   map([1, 2, 3, 4], fn(n) { n + 1 }) == [2, 3, 4, 5]
// }
/// Apply a function of two arguments, combining elements from two lists.
///
/// Note: if one list is longer, the extra elements are dropped.
pub fn map2(xs: List<a>, ys: List<b>, f: fn(a, b) -> result) -> List<result> {
  when xs is {
    [] -> []
    [x, ..rest_x] ->
      when ys is {
        [] -> []
        [y, ..rest_y] -> [f(x, y), ..map2(rest_x, rest_y, f)]
      }
  }
}

/// Apply a function of three arguments, combining elements from three lists.
///
/// Note: if one list is longer, the extra elements are dropped.
pub fn map3(
  xs: List<a>,
  ys: List<b>,
  zs: List<c>,
  f: fn(a, b, c) -> result,
) -> List<result> {
  when xs is {
    [] -> []
    [x, ..rest_x] ->
      when ys is {
        [] -> []
        [y, ..rest_y] ->
          when zs is {
            [] -> []
            [z, ..rest_z] -> [f(x, y, z), ..map3(rest_x, rest_y, rest_z, f)]
          }
      }
  }
}

/// Reduce a list from left to right.
pub fn foldl(xs: List<a>, f: fn(a, b) -> b, zero: b) -> b {
  when xs is {
    [] -> zero
    [x, ..rest] -> foldl(rest, f, f(x, zero))
  }
}

test foldl_1() {
  foldl([1, 2, 3, 4, 5], fn(n, total) { n + total }, 0) == 15
}

/// Reduce a list from right to left.
pub fn foldr(xs: List<a>, f: fn(a, b) -> b, zero: b) -> b {
  when xs is {
    [] -> zero
    [x, ..rest] -> f(x, foldr(rest, f, zero))
  }
}

test foldr_1() {
  foldr([1, 2, 3, 4, 5], fn(n, total) { n + total }, 0) == 15
}

/// Produce a list from elements that statisfy a predicate.
pub fn filter(xs: List<a>, f: fn(a) -> Bool) -> List<a> {
  when xs is {
    [] -> []
    [x, ..rest] ->
      if f(x) {
        [x, ..filter(rest, f)]
      } else {
        filter(rest, f)
      }
  }
}

// TODO: acceptance_test 012
// test filter_1() {
//   filter([], fn(x) { x > 0 }) == []
// }
//
// test filter_2() {
//   filter([1,
//       2, 3, 4, 5, 6], fn(x) { builtin.mod_integer(x, 2) == 0 }) == [2, 4, 6]
// }
/// Find the first element satisfying the given predicate, if any.
pub fn find(xs: List<a>, f: fn(a) -> Bool) -> Option<a> {
  when xs is {
    [] -> None
    [x, ..rest] ->
      if f(x) {
        Some(x)
      } else {
        find(rest, f)
      }
  }
}

test find_1() {
  find([1, 2, 3], fn(x) { x == 1 }) == Some(1)
}

test find_2() {
  find([1, 2, 3], fn(x) { x > 42 }) == None
}

test find_3() {
  find([], fn(_) { True }) == None
}

/// Produce a list from elements that statisfy a predicate.
pub fn filter_map(xs: List<a>, f: fn(a) -> Option<b>) -> List<b> {
  foldr(
    xs,
    fn(x, ys) {
      when f(x) is {
        None -> ys
        Some(y) -> [y, ..ys]
      }
    },
    [],
  )
}

test filter_map_1() {
  filter_map([], fn(_) { Some(42) }) == []
}

test filter_map_2() {
  filter_map(
    [1, 2, 3, 4, 5, 6],
    fn(x) {
      if builtin.mod_integer(x, 2) != 0 {
        Some(3 * x)
      } else {
        None
      }
    },
  ) == [3, 9, 15]
}

/// Map elements of a list into a new list and flatten the result.
pub fn flat_map(xs: List<a>, f: fn(a) -> List<b>) -> List<b> {
  foldr(xs, fn(x, ys) { concat(f(x), ys) }, [])
}
