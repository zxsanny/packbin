/// The most rounds one `repeat` or `times` reads or writes (TypeScript's
/// `maxRounds`).
const int defaultMaxRounds = 65535;

/// The most entries all the rounds of one pack or unpack call may hold.
const int defaultMaxSlots = 1048576;

/// The most bytes one pack call may write, type byte included.
const int defaultMaxBytes = 16777216;
