import 'dart:typed_data';

import '../errors.dart';
import 'codec.dart';
import 'percent.dart';

/// A parity count 0 to 32, or a throw naming `parity`.
void checkParity(int n) {
  if (n < 0 || n > maxParity) {
    throw schemeFail(
      null,
      'parity',
      'parity: expected 0..$maxParity parity bytes, got $n',
    );
  }
}

/// A parity percentage 0 to 100, or a throw naming `parity`.
void checkPercent(int p) {
  if (p < 0 || p > maxPercent) {
    throw schemeFail(
      null,
      'parity',
      'parity percentage: expected 0..$maxPercent, got $p',
    );
  }
}

/// A correction limit for a scheme of [n] parity bytes or [p] percent,
/// before any byte is read: 0 to `n / 2` for a count, 0 to 16 for a
/// percentage. Throws a [PackbinException] naming `limit`.
void checkLimit(int t, int n, int p) {
  if (p > 0) {
    if (t < 0 || t > maxPercentLimit) {
      throw schemeFail(
        null,
        'limit',
        'correction limit: expected 0..$maxPercentLimit under a parity '
            'percentage, got $t',
      );
    }
  } else if (t < 0 || t > n ~/ 2) {
    throw schemeFail(
      null,
      'limit',
      'correction limit: expected 0..${n ~/ 2} for $n parity bytes, got $t',
    );
  }
}

String _setting(int n, int p) => p > 0 ? '$p percent' : '$n parity bytes';

/// The refusal of one declaration of a count and a percentage together.
PackbinException mixedDeclaration(int n, int p) => schemeFail(
  null,
  'parity',
  'a scheme declares a count or a percentage, got $n parity bytes and '
      '$p percent',
);

/// The refusal of handlers that declare different settings.
PackbinException mixedSettings(int n1, int p1, int n2, int p2) => schemeFail(
  null,
  'parity',
  'schemes declare ${_setting(n1, p1)} and ${_setting(n2, p2)}; '
      'they must declare the same setting',
);

/// The clear message with the parity of a count [n] or, when [p] is above 0,
/// of the percentage [p].
Uint8List protectWith(Uint8List clear, int n, int p) =>
    p > 0 ? protectPercent(clear, p) : protect(clear, n);

/// Repairs [received] under a count [n] or, when [p] is above 0, a
/// percentage [p], with limit [t] (checked by [checkLimit]).
Repair repairWith(Uint8List received, int n, int p, int t) =>
    p > 0 ? repairPercent(received, p, t) : repair(received, n, t);
