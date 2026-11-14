// Probe of AZ-4291: what happens when a scheme is nested very deep. Usage: dart run probe.dart <shape> <depth>
// with shape `when` or `group`. It prints one tab-separated line: package, shape-depth, build, pack, unpack.
// It asserts nothing: it prints what happens. The scheme and the values are built in a loop, innermost first,
// and compared in a loop, so the probe itself never recurses.
//
// group form: `nested(name, members)`, the group without an anchor, D deep, each under the name `g` (a nested
// row's names are its own, so the same name at every level is allowed), the innermost holding `u8 b`. Rows are
// maps, so the value is `{g: {g: ... {b: 7}}}` D deep and it packs `01 07` (a nested row writes no byte of its
// own). The anchored `groupOf` was not used: it shares the row around it, so a chain of them is not a deep row.
import 'dart:typed_data';

import 'package:packbin/packbin.dart';

typedef Row = Map<String, Object?>;

const maxHex = 80;

String oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

String clip(String text) => text.length > 120 ? text.substring(0, 120) : text;

// The package's own refusal is a PackbinException; any other error or exception (a raw StackOverflowError
// included) is the language failing, not the package refusing.
String failure(Object e) => e is PackbinException
    ? 'refused: ${clip(oneLine(e.toString()))}'
    : 'threw: ${e.runtimeType}';

String hex(Uint8List bytes) {
  final text = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return text.length > maxHex
      ? '${text.substring(0, 40)}...(${bytes.length} bytes)'
      : text;
}

Scheme<Row> buildWhen(int depth) {
  var inner = <Field>[u8(1, 'b')];
  for (var i = 0; i < depth; i++) {
    inner = [when(1, eq(0, 1), inner)];
  }
  return scheme(1, [u8(0, 'a'), ...inner]);
}

Scheme<Row> buildGroup(int depth) {
  var inner = <Field>[u8(0, 'b')];
  for (var i = 0; i < depth; i++) {
    inner = [nested('g', inner)];
  }
  return scheme(1, inner);
}

Row groupValues(int depth) {
  Row row = {'b': 7};
  for (var i = 0; i < depth; i++) {
    row = {'g': row};
  }
  return row;
}

// Walks both rows down the `g` chain. Null when they hold the same values, else what differs.
String? firstDifference(Row got, Row want, int depth) {
  Object? a = got;
  Object? b = want;
  for (var i = 0; i <= depth; i++) {
    final ma = a;
    final mb = b;
    if (ma is! Map || mb is! Map) return 'level $i: $ma vs $mb';
    if (ma.length != mb.length || !ma.keys.every(mb.containsKey)) {
      return 'level $i keys: ${ma.keys.toList()} vs ${mb.keys.toList()}';
    }
    if (!mb.containsKey('g')) {
      return ma['b'] == mb['b'] ? null : 'leaf b: ${ma['b']} vs ${mb['b']}';
    }
    a = ma['g'];
    b = mb['g'];
  }
  return 'deeper than $depth';
}

void main(List<String> args) {
  final depth = args.length == 2 ? int.tryParse(args[1]) : null;
  if (depth == null || depth < 1 || (args[0] != 'when' && args[0] != 'group')) {
    throw ArgumentError('usage: dart run probe.dart <when|group> <depth>');
  }
  final shape = args[0];
  void line(String b, String p, String u) =>
      print(['dart', '$shape-$depth', b, p, u].join('\t'));

  final Row values = shape == 'when' ? {'a': 1, 'b': 7} : groupValues(depth);

  final Scheme<Row> s;
  try {
    s = shape == 'when' ? buildWhen(depth) : buildGroup(depth);
  } catch (e) {
    line(failure(e), '-', '-');
    return;
  }
  final Uint8List packed;
  try {
    packed = pack(s, values);
  } catch (e) {
    line('built', failure(e), '-');
    return;
  }
  final Unpacked<Row> result;
  try {
    result = unpackRow(packed, s);
  } catch (e) {
    line('built', hex(packed), failure(e));
    return;
  }
  final got = result.row;
  if (got == null) {
    line('built', hex(packed), 'refused: ${clip(oneLine('${result.error}'))}');
    return;
  }
  String unpacked;
  try {
    final difference = shape == 'when'
        ? (got['a'] == 1 && got['b'] == 7 && got.length == 2 ? null : '$got')
        : firstDifference(got, values, depth);
    unpacked = difference == null ? 'same' : 'differs: ${clip(oneLine(difference))}';
  } catch (e) {
    unpacked = 'threw: probe: ${e.runtimeType}';
  }
  line('built', hex(packed), unpacked);
}
