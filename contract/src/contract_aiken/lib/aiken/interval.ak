/// A type to represent intervals of values. Interval are inhabited by a type /
/// `a` which is useful for non-infinite intervals that have a finite
/// lower-bound and/or upper-bound.
pub type Interval<a> {
  lower_bound: IntervalBound<a>,
  upper_bound: IntervalBound<a>,
}

/// An interval bound, either inclusive or exclusive.
pub type IntervalBound<a> {
  bound_type: IntervalBoundType<a>,
  is_inclusive: Bool,
}

/// A type of interval bound. Where finite, a value of type 'a' must be provided.
pub type IntervalBoundType<a> {
  NegativeInfinity
  Finite(a)
  PositiveInfinity
}
