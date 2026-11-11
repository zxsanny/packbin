import 'dart:typed_data';

/// `exp[i]` is alpha^i (alpha = 2, field polynomial 0x11D), twice around the
/// cycle so a sum of two logs needs no reduction.
final Uint8List exp = _tables.$1;

/// `log[x]` is the power of alpha that gives `x` (`log[0]` is unused).
final Uint8List log = _tables.$2;

final (Uint8List, Uint8List) _tables = () {
  final exp = Uint8List(512);
  final log = Uint8List(256);
  var x = 1;
  for (var i = 0; i < 255; i++) {
    exp[i] = x;
    log[x] = i;
    x <<= 1;
    if (x & 0x100 != 0) x ^= 0x11D;
  }
  for (var i = 255; i < 512; i++) {
    exp[i] = exp[i - 255];
  }
  return (exp, log);
}();

int mul(int a, int b) => a == 0 || b == 0 ? 0 : exp[log[a] + log[b]];

/// The inverse of a non-zero [a].
int inv(int a) => exp[255 - log[a]];
