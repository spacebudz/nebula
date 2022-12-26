//// A module for working with associative lists.
////
//// Associative lists are fundamentally ordered lists of key-value pairs,
//// which preserve some invariants. In particular, each key is only present
//// once in the list.
////
//// Note however that they aren't proper maps or dictionnaries! So, **two
//// lists constructed in a different order may not be equal** (in the sense
//// of the equality operator `==`) even though they have the exact same
//// elements.

/// An opaque `AssocList`. The type is opaque because the module maintains some
/// invariant, namely: there's only one occurence of a given key in the list.
pub opaque type AssocList<key, value> {
  inner: List<#(key, value)>,
}

/// Create a new map
pub fn new() -> AssocList<key, value> {
  AssocList { inner: [] }
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

/// Remove a key-value pair from the list. If the key is not found, no changes are made.
///
/// ```aiken
/// use aiken/assoc_list
///
/// assoc_list.new()
/// |> assoc_list.insert(key: "foo", value: 42)
/// |> assoc_list.delete(key: "foo")
/// |> assoc_list.get("foo")
/// // None
/// ```
pub fn delete(self: AssocList<key, value>, key k: key) -> AssocList<key, value> {
  AssocList { inner: do_delete(self.inner, k) }
}

fn do_delete(self: List<#(key, value)>, key k: key) -> List<#(key, value)> {
  when self is {
    [] -> []
    [#(k2, value), ..rest] ->
      if k == k2 {
        rest
      } else {
        [#(k2, value), ..do_delete(rest, k2)]
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
//   !has_key(delete(m, "foo"), "foo")
// }
//
// test delete_5() {
//   let m =
//     new()
//     |> insert("foo", 14)
//     |> insert("bar", 14)
//   has_key(delete(m, "bar"), "foo")
// }

/// Keep only the key-value pairs that pass the given predicate.
pub fn filter(
  self: AssocList<key, value>,
  with: fn(key, value) -> Bool,
) -> AssocList<key, value> {
  AssocList { inner: do_filter(self.inner, with) }
}

fn do_filter(
  self: List<#(key, value)>,
  with: fn(key, value) -> Bool,
) -> List<#(key, value)> {
  when self is {
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

/// Finds a value in the list, and returns the first key found to have that value.
///
/// ```aiken
/// use aiken/assoc_list
///
/// assoc_list.new()
/// |> assoc_list.insert(key: "foo", value: 42)
/// |> assoc_list.insert(key: "bar", value: 14)
/// |> assoc_list.find(42)
/// // Some("foo")
/// ```
pub fn find(self: AssocList<key, value>, value v: value) -> Option<key> {
  do_find(self.inner, v)
}

fn do_find(self: List<#(key, value)>, value v: value) -> Option<key> {
  when self is {
    [] -> None
    [#(k2, v2), ..rest] ->
      if v == v2 {
        Some(k2)
      } else {
        do_find(rest, v)
      }
  }
}

// TODO: acceptance_test 013
//
// test find_1() {
//   find(new(), "foo") == None
// }
//
// test find_2() {
//   find(
//     new()
//     |> insert("foo", 14),
//     14,
//   ) == Some("foo")
// }
//
// test find_3() {
//   find(
//     new()
//     |> insert("foo", 14),
//     42,
//   ) == None
// }
//
// test find_4() {
//   find(
//     new()
//     |> insert("foo", 14)
//     |> insert("bar", 42)
//     |> insert("baz", 14),
//     14,
//   ) == Some("foo")
// }

/// Fold over the key-value pairs in a list.
pub fn fold(
  self: AssocList<key, value>,
  with: fn(key, value, result) -> result,
  zero: result,
) -> result {
  do_fold(self.inner, with, zero)
}

fn do_fold(
  self: List<#(key, value)>,
  with: fn(key, value, result) -> result,
  zero: result,
) -> result {
  when self is {
    [] -> zero
    [#(key, value), ..rest] -> with(key, value, do_fold(rest, with, zero))
  }
}

// TODO: acceptance_test 023
//
// test fold_2() {
//   fold(fixture_1(), with: fn(_, v, total) { v + total }, zero: 0) == 56
// }
//
// test fold_1() {
//   fold(new(), fn(_, _, _) { 42 }, 14) == 14
// }

// TODO: acceptance_test 023
//
// test to_list_2() {
//   to_list(fixture_1()) == [#("foo", 42), #("bar", 14)]
// }

/// Construct an associative list from a list of key-value pairs. Note that when a key is present
/// multiple times, the first occurence prevails.
pub fn from_list(self: List<#(key, value)>) -> AssocList<key, value> {
  AssocList { inner: do_from_list(self) }
}

fn do_from_list(xs: List<#(key, value)>) -> List<#(key, value)> {
  when xs is {
    [] -> []
    [#(key, value), ..rest] -> do_insert(do_from_list(rest), key, value)
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

/// Get a value in the assoc_list by its key.
///
/// ```aiken
/// use aiken/assoc_list
///
/// assoc_list.new()
/// |> assoc_list.insert(key: "name", value: "Aiken")
/// |> assoc_list.get(key: "name")
/// // Some("Aiken")
/// ```
pub fn get(self: AssocList<key, value>, key k: key) -> Option<value> {
  do_get(self.inner, k)
}

fn do_get(self: List<#(key, value)>, key k: key) -> Option<value> {
  when self is {
    [] -> None
    [#(k2, v), ..rest] ->
      if k == k2 {
        Some(v)
      } else {
        do_get(rest, k)
      }
  }
}

// TODO: acceptance_test 013
//
// test get_1() {
//   get(new(), 14) == None
// }
//
// test get_2() {
//   let m =
//     new()
//     |> insert(key: "name", value: "Aiken")
//     |> insert(key: "trait", value: "awesome")
//   get(m, key: "name") == Some("Aiken")
// }
//
// test get_3() {
//   let m =
//     new()
//     |> insert(key: "name", value: "Aiken")
//     |> insert(key: "trait", value: "awesome")
//   get(m, key: "foo") == None
// }

/// Check if a key exists in the list.
///
/// ```aiken
/// use aiken/assoc_list
///
/// assoc_list.new()
/// |> assoc_list.insert(key: "name", value: "Aiken")
/// |> assoc_list.has_key("name")
/// // True
/// ```
pub fn has_key(self: AssocList<key, value>, key k: key) -> Bool {
  do_has_key(self.inner, k)
}

fn do_has_key(self: List<#(key, value)>, key k: key) -> Bool {
  when self is {
    [] -> False
    [#(k2, _), ..rest] ->
      if k == k2 {
        True
      } else {
        do_has_key(rest, k)
      }
  }
}

// TODO: acceptance_test 013
//
// test has_key_1() {
//   !has_key(new(), "foo")
// }
//
// test has_key_2() {
//   has_key(
//     new()
//     |> insert("foo", 14),
//     "foo",
//   )
// }
//
// test has_key_3() {
//   !has_key(
//     new()
//     |> insert("foo", 14),
//     "bar",
//   )
// }
//
// test has_key_4() {
//   has_key(
//     new()
//     |> insert("foo", 14)
//     |> insert("bar", 42),
//     "bar",
//   )
// }

/// Insert a value in the assoc-list at a given key key. If the key already exists, its value is **overridden**.
///
/// ```aiken
/// use aiken/assoc_list
///
/// assoc_list.new()
/// |> assoc_list.insert(key: "name", value: "Foo")
/// |> assoc_list.insert(key: "name", value: "Aiken")
/// |> assoc_list.to_list()
/// // [#("name", "Aiken")]
/// ```
pub fn insert(
  self: AssocList<key, value>,
  key k: key,
  value v: value,
) -> AssocList<key, value> {
  AssocList { inner: do_insert(self.inner, k, v) }
}

fn do_insert(
  self: List<#(key, value)>,
  key k: key,
  value v: value,
) -> List<#(key, value)> {
  when self is {
    [] -> [#(k, v)]
    [#(k2, v), ..rest] ->
      if k == k2 {
        [#(k, v), ..rest]
      } else {
        [#(k2, v), ..do_insert(rest, k, v)]
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

/// Extract all the keys present in a given `AssocList`.
///
/// ```aiken
/// use aiken.assoc_list
///
/// assoc_list.new()
/// |> assoc_list.insert("foo", 14)
/// |> assoc_list.insert("bar", 42)
/// |> assoc_list.insert("foo", 1337)
/// |> assoc_list.keys()
/// // ["foo", "bar"]
/// ```
pub fn keys(self: AssocList<key, value>) -> List<key> {
  do_keys(self.inner)
}

fn do_keys(self: List<#(key, value)>) -> List<key> {
  when self is {
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

/// Apply a function to all key-value pairs in a map.
///
/// ```aiken
/// use aiken/assoc_list
///
/// pub fn celebrate_birthday(xs: AssocList<String, Int>, key: String) {
///   xs.map(in: m, with: fn(_key, value) { value + 1 })
/// }
/// ```
pub fn map(
  self: AssocList<key, value>,
  with: fn(key, value) -> result,
) -> AssocList<key, result> {
  AssocList { inner: do_map(self.inner, with) }
}

fn do_map(
  self: List<#(key, value)>,
  with: fn(key, value) -> result,
) -> List<#(key, result)> {
  when self is {
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

/// Get the inner list holding the map data.
pub fn to_list(self: AssocList<key, value>) -> List<#(key, value)> {
  self.inner
}

test to_list_1() {
  to_list(new()) == []
}

/// Return the number of key-value pairs in the assoc-list.
pub fn size(self: AssocList<key, value>) -> Int {
  do_size(self.inner)
}

fn do_size(self: List<#(key, value)>) -> Int {
  when self is {
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

/// Combine two associate lists. If the same key exist in both the left and
/// right lists, values from the left are preferred (i.e. left-biaised).
pub fn union(
  left: AssocList<key, value>,
  right: AssocList<key, value>,
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

// TODO: acceptance_test 029
//
// test union_1() {
//   union(fixture_1(), new()) == fixture_1()
// }
//
// test union_2() {
//   union(new(), fixture_1()) == fixture_1()
// }
//
// test union_3() {
//   let left =
//     new()
//     |> insert("foo", 14)
//   let right =
//     new()
//     |> insert("bar", 42)
//     |> insert("baz", 1337)
//   union(left, right) == from_list([#("foo", 14), #("bar", 42), #("baz", 1337)])
// }
//
// test union_4() {
//   let left =
//     new()
//     |> insert("foo", 14)
//   let right =
//     new()
//     |> insert("bar", 42)
//     |> insert("foo", 1337)
//   union(left, right) == from_list([#("foo", 14), #("bar", 42)])
// }

/// Combine two lists using the provided strategy for combining values when the same
/// key is found in both lists.
pub fn union_with(
  left: AssocList<key, value>,
  right: AssocList<key, value>,
  with: fn(key, value, value) -> value,
) -> AssocList<key, value> {
  AssocList { inner: do_union_with(left.inner, right.inner, with) }
}

fn do_union_with(
  left: List<#(key, value)>,
  right: List<#(key, value)>,
  with: fn(key, value, value) -> value,
) -> List<#(key, value)> {
  when left is {
    [] -> right
    [#(k, v), ..rest] ->
      do_union_with(rest, do_insert_with(right, k, v, with), with)
  }
}

fn do_insert_with(
  self: List<#(key, value)>,
  key k: key,
  value v: value,
  with: fn(key, value, value) -> value,
) -> List<#(key, value)> {
  when self is {
    [] -> [#(k, v)]
    [#(k2, v2), ..rest] ->
      if k == k2 {
        [#(k, with(k, v, v2)), ..rest]
      } else {
        [#(k2, v2), ..do_insert_with(rest, k, v, with)]
      }
  }
}

/// Extract all the values present in a given `AssocList`.
///
/// ```aiken
/// use aiken.assoc_list
///
/// assoc_list.new()
/// |> assoc_list.insert("foo", 14)
/// |> assoc_list.insert("bar", 42)
/// |> assoc_list.insert("foo", 1337)
/// |> assoc_list.values()
/// // [42, 1337]
/// ```
pub fn values(self: AssocList<key, value>) -> List<value> {
  do_values(self.inner)
}

fn do_values(self: List<#(key, value)>) -> List<value> {
  when self is {
    [] -> []
    [#(_, v), ..rest] -> [v, ..do_values(rest)]
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
