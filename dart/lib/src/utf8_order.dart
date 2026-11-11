/// The order of two well-formed strings by their UTF-8 bytes, without
/// encoding them: the order of their code points. The first differing UTF-16
/// unit decides, except that a surrogate (a code point above U+FFFF) sorts
/// after U+E000..U+FFFF, so surrogates are ranked above that range first.
/// `String.compareTo` compares the UTF-16 units as they are and so orders such
/// keys differently.
int compareUtf8(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final x = a.codeUnitAt(i);
    final y = b.codeUnitAt(i);
    if (x != y) return _rank(x) - _rank(y);
  }
  return a.length - b.length;
}

int _rank(int unit) {
  if (unit < 0xd800) return unit;
  return unit >= 0xe000 ? unit - 0x800 : unit + 0x2000;
}
