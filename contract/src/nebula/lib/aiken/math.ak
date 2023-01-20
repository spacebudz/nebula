//// This module contains some basic Math utilities. Standard arithmetic
//// operations on integers are available through native operators:
////
//// operator | Description
//// ---      | ---
//// +        | Arithmetic sum
//// -        | Arithmetic difference
//// /        | Whole division
//// *        | Arithmetic multiplication
//// %        | Remainder by whole division
////
//// Here are a few examples:
////
//// ```aiken
//// 1 + 1   // 2
//// 10 - 2  // 8
//// 40 / 14 // 2
//// 3 * 4   // 12
//// 10 % 3  // 1

/// Calculate the absolute value of an integer.
///
/// ```aiken
/// use aiken/math
///
/// math.abs(-42)
/// // 42
///
/// math.abs(14)
/// // 14
/// ```
pub fn abs(self: Int) -> Int {
  if self < 0 {
    0 - self
  } else {
    self
  }
}

test abs_1() {
  abs(14) == 14
}

test abs_2() {
  abs(-42) == 42
}

/// Restrict the value of an integer between two min and max bounds
///
/// ```aiken
/// use aiken/math
///
/// math.clamp(14, min: 0, max: 10)
/// // 10
/// ```
pub fn clamp(self: Int, min: Int, max: Int) -> Int {
  if self < min {
    min
  } else {
    if self > max {
      max
    } else {
      self
    }
  }
}

test clamp_1() {
  clamp(14, min: 0, max: 10) == 10
}

test clamp_2() {
  clamp(7, min: 0, max: 10) == 7
}

test clamp_3() {
  clamp(7, min: 10, max: 100) == 10
}

/// Return the maximum of two integers.
pub fn max(a: Int, b: Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

test max_1() {
  max(0, 0) == 0
}

test max_2() {
  max(14, 42) == 42
}

test max_3() {
  max(42, 14) == 42
}

/// Return the minimum of two integers.
pub fn min(a: Int, b: Int) -> Int {
  if a > b {
    b
  } else {
    a
  }
}

test min_1() {
  min(0, 0) == 0
}

test min_2() {
  min(14, 42) == 14
}

test min_3() {
  min(42, 14) == 14
}
