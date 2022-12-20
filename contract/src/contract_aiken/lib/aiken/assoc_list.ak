//// A module for working with associative lists.
////
//// Associative lists are fundamentally ordered lists of key-value pairs,
//// which preserve some invariants. In particular, each key is only present
//// once in the list.
////
//// Note however that they aren't proper maps or dictionnaries! So, two
//// lists constructed in a different order may not be equal (in the sense
//// of the equality operator `==`) even though they have the exact same
//// elements.

pub opaque type AssocList<key, value> {
  inner: List<#(key, value)>,
}

/// Create a new map
pub fn new() -> AssocList<key, value> {
  AssocList { inner: [] }
}

/// Get the inner list holding the map data
pub fn to_list(m: AssocList<key, value>) -> List<#(key, value)> {
  m.inner
}

// fn fixture_1() {
//   new()
//   |> insert("foo", 42)
//   |> insert("bar", 14)
// }
//
// fn fixture_2() {
//   new()
//   |> insert("foo", 1337)
//   |> insert("baz", 42)
// }

// TODO: acceptance_test 015
//
// test to_list_1() {
//   to_list(new()) == []
// }
//
// test to_list_2() {
//   to_list(fixture_1()) == [("foo", 42), ("bar", 14)]
// }

/// Construct an associative list from a list of key-value pairs. Note that when a key is present
/// multiple times, the first occurence prevails.
pub fn from_list(xs: List<#(key, value)>) -> AssocList<key, value> {
  AssocList { inner: do_from_list(xs) }
}

