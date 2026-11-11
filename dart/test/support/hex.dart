import 'dart:typed_data';

/// Lowercase hex of [bytes], with no separators.
String hex(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}

/// The bytes of a hex string; spaces and line ends are ignored.
Uint8List unhex(String text) {
  final digits = text.replaceAll(RegExp(r'\s'), '');
  if (digits.length.isOdd) throw FormatException('odd hex length', text);
  final out = Uint8List(digits.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(digits.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
