/// Load-aware wall-clock bounds, as in the other packages (AZ-2723). A host
/// that other work loads makes a fixed bound fail, so a bound is its nominal
/// time, written for an idle host, times the load factor: how many times
/// slower than an idle host a fixed integer loop runs right now, in this
/// process, never below 1 and never above [maxLoadFactor]. A real slowdown of
/// the timed code still fails, because the reference loop does not change with
/// it.
library;

import 'package:test/test.dart';

/// The smallest of 60 runs of the reference loop after a warm-up on the
/// owner's Mac (Apple M-series, `dart test` VM); other work only adds time, so
/// the smallest run is the idle one.
const double referenceSeconds = 0.020;

/// The largest factor a bound grows by.
const double maxLoadFactor = 8;

const int _iterations = 5000000;

/// What the reference loop computed: kept so the loop is not optimised away.
int referenceSink = 0;

int _referenceLoop() {
  var x = 0x2545F491;
  var sum = 0;
  for (var i = 0; i < _iterations; i++) {
    x ^= (x << 13) & 0xffffffff;
    x ^= x >>> 7;
    x ^= (x << 17) & 0xffffffff;
    sum = (sum + x) & 0xffffffff;
  }
  return sum;
}

double _seconds() {
  final watch = Stopwatch()..start();
  referenceSink ^= _referenceLoop();
  return watch.elapsedMicroseconds / 1e6;
}

bool _warm = false;

/// How much slower than an idle host this process runs now, in
/// [1, [maxLoadFactor]]: the mean of five reference loops over the idle time
/// of one. The mean, not the smallest: on a host loaded many times over its
/// cores the smallest of a few short runs catches a free time slice and reads
/// 1 while a section of a few hundred milliseconds is slowed several times.
/// The first call also warms the loop up before it is timed.
double loadFactor() {
  if (!_warm) {
    referenceSink ^= _referenceLoop();
    _warm = true;
  }
  const runs = 5;
  var total = 0.0;
  for (var i = 0; i < runs; i++) {
    total += _seconds();
  }
  final factor = total / runs / referenceSeconds;
  return factor < 1 ? 1 : (factor > maxLoadFactor ? maxLoadFactor : factor);
}

/// A wall-clock bound: [nominal] times the load factor taken when the bound
/// was made. Make it right before the timed section.
final class LoadBound {
  LoadBound(this.nominal) : factor = loadFactor();

  final Duration nominal;
  final double factor;

  Duration get limit =>
      Duration(microseconds: (nominal.inMicroseconds * factor).round());
}

/// Fails unless [elapsed] is within [bound]. When the first factor does not
/// cover it, the load factor is taken again after the timed section (the load
/// may have risen during it) and the larger factor counts.
void expectWithin(Duration elapsed, LoadBound bound, {String what = ''}) {
  if (elapsed <= bound.limit) return;
  final later = loadFactor();
  final factor = later > bound.factor ? later : bound.factor;
  final limit = Duration(
    microseconds: (bound.nominal.inMicroseconds * factor).round(),
  );
  expect(
    elapsed <= limit,
    isTrue,
    reason:
        '$what: took ${elapsed.inMilliseconds} ms, nominal bound '
        '${bound.nominal.inMilliseconds} ms, load factor '
        '${factor.toStringAsFixed(2)}, scaled bound ${limit.inMilliseconds} ms',
  );
}

/// Whether [elapsed] is over the [nominal] bound scaled by the load factor,
/// for checks that run thousands of times (a fuzz loop, the hostile cases): a
/// call inside the nominal bound, the usual case, never measures the load;
/// only a call over it does, as [expectWithin] does.
bool overLoadBound(Duration elapsed, Duration nominal) {
  if (elapsed <= nominal) return false;
  final limit = Duration(
    microseconds: (nominal.inMicroseconds * loadFactor()).round(),
  );
  return elapsed > limit;
}
