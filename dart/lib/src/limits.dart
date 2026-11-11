import 'errors.dart';

/// The most rounds one `repeat` or `times` reads or writes by default
/// (TypeScript's `maxRounds`).
const int defaultMaxRounds = 65535;

/// The most entries all the rounds of one pack or unpack call may hold by
/// default.
const int defaultMaxSlots = 1048576;

/// The most bytes one pack call may write by default, type byte included.
const int defaultMaxBytes = 16777216;

/// The three limits of one scheme. A limit is at least 1, so a scheme made
/// by [Scheme.withLimits] always passes the checks the walker makes.
final class Limits {
  /// Holds the limits; the caller has checked them with [checkedLimit].
  const Limits(this.maxRounds, this.maxSlots, this.maxBytes);

  /// The most rounds one `repeat` or `times` may start.
  final int maxRounds;

  /// The most slots all the rounds of one call may create together.
  final int maxSlots;

  /// The most bytes one pack call may write.
  final int maxBytes;
}

/// The limits a scheme has until `withLimits` changes them.
const Limits defaultLimits = Limits(
  defaultMaxRounds,
  defaultMaxSlots,
  defaultMaxBytes,
);

/// [value] when it is at least 1, [fallback] when it is null; a smaller one
/// throws a [PackbinException] of kind [ErrorKind.schemeError] naming [name].
int checkedLimit(String name, int? value, int fallback) {
  if (value == null) return fallback;
  if (value < 1) {
    throw schemeFail(
      null,
      name,
      '$name: expected a positive integer, got $value',
    );
  }
  return value;
}
