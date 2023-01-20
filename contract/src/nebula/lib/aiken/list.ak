use aiken/builtin

/// Determine if all elements of the list satisfy the given predicate.
///
/// Note: an empty list always satisfies the predicate.
pub fn all(self: List<a>, predicate: fn(a) -> Bool) -> Bool {
  when self is {
    [] -> True
    [x, ..xs] -> predicate(x) && all(xs, predicate)
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

/// Like [all](#and) but when elements are already booleans.
///
/// Note: an empty list always satisfies the predicate.
pub fn and(self: List<Bool>) -> Bool {
  when self is {
    [] -> True
    [x, ..xs] -> x && and(xs)
  }
}

test and_1() {
  and([True, True, True])
}

test and_2() {
  !and([True, False, True])
}

test and_3() {
  and([])
}

/// Determine if at least one element of the list satisfies the given predicate.
///
/// Note: an empty list never satisfies the predicate.
pub fn any(self: List<a>, predicate: fn(a) -> Bool) -> Bool {
  when self is {
    [] -> False
    [x, ..xs] -> predicate(x) || any(xs, predicate)
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

/// Like [any](#any) but when elements are already booleans.
///
/// Note: an empty list never satisfies the predicate.
pub fn or(self: List<Bool>) -> Bool {
  when self is {
    [] -> False
    [x, ..xs] -> x || or(xs)
  }
}

test or_1() {
  or([True, True])
}

test or_2() {
  or([True, False, True])
}

test or_3() {
  !or([])
}

test or_4() {
  !or([False, False])
}

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

/// Drop the first `n` elements of a list.
pub fn drop(self: List<a>, n: Int) -> List<a> {
  if n <= 0 {
    self
  } else {
    when self is {
      [] -> []
      [_x, ..xs] -> drop(xs, n - 1)
    }
  }
}

test drop_1() {
  drop([], 42) == []
}

test drop_2() {
  drop([1, 2, 3], 2) == [3]
}

/// Produce a list of elements that statisfy a predicate.
pub fn filter(self: List<a>, predicate: fn(a) -> Bool) -> List<a> {
  when self is {
    [] -> []
    [x, ..xs] ->
      if predicate(x) {
        [x, ..filter(xs, predicate)]
      } else {
        filter(xs, predicate)
      }
  }
}

test filter_1() {
  filter([], fn(x) { x > 0 }) == []
}

test filter_2() {
  let xs = [1, 2, 3, 4, 5, 6]
  filter(xs, fn(x) { builtin.mod_integer(x, 2) == 0 }) == [2, 4, 6]
}

test filter_3() {
  let filter_foldr = fn(xs, f) {
    foldr(
      xs,
      fn(x, ys) {
        if f(x) {
          [x, ..ys]
        } else {
          ys
        }
      },
      [],
    )
  }

  let is_odd = fn(n) { builtin.mod_integer(n, 2) != 0 }

  filter_foldr([1, 2, 3], is_odd) == filter([1, 2, 3], is_odd)
}

/// Produce a list of transformed elements that statisfy a predicate.
pub fn filter_map(self: List<a>, predicate: fn(a) -> Option<b>) -> List<b> {
  when self is {
    [] -> []
    [x, ..xs] ->
      when predicate(x) is {
        None -> filter_map(xs, predicate)
        Some(y) -> [y, ..filter_map(xs, predicate)]
      }
  }
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

/// Find the first element satisfying the given predicate, if any.
pub fn find(self: List<a>, predicate: fn(a) -> Bool) -> Option<a> {
  when self is {
    [] -> None
    [x, ..xs] ->
      if predicate(x) {
        Some(x)
      } else {
        find(xs, predicate)
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

/// Map elements of a list into a new list and flatten the result.
pub fn flat_map(self: List<a>, with: fn(a) -> List<b>) -> List<b> {
  foldr(self, fn(x, xs) { concat(with(x), xs) }, [])
}

test flat_map_1() {
  flat_map([], fn(a) { [a] }) == []
}

test flat_map_2() {
  flat_map([1, 2, 3], fn(a) { [a, a] }) == [1, 1, 2, 2, 3, 3]
}

/// Reduce a list from left to right.
pub fn foldl(self: List<a>, with: fn(a, b) -> b, zero: b) -> b {
  when self is {
    [] -> zero
    [x, ..xs] -> foldl(xs, with, with(x, zero))
  }
}

test foldl_1() {
  foldl([], fn(_, _) { 1 }, 0) == 0
}

test foldl_2() {
  foldl([1, 2, 3, 4, 5], fn(n, total) { n + total }, 0) == 15
}

test foldl_3() {
  foldl([1, 2, 3, 4], fn(x, xs) { [x, ..xs] }, []) == [4, 3, 2, 1]
}

/// Reduce a list from right to left.
pub fn foldr(self: List<a>, with: fn(a, b) -> b, zero: b) -> b {
  when self is {
    [] -> zero
    [x, ..xs] -> with(x, foldr(xs, with, zero))
  }
}

test foldr_1() {
  foldr([1, 2, 3, 4, 5], fn(n, total) { n + total }, 0) == 15
}

test foldr_2() {
  foldr(
    [1, 2, 3],
    fn(n, _str) {
      if builtin.mod_integer(n, 2) == 0 {
        "foo"
      } else {
        "bar"
      }
    },
    "",
  ) == "bar"
}

test foldr_3() {
  foldr([1, 2, 3, 4], fn(x, xs) { [x, ..xs] }, []) == [1, 2, 3, 4]
}

/// Figures out whether a list contain the given element.
pub fn has(self: List<a>, elem: a) -> Bool {
  when self is {
    [] -> False
    [x, ..xs] ->
      if x == elem {
        True
      } else {
        has(xs, elem)
      }
  }
}

test has_1() {
  has([1, 2, 3], 1) == True
}

test has_2() {
  has([1, 2, 3], 14) == False
}

test has_3() {
  has([], 14) == False
}

/// Get the first element of a list
pub fn head(self: List<a>) -> Option<a> {
  when self is {
    [] -> None
    _ -> Some(builtin.head_list(self))
  }
}

test head_1() {
  head([1, 2, 3]) == Some(1)
}

test head_2() {
  head([]) == None
}

pub fn indexed_foldr(
  self: List<a>,
  with: fn(Int, a, result) -> result,
  zero: result,
) -> result {
  do_indexed_foldr(0, self, with, zero)
}

fn do_indexed_foldr(
  n: Int,
  self: List<a>,
  with: fn(Int, a, result) -> result,
  zero: result,
) -> result {
  when self is {
    [] -> zero
    [x, ..xs] -> with(n, x, do_indexed_foldr(n + 1, xs, with, zero))
  }
}

test indexed_foldr_1() {
  indexed_foldr([], fn(i, x, xs) { i + x + xs }, 0) == 0
}

test indexed_foldr_2() {
  let letters = ["a", "b", "c"]
  indexed_foldr(letters, fn(i, x, xs) { [(i, x), ..xs] }, []) == [
    (0, "a"),
    (1, "b"),
    (2, "c"),
  ]
}

/// Apply a function to each element of a list.
pub fn indexed_map(self: List<a>, with: fn(Int, a) -> result) -> List<result> {
  do_indexed_map(0, self, with)
}

fn do_indexed_map(
  n: Int,
  self: List<a>,
  with: fn(Int, a) -> result,
) -> List<result> {
  when self is {
    [] -> []
    [x, ..xs] -> [with(n, x), ..do_indexed_map(n + 1, xs, with)]
  }
}

test indexed_map_1() {
  indexed_map([], fn(i, _n) { i }) == []
}

test indexed_map_2() {
  indexed_map(
    [4, 8, 13, 2],
    fn(i, n) {
      if n == 8 {
        n
      } else {
        i
      }
    },
  ) == [0, 8, 2, 3]
}

/// Checks whether a list is empty.
pub fn is_empty(self: List<a>) -> Bool {
  when self is {
    [] -> True
    _ -> False
  }
}

test is_empty_1() {
  is_empty([]) == True
}

test is_empty_2() {
  is_empty([1, 2, 3]) == False
}

/// Get the number of elements in the given list.
pub fn length(self: List<a>) -> Int {
  when self is {
    [] -> 0
    [_, ..xs] -> 1 + length(xs)
  }
}

test length_1() {
  length([]) == 0
}

test length_2() {
  length([1, 2, 3]) == 3
}

/// Apply a function to each element of a list.
pub fn map(self: List<a>, with: fn(a) -> result) -> List<result> {
  when self is {
    [] -> []
    [x, ..xs] -> [with(x), ..map(xs, with)]
  }
}

test map_1() {
  map([], fn(n) { n + 1 }) == []
}

test map_2() {
  map([1, 2, 3, 4], fn(n) { n + 1 }) == [2, 3, 4, 5]
}

/// Apply a function of two arguments, combining elements from two lists.
///
/// Note: if one list is longer, the extra elements are dropped.
pub fn map2(
  self: List<a>,
  bs: List<b>,
  with: fn(a, b) -> result,
) -> List<result> {
  when self is {
    [] -> []
    [x, ..xs] ->
      when bs is {
        [] -> []
        [y, ..ys] -> [with(x, y), ..map2(xs, ys, with)]
      }
  }
}

test map2_1() {
  map2([], [1, 2, 3], fn(a, b) { a + b }) == []
}

test map2_2() {
  map2([1, 2, 3], [1, 2], fn(a, b) { a + b }) == [2, 4]
}

test map2_3() {
  map2([42], [1, 2, 3], fn(_a, b) { Some(b) }) == [Some(1)]
}

/// Apply a function of three arguments, combining elements from three lists.
///
/// Note: if one list is longer, the extra elements are dropped.
pub fn map3(
  self: List<a>,
  bs: List<b>,
  cs: List<c>,
  with: fn(a, b, c) -> result,
) -> List<result> {
  when self is {
    [] -> []
    [x, ..xs] ->
      when bs is {
        [] -> []
        [y, ..ys] ->
          when cs is {
            [] -> []
            [z, ..zs] -> [with(x, y, z), ..map3(xs, ys, zs, with)]
          }
      }
  }
}

test map3_1() {
  map3([], [], [1, 2, 3], fn(a, b, c) { a + b + c }) == []
}

test map3_2() {
  map3([1, 2, 3], [1, 2], [1, 2, 3], fn(a, b, c) { a + b + c }) == [3, 6]
}

/// Add an element in front of the list. Sometimes useful when combined with
/// other functions.
///
/// ```aiken
/// use aiken/list
///
/// list.push([2, 3], 1) == [1, ..[2, 3]] == [1, 2, 3]
/// ```
pub fn push(self: List<a>, elem: a) -> List<a> {
  [elem, ..self]
}

test push_1() {
  push([], 0) == [0]
}

test push_2() {
  push([2, 3], 1) == [1, 2, 3]
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
  range(-1, 1) == [-1, 0, 1]
}

/// Construct a list filled with n copies of a value.
pub fn repeat(elem: a, n_times: Int) -> List<a> {
  if n_times <= 0 {
    []
  } else {
    [elem, ..repeat(elem, n_times - 1)]
  }
}

test repeat_1() {
  repeat(42, 0) == []
}

test repeat_2() {
  repeat(14, 3) == [14, 14, 14]
}

/// Get the number of elements in the given list.
pub fn reverse(self: List<a>) -> List<a> {
  foldl(self, fn(x, xs) { [x, ..xs] }, [])
}

test reverse_1() {
  reverse([]) == []
}

test reverse_2() {
  reverse([1, 2, 3]) == [3, 2, 1]
}

/// Get elements of a list after the first one, if any
pub fn tail(self: List<a>) -> Option<List<a>> {
  when self is {
    [] -> None
    [_, ..xs] -> Some(xs)
  }
}

test tail_1() {
  tail([1, 2, 3]) == Some([2, 3])
}

test tail_2() {
  tail([]) == None
}

/// Get the first `n` elements of a list.
pub fn take(self: List<a>, n: Int) -> List<a> {
  if n <= 0 {
    []
  } else {
    when self is {
      [] -> []
      [x, ..xs] -> [x, ..take(xs, n - 1)]
    }
  }
}

test take_1() {
  take([], 42) == []
}

test take_2() {
  take([1, 2, 3], 2) == [1, 2]
}

/// Removes duplicate elements from a list.
///
/// ```aiken
/// use aiken/list
///
/// list.unique([1,2,3,1])
/// // [1,2,3]
/// ```
pub fn unique(self: List<a>) -> List<a> {
  when self is {
    [] -> []
    [x, ..xs] -> [x, ..unique(filter(xs, fn(y) { y != x }))]
  }
}

test unique_1() {
  unique([]) == []
}

test unique_2() {
  let xs = [1, 2, 3, 1, 1, 3, 4, 1, 2, 3, 2, 4, 5, 6, 7, 8, 9, 10, 9]
  unique(xs) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
}

/// Decompose a list of tuples into a tuple of lists.
pub fn unzip(self: List<(a, b)>) -> (List<a>, List<b>) {
  when self is {
    [] -> ([], [])
    [(a, b), ..xs] -> {
      let (a_tail, b_tail) = unzip(xs)
      ([a, ..a_tail], [b, ..b_tail])
    }
  }
}

test unzip_1() {
  unzip([]) == ([], [])
}

test unzip_2() {
  unzip([(1, "a"), (2, "b")]) == ([1, 2], ["a", "b"])
}

/// Combine two lists together.
///
/// Note: if one list is longer, the extra elements are dropped.
pub fn zip(self: List<a>, bs: List<b>) -> List<(a, b)> {
  when self is {
    [] -> []
    [x, ..xs] ->
      when bs is {
        [] -> []
        [y, ..ys] -> [(x, y), ..zip(xs, ys)]
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
  zip([1, 2], ["a", "b", "c"]) == [(1, "a"), (2, "b")]
}
