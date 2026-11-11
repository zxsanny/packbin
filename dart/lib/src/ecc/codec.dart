import 'dart:typed_data';

import '../errors.dart';
import 'gf256.dart';

/// The most parity bytes a scheme declares.
const int maxParity = 32;

/// The most bytes sent: the code word is 255, one byte of it (the clear
/// length) is not sent.
const int maxBlock = 254;

/// What repair gives: the clear message and the count of bytes repaired, or
/// the [error] that refuses the message.
final class Repair {
  const Repair.ok(Uint8List this.clear, this.count) : error = null;
  const Repair.fail(PackbinError this.error) : clear = null, count = 0;

  /// The clear message (a view of the input when it is intact, a repaired
  /// copy otherwise); null when refused.
  final Uint8List? clear;

  /// The bytes repaired, 0 when intact.
  final int count;

  /// Why the message is refused; null when it is read.
  final PackbinError? error;
}

/// The refusal of a protected buffer above [maxBlock] bytes.
PackbinError tooLongBuffer(int size) => PackbinError(
  ErrorKind.tooLong,
  left: size,
  reason: 'the message is $size bytes, above the limit of $maxBlock bytes',
);

/// The refusal of a repair that cannot be done.
const PackbinError uncorrectableError = PackbinError(ErrorKind.uncorrectable);

final List<Uint8List> _generators = List<Uint8List>.generate(maxParity + 1, (
  n,
) {
  var g = <int>[1];
  for (var i = 0; i < n; i++) {
    final next = List<int>.filled(g.length + 1, 0);
    for (var j = 0; j < g.length; j++) {
      next[j] ^= g[j];
      next[j + 1] ^= mul(g[j], exp[i]);
    }
    g = next;
  }
  return Uint8List.fromList(g);
}, growable: false);

/// The clear message followed by its [n] parity bytes ([n] checked, 0 to 32).
/// A clear message above `254 - n` bytes throws a [PackbinException] of kind
/// [ErrorKind.tooLong].
Uint8List protect(Uint8List clear, int n) {
  if (n == 0) return clear;
  final size = clear.length;
  if (size > maxBlock - n) {
    throw PackbinException(
      PackbinError(
        ErrorKind.tooLong,
        left: size,
        reason:
            'the packet would be $size bytes, above the limit of '
            '${maxBlock - n} bytes for $n parity bytes',
      ),
    );
  }
  final g = _generators[n];
  final rem = Uint8List(size + 1 + n);
  rem[0] = size;
  rem.setRange(1, size + 1, clear);
  for (var i = 0; i <= size; i++) {
    final c = rem[i];
    if (c == 0) continue;
    final lc = log[c];
    for (var j = 1; j <= n; j++) {
      final gj = g[j];
      if (gj != 0) rem[i + j] ^= exp[log[gj] + lc];
    }
  }
  final out = Uint8List(size + n);
  out.setRange(0, size, clear);
  out.setRange(size, size + n, rem, size + 1);
  return out;
}

/// The syndromes of the code word: the clear length (word length minus [n]),
/// then the word.
List<int> _syndromes(Uint8List word, int n) {
  final length = word.length - n;
  final out = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    var s = length;
    for (var k = 0; k < word.length; k++) {
      s = (s == 0 ? 0 : exp[log[s] + i]) ^ word[k];
    }
    out[i] = s;
  }
  return out;
}

bool _allZero(List<int> values) {
  for (final v in values) {
    if (v != 0) return false;
  }
  return true;
}

/// [p] (lowest degree first) at [x].
int _evaluate(List<int> p, int x) {
  var y = 0;
  for (var i = p.length - 1; i >= 0; i--) {
    y = mul(y, x) ^ p[i];
  }
  return y;
}

/// Berlekamp-Massey: the error locator, lowest degree first, trimmed.
List<int> _locator(List<int> synd, int n) {
  var lam = <int>[1];
  var prev = <int>[1];
  var l = 0;
  var m = 1;
  var b = 1;
  for (var r = 0; r < n; r++) {
    var d = synd[r];
    for (var i = 1; i <= l; i++) {
      if (i < lam.length && r - i >= 0) d ^= mul(lam[i], synd[r - i]);
    }
    if (d == 0) {
      m++;
      continue;
    }
    final before = List<int>.of(lam);
    final coef = mul(d, inv(b));
    while (lam.length < prev.length + m) {
      lam.add(0);
    }
    for (var i = 0; i < prev.length; i++) {
      lam[i + m] ^= mul(coef, prev[i]);
    }
    if (2 * l <= r) {
      l = r + 1 - l;
      prev = before;
      b = d;
      m = 1;
    } else {
      m++;
    }
  }
  while (lam.length > 1 && lam.last == 0) {
    lam = lam.sublist(0, lam.length - 1);
  }
  return lam;
}

/// Checks [received] against [n] parity bytes and repairs up to [t] wrong
/// bytes. [n] and [t] are the caller's and are checked first. Never throws on
/// the bytes: a message that cannot be read is a [Repair.fail] (short packet
/// naming `parity`, too long, uncorrectable). The input is never written.
Repair repair(Uint8List received, int n, int t) {
  if (n == 0) return Repair.ok(received, 0);
  final size = received.length;
  if (size > maxBlock) return Repair.fail(tooLongBuffer(size));
  if (size < n) return Repair.fail(shortPacket(null, 'parity', n, size));
  final synd = _syndromes(received, n);
  if (_allZero(synd)) {
    return Repair.ok(Uint8List.sublistView(received, 0, size - n), 0);
  }
  if (t == 0) return Repair.fail(uncorrectableError);
  final lam = _locator(synd, n);
  final degree = lam.length - 1;
  if (degree < 1 || degree > t) return Repair.fail(uncorrectableError);
  // Position p (0 = first byte sent) has locator X = alpha^(size-1-p); the
  // unsent length byte is one place before it, and a root there makes the
  // count differ.
  final roots = <int>[];
  for (var p = 0; p < size; p++) {
    if (_evaluate(lam, exp[(255 - (size - 1 - p)) % 255]) == 0) roots.add(p);
  }
  if (roots.length != degree) return Repair.fail(uncorrectableError);
  // The error evaluator omega = (synd * lam) mod x^n, lowest degree first.
  final omega = List<int>.filled(n, 0);
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < lam.length && i + j < n; j++) {
      omega[i + j] ^= mul(synd[i], lam[j]);
    }
  }
  // The derivative in characteristic 2 keeps the odd-degree terms.
  final dlam = <int>[for (var i = 1; i < lam.length; i++) i.isOdd ? lam[i] : 0];
  final word = Uint8List.fromList(received);
  for (final p in roots) {
    final x = exp[(size - 1 - p) % 255];
    final xi = inv(x);
    final den = _evaluate(dlam, xi);
    if (den == 0) return Repair.fail(uncorrectableError);
    word[p] ^= mul(x, mul(_evaluate(omega, xi), inv(den)));
  }
  if (!_allZero(_syndromes(word, n))) return Repair.fail(uncorrectableError);
  return Repair.ok(Uint8List.sublistView(word, 0, size - n), degree);
}
