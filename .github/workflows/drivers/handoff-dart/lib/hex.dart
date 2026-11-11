import 'dart:typed_data';

const _digits = '0123456789abcdef';

/// The lowercase hex of [bytes].
String hexString(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out
      ..write(_digits[b >> 4])
      ..write(_digits[b & 0x0f]);
  }
  return out.toString();
}

int _nibble(int c) {
  if (c >= 0x30 && c <= 0x39) return c - 0x30;
  if (c >= 0x61 && c <= 0x66) return c - 0x61 + 10;
  if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
  return -1;
}

/// The bytes of [text], or null when it is not an even run of hex digits.
Uint8List? hexBytes(String text) {
  if (text.length.isOdd) return null;
  final out = Uint8List(text.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final hi = _nibble(text.codeUnitAt(i * 2));
    final lo = _nibble(text.codeUnitAt(i * 2 + 1));
    if (hi < 0 || lo < 0) return null;
    out[i] = hi << 4 | lo;
  }
  return out;
}

/// The words of every non-blank line of [text], split on white space.
List<List<String>> wordLines(String text) => [
  for (final line in text.split('\n')) _words(line),
];

List<String> _words(String line) {
  final trimmed = line.trim();
  return trimmed.isEmpty ? const [] : trimmed.split(RegExp(r'\s+'));
}