pub fn do_from_list(xs: List<#(key, value)>) -> List<#(key, value)> {
  when xs is {
    [] -> []
    [#(k, v), ..rest] -> do_insert(do_from_list(rest), k, v)
  }
}

// TODO: acceptance_test 013
//
// test from_list_1() {
//   from_list([]) == new()
// }
//
// test from_list_2() {
//   from_list([#("foo", 42), #("bar", 14)]) == fixture_1()
// }
//
// test from_list_3() {
//   from_list([#("foo", 42), #("bar", 14), #("foo", 1337)]) == fixture_1()
// }

pub fn keys(m: AssocList<key, value>) -> List<key> {
  do_keys(m.inner)
}

fn do_keys(elems: List<#(key, value)>) -> List<key> {
  when elems is {
    [] -> []
    [#(k, _), ..rest] -> [k, ..do_keys(rest)]
  }
}

// TODO: acceptance_test 013
//
// test keys_1() {
//   keys(new()) == []
// }
//
// test keys_2() {
//   keys(
//     new()
//     |> insert(1, 0)
//     |> insert(2, 0),
//   ) == [1, 2]
// }

pub fn values(m: AssocList<key, value>) -> List<value> {
  do_values(m.inner)
}

fn do_values(elems: List<#(key, value)>) -> List<value> {
  when elems is {
    [] -> []
    [#(_, value), ..rest] -> [value, ..do_values(rest)]
  }
}

// TODO: acceptance_test 013
//
// test values_1() {
//   values(new()) == []
// }
//
// test values_2() {
//   values(
//     new()
//     |> insert(1, 3)
//     |> insert(2, 4),
//   ) == [3, 4]
// }

/// Return the number of key-value pairs in the map.
pub fn size(m: AssocList<key, value>) -> Int {
  do_size(m.inner)
}

pub fn do_size(elems: List<#(key, value)>) -> Int {
  when elems is {
    [] -> 0
    [_, ..rest] -> 1 + do_size(rest)
  }
}

// TODO: acceptance_test 013
//
// test size_1() {
//   size(new()) == 0
// }
//
// test size_2() {
//   size(
//     new()
//     |> insert("foo", 14),
//   ) == 1
// }
//
// test size_3() {
//   size(
//     new()
//     |> insert("foo", 14)
//     |> insert("bar", 42),
//   ) == 2
// }

/// Get a value in the map by a key
///
/// ```aiken
/// use aiken/map
///
/// let info = map.new() |> map.insert(key: "name", value: "Aiken")
///
/// assert Some(x) = map.get(in: info, key: "key")
/// ```
pub fn get(in m: AssocList<key, value>, key k: key) -> Option<value> {
  do_get(m.inner, k)
}

fn do_get(elems: List<#(key, value)>, k: key) -> Option<value> {
  when elems is {
    [] -> None
    [#(first, second), ..xs] ->
      if first == k {
        Some(second)
      } else {
        do_get(xs, k)
      }
  }
}

// TODO: acceptance_test 013
//
// test get_insert_1() {
//   get(new(), 14) == None
// }
//
// test get_insert_2() {
//   let m =
//     new()
//     |> insert(key: "name", value: "Aiken")
//     |> insert(key: "trait", value: "awesome")
//   get(m, key: "name") == Some("Aiken")
// }
//
// test get_insert_3() {
//   let m =
//     new()
//     |> insert(key: "name", value: "Aiken")
//     |> insert(key: "trait", value: "awesome")
//   get(m, key: "foo") == None
// }

/// Insert a value in the map by key. If the key already exists, its value is overridden.
///
/// ```aiken
/// use aiken/map
///
/// map.new() |> map.insert(key: "name", value: "Aiken")
/// ```
pub fn insert(
  in m: AssocList<key, value>,
  key k: key,
  value v: value,
) -> AssocList<key, value> {
  AssocList { inner: do_insert(m.inner, k, v) }
}

fn do_insert(
  elems: List<#(key, value)>,
  k: key,
  v: value,
) -> List<#(key, value)> {
  when elems is {
    [] -> [#(k, v)]
    [#(k2, v2), ..rest] ->
      if k == k2 {
        [#(k, v), ..rest]
      } else {
        [#(k2, v2), ..do_insert(rest, k, v)]
      }
  }
}

// TODO: acceptance_test 013
//
// test insert_1() {
//   let m1 =
//     new()
//     |> insert("foo", 42)
//   let m2 =
//     new()
//     |> insert("foo", 14)
//   insert(m1, "foo", 14) == m2
// }
//
// test insert_2() {
//   let m1 =
//     new()
//     |> insert("foo", 42)
//   let m2 =
//     new()
//     |> insert("bar", 14)
//   insert(m1, "bar", 14) == insert(m2, "foo", 42)
// }

/// Check if a key exists in the map
///
/// ```aiken
/// use aiken/map
///
/// let info = map.new() |> map.insert(key: "name", value: "Aiken")
///
/// assert Some(x) = map.contains(in: info, key: "key")
/// ```
pub fn contains(in m: AssocList<key, value>, key k: key) -> Bool {
  do_contains(m.inner, k)
}

fn do_contains(elems: List<#(key, value)>, k: key) -> Bool {
  when elems is {
    [] -> False
    [#(k2, _), ..rest] ->
      if k2 == k {
        True
      } else {
        do_contains(rest, k)
      }
  }
}

// TODO: acceptance_test 013
//
// test contains_1() {
//   !contains(new(), "foo")
// }
//
// test contains_2() {
//   contains(
//     new()
//     |> insert("foo", 14),
//     "foo",
//   )
// }
//
// test contains_3() {
//   !contains(
//     new()
//     |> insert("foo", 14),
//     "bar",
//   )
// }
//
// test contains_4() {
//   contains(
//     new()
//     |> insert("foo", 14)
//     |> insert("bar", 42),
//     "bar",
//   )
// }

/// Remove a key-value pair from a map. If the key is not found, no changes are made.
pub fn delete(in m: AssocList<key, value>, key k: key) -> AssocList<key, value> {
  AssocList { inner: do_delete(m.inner, k) }
}

fn do_delete(elems: List<#(key, value)>, k: key) -> List<#(key, value)> {
  when elems is {
    [] -> []
    [#(k2, v), ..rest] ->
      if k == k2 {
        rest
      } else {
        [#(k2, v), ..do_delete(rest, k)]
      }
  }
}

// TODO: acceptance_test 013
//
// test delete_1() {
//   delete(new(), "foo") == new()
// }
//
// test delete_2() {
//   let m =
//     new()
//     |> insert("foo", 14)
//   delete(m, "foo") == new()
// }
//
// test delete_3() {
//   let m =
//     new()
//     |> insert("foo", 14)
//   delete(m, "bar") == m
// }
//
// test delete_4() {
//   let m =
//     new()
//     |> insert("foo", 14)
//     |> insert("bar", 14)
//   !contains(delete(m, "foo"), "foo")
// }
//
// test delete_5() {
//   let m =
//     new()
//     |> insert("foo", 14)
//     |> insert("bar", 14)
//   contains(delete(m, "bar"), "foo")
// }

/// Apply a function to all key-value pairs in a map.
///
/// ```aiken
/// use aiken/map
///
/// let info = map.new() |> map.insert(key: "age", value: 14)
///
/// pub fn celebrate_birthday(m: AssocList<String, Int>, key: String) {
///   map.map(in: m, with: fn(_key, value) { value + 1 })
/// }
/// ```
pub fn map(
  in m: AssocList<key, value>,
  with with: fn(key, value) -> result,
) -> AssocList<key, result> {
  AssocList { inner: do_map(m.inner, with) }
}

fn do_map(
  elems: List<#(key, value)>,
  with: fn(key, value) -> result,
) -> List<#(key, result)> {
  when elems is {
    [] -> []
    [#(k, v), ..rest] -> [#(k, with(k, v)), ..do_map(rest, with)]
  }
}

// TODO: acceptance_test 013
//
// test map_1() {
//   let result =
//     fixture_1()
//     |> map(with: fn(k, _) { k })
//   get(result, "foo") == Some("foo")
// }
//
// test map_2() {
//   let result =
//     fixture_1()
//     |> map(with: fn(_, v) { v + 1 })
//   get(result, "foo") == Some(43) && size(result) == size(fixture_1())
// }

/// Fold over the key-value pairs in a map.
pub fn fold(
  m: AssocList<key, value>,
  with with: fn(key, value, result) -> result,
  zero zero: result,
) -> result {
  do_fold(m.inner, with, zero)
}

fn do_fold(
  elems: List<#(key, value)>,
  with: fn(key, value, result) -> result,
  zero: result,
) -> result {
  when elems is {
    [] -> zero
    [#(k, v), ..rest] -> with(k, v, do_fold(rest, with, zero))
  }
}

// TODO: acceptance_test 015
//
// test fold_2() {
//   fold(fixture_1(), with: fn(_, v, total) { v + total }, zero: 0) == 56
// }
//
// test fold_1() {
//   fold(new(), fn(_, _, _) { 42 }, 14) == 14
// }

/// Keep only the key-value pairs that pass the given predicate.
pub fn filter(
  m: AssocList<key, value>,
  with with: fn(key, value) -> Bool,
) -> AssocList<key, value> {
  AssocList { inner: do_filter(m.inner, with) }
}

fn do_filter(
  elems: List<#(key, value)>,
  with: fn(key, value) -> Bool,
) -> List<#(key, value)> {
  when elems is {
    [] -> []
    [#(k, v), ..rest] ->
      if with(k, v) {
        [#(k, v), ..do_filter(rest, with)]
      } else {
        do_filter(rest, with)
      }
  }
}

// TODO: acceptance_test 013
//
// test filter_1() {
//   filter(new(), fn(_, _) { True }) == new()
// }
//
// test filter_2() {
//   let expected =
//     new()
//     |> insert("foo", 42)
//   filter(fixture_1(), fn(_, v) { v > 14 }) == expected
// }
//
// test filter_3() {
//   let expected =
//     new()
//     |> insert("bar", 14)
//   filter(fixture_1(), fn(k, _) { k == "bar" }) == expected
// }

/// Combine two maps. If the same key exist in both the left and right maps,
/// values from the left are preferred (i.e. left-biaised).
pub fn union(
  left left: AssocList<key, value>,
  right right: AssocList<key, value>,
) -> AssocList<key, value> {
  AssocList { inner: do_union(left.inner, right.inner) }
}

fn do_union(
  left: List<#(key, value)>,
  right: List<#(key, value)>,
) -> List<#(key, value)> {
  when left is {
    [] -> right
    [#(k, v), ..rest] -> do_union(rest, do_insert(right, k, v))
  }
}

/// Combine two maps using the provided strategy for combining values when the same
/// key is found in both maps.
pub fn union_with(
  left left: AssocList<key, value>,
  right right: AssocList<key, value>,
  with with: fn(key, value, value) -> value,
) -> AssocList<key, value> {
  AssocList { inner: do_union_with(left.inner, right.inner, with) }
}

fn do_union_with(
  left: List<#(key, value)>,
  right: List<#(key, value)>,
  with with: fn(key, value, value) -> value,
) -> List<#(key, value)> {
  when left is {
    [] -> right
    [#(k, v), ..rest] ->
      do_union_with(rest, do_insert_with(right, k, v, with), with)
  }
}

fn do_insert_with(
  elems: List<#(key, value)>,
  k: key,
  v: value,
  with: fn(key, value, value) -> value,
) -> List<#(key, value)> {
  when elems is {
    [] -> [#(k, v)]
    [#(k2, v2), ..rest] ->
      if k == k2 {
        [#(k, with(k, v, v2)), ..rest]
      } else {
        [#(k2, v2), ..do_insert_with(rest, k, v, with)]
      }
  }
}
