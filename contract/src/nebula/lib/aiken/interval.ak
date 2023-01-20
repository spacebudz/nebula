//// In a eUTxO-based blockchain like Cardano, the management of time can be
//// finicky.
////
//// Indeed, in order to maintain a complete determinism in the execution of
//// scripts, it is impossible to introduce a notion of _"current time"_ since
//// the execution would then depend on factor that are external to the
//// transaction itself: the ineluctable stream of time flowing in our universe.
////
//// Hence, to work around that, we typically define time intervals, which gives
//// window -- a.k.a intervals -- within which the transaction can be executed.
//// From within a script, it isn't possible to know when exactly the script is
//// executed, but we can reason about the interval bounds to validate pieces of
//// logic.

/// A type to represent intervals of values. Interval are inhabited by a type
/// `a` which is useful for non-infinite intervals that have a finite
/// lower-bound and/or upper-bound.
///
/// This allows to represent all kind of mathematical intervals:
///
/// ```aiken
/// // [1; 10]
/// let i0: Interval<Int> = Interval
///   { lower_bound:
///       IntervalBound { bound_type: Finite(1), is_inclusive: True }
///   , upper_bound:
///       IntervalBound { bound_type: Finite(10), is_inclusive: True }
///   }
/// ```
///
/// ```aiken
/// // (20; infinity)
/// let i1: Interval<Int> = Interval
///   { lower_bound:
///       IntervalBound { bound_type: Finite(20), is_inclusive: False }
///   , upper_bound:
///       IntervalBound { bound_type: PositiveInfinity, is_inclusive: False }
///   }
/// ```
pub type Interval<a> {
  lower_bound: IntervalBound<a>,
  upper_bound: IntervalBound<a>,
}

/// An interval bound, either inclusive or exclusive.
pub type IntervalBound<a> {
  bound_type: IntervalBoundType<a>,
  is_inclusive: Bool,
}

/// A type of interval bound. Where finite, a value of type `a` must be
/// provided. `a` will typically be an `Int`, representing a number of seconds or
/// milliseconds.
pub type IntervalBoundType<a> {
  NegativeInfinity
  Finite(a)
  PositiveInfinity
}

// TODO: Replace 'Int' with a generic 'a' once we have comparable traits.

/// Checks whether an element is contained within the interval.
///
/// ```aiken
/// use aiken/interval.{Interval, IntervalBound, Finite}
///
/// let iv =
///   Interval {
///     lower_bound: IntervalBound(Finite(14), True),
///     upper_bound: IntervalBound(Finite(42), False),
///   }
///
/// contains(iv, 25) // True
/// contains(iv, 0)  // False
/// contains(iv, 14) // True
/// contains(iv, 42) // False
/// ```
pub fn contains(self: Interval<Int>, elem: Int) -> Bool {
  let is_greater_than_lower_bound = when self.lower_bound.bound_type is {
    NegativeInfinity -> True
    Finite(lower_bound) ->
      if self.lower_bound.is_inclusive {
        elem >= lower_bound
      } else {
        elem > lower_bound
      }
    PositiveInfinity -> False
  }

  let is_smaller_than_upper_bound = when self.upper_bound.bound_type is {
    NegativeInfinity -> False
    Finite(upper_bound) ->
      if self.upper_bound.is_inclusive {
        elem <= upper_bound
      } else {
        elem < upper_bound
      }
    PositiveInfinity -> True
  }

  is_greater_than_lower_bound && is_smaller_than_upper_bound
}

test contains_1() {
  let iv =
    Interval {
      lower_bound: IntervalBound(NegativeInfinity, False),
      upper_bound: IntervalBound(PositiveInfinity, False),
    }

  contains(iv, 14)
}

test contains_2() {
  let iv =
    Interval {
      lower_bound: IntervalBound(NegativeInfinity, False),
      upper_bound: IntervalBound(Finite(15), False),
    }

  contains(iv, 14)
}

test contains_3() {
  let iv =
    Interval {
      lower_bound: IntervalBound(NegativeInfinity, False),
      upper_bound: IntervalBound(Finite(14), True),
    }

  contains(iv, 14)
}

test contains_4() {
  let iv =
    Interval {
      lower_bound: IntervalBound(NegativeInfinity, False),
      upper_bound: IntervalBound(Finite(14), False),
    }

  !contains(iv, 14)
}

test contains_5() {
  let iv =
    Interval {
      lower_bound: IntervalBound(Finite(13), False),
      upper_bound: IntervalBound(PositiveInfinity, False),
    }

  contains(iv, 14)
}

test contains_6() {
  let iv =
    Interval {
      lower_bound: IntervalBound(Finite(14), True),
      upper_bound: IntervalBound(PositiveInfinity, False),
    }

  contains(iv, 14)
}

test contains_7() {
  let iv =
    Interval {
      lower_bound: IntervalBound(Finite(14), False),
      upper_bound: IntervalBound(PositiveInfinity, False),
    }

  !contains(iv, 14)
}

test contains_8() {
  let iv =
    Interval {
      lower_bound: IntervalBound(Finite(42), False),
      upper_bound: IntervalBound(Finite(1337), False),
    }

  !contains(iv, 14)
}

test contains_9() {
  let iv =
    Interval {
      lower_bound: IntervalBound(Finite(0), False),
      upper_bound: IntervalBound(Finite(42), False),
    }

  contains(iv, 14)
}
