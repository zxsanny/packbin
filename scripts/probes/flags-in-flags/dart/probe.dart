// Probe of AZ-4251: a `flags` that is a direct member of a `flags`. It builds scheme S of
// ../README.md, packs each shape's values and unpacks its own bytes. One line per shape: package,
// shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//
// Rows are maps (`scheme(type, fields)`); a shape leaves a value out by leaving its key out. The bool
// is `flagBool` (`bool` in the other packages). Ids: both `flags` and `x` are 0, `b` is 1.
// ./run.sh gives the package to this file through a pubspec it writes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';

typedef Row = Map<String, Object?>;

String oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

String raised(Object e) => oneLine('${e.runtimeType}: $e');

String hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

// Keys in sorted order, so two rows that hold the same values print the same text.
String shown(Row row) {
  final keys = [for (final k in row.keys) k]..sort();
  return jsonEncode({for (final k in keys) k: row[k]});
}

// The row two rows are compared by: a member with no value (null) is absent, and so is `b = false`,
// which leaves the bit clear as an absent `b` does (README §Bool).
String present(Row row) => shown({
  for (final MapEntry(:key, :value) in row.entries)
    if (value != null && !(key == 'b' && value == false)) key: value,
});

// The unpack column of an unpack that returned.
String readBack(Unpacked<Row> result, Row values) {
  final got = result.row;
  if (got == null) return 'refused: ${oneLine('${result.error}')}';
  return present(got) == present(values) ? 'same' : 'differs: ${shown(got)}';
}

// S: flags(flags(u8 x), bool b).
Scheme<Row> build() => scheme(1, [
  flags(0, [
    flags(0, [u8(0, 'x')]),
    flagBool(1, 'b'),
  ]),
]);

void probe(String shape, Row values) {
  void line(String b, String p, String u) =>
      print(['dart', shape, b, p, u].join('\t'));
  final Scheme<Row> s;
  try {
    s = build();
  } catch (e) {
    line('refused: ${raised(e)}', '-', '-');
    return;
  }
  final Uint8List packed;
  try {
    packed = pack(s, values);
  } catch (e) {
    line('built', 'refused: ${raised(e)}', '-');
    return;
  }
  final Unpacked<Row> result;
  try {
    result = unpackRow(packed, s);
  } catch (e) {
    line('built', hex(packed), 'threw: ${raised(e)}');
    return;
  }
  String unpacked;
  try {
    unpacked = readBack(result, values);
  } catch (e) {
    // A row the probe cannot compare or print: say so and go on.
    unpacked = 'threw: probe: ${raised(e)}';
  }
  line('built', hex(packed), unpacked);
}

void main() {
  probe('both', {'x': 9, 'b': true});
  probe('x-only', {'x': 9});
  probe('b-only', {'b': true});
  probe('none', {});
}
