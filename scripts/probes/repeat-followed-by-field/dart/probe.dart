// Probe of AZ-4206: a repeat that is not the last thing a packet reads. It builds each shape of
// ../README.md, packs the values given there and unpacks its own bytes. One line per shape:
// package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//
// Rows are maps (`scheme(type, fields)`): this form writes every shape with no row class, and the
// rounds of a repeat are one list per name (`v = [5, 6]`). A typed scheme (`rowScheme`) takes the
// rounds as a list of rows. ./run.sh gives the package to this file through a pubspec it writes.
import 'dart:convert';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';

typedef Row = Map<String, Object?>;

String oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

String raised(Object e) => oneLine('${e.runtimeType}: $e');

String hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

// Keys in sorted order, so two rows that hold the same values print the same text.
Object? sorted(Object? value) {
  if (value is Uint8List) return value.toList();
  if (value is Map) {
    final keys = [for (final k in value.keys) '$k']..sort();
    return {for (final k in keys) k: sorted(value[k])};
  }
  if (value is List) return [for (final v in value) sorted(v)];
  return value;
}

String shown(Object? value) => jsonEncode(sorted(value));

// The names a repeat holds in the shapes.
const roundNames = {'v', 'w'};

// A repeat that reads no round leaves its names out of the row unpack returns, so an empty list of
// rounds and an absent name are the same values: both are dropped before two rows are compared.
Object? withoutEmptyRounds(Object? value) {
  if (value is Map) {
    final kept = <Object?, Object?>{};
    for (final MapEntry(:key, value: item) in value.entries) {
      if (roundNames.contains(key) && item is List && item.isEmpty) continue;
      kept[key] = withoutEmptyRounds(item);
    }
    return kept;
  }
  if (value is List) return [for (final v in value) withoutEmptyRounds(v)];
  return value;
}

// The unpack column of an unpack that returned.
String readBack(Unpacked<Row> result, Row values) {
  final got = result.row;
  if (got == null) return 'refused: ${oneLine('${result.error}')}';
  return shown(withoutEmptyRounds(got)) == shown(withoutEmptyRounds(values))
      ? 'same'
      : 'differs: ${shown(got)}';
}

void probe(String shape, Scheme<Row> Function() build, Row values) {
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
  // control: the repeat is the last thing read.
  probe(
    'control',
    () => scheme(1, [
      u8(0, 'x'),
      repeat(1, [u8(1, 'v')]),
    ]),
    {
      'x': 9,
      'v': [5, 6],
    },
  );

  // a: a field after a repeat, top level.
  probe(
    'a',
    () => scheme(1, [
      repeat(0, [u8(0, 'v')]),
      u8(1, 'x'),
    ]),
    {
      'v': [5, 6],
      'x': 9,
    },
  );

  // b: a repeat inside a list element row, two items. The element row is a nested row (the only
  // row a list or dict element can be); its ids start at 0.
  probe(
    'b',
    () => scheme(1, [
      list(
        'items',
        nested('item', [
          u8(0, 'mode'),
          repeat(1, [u8(1, 'v')]),
        ]),
      ),
    ]),
    {
      'items': [
        {
          'mode': 1,
          'v': [5],
        },
        {'mode': 2, 'v': <int>[]},
      ],
    },
  );

  // c: a repeat inside a dict element row, two entries.
  probe(
    'c',
    () => scheme(1, [
      dict(
        'd',
        nested('item', [
          u8(0, 'mode'),
          repeat(1, [u8(1, 'v')]),
        ]),
      ),
    ]),
    {
      'd': {
        'a': {
          'mode': 1,
          'v': [5],
        },
        'b': {'mode': 2, 'v': <int>[]},
      },
    },
  );

  // d: a repeat inside a nested row (the group without an anchor), then a field. The nested row is
  // a map under its name and takes no id of the row around it, so `x` is id 0.
  probe(
    'd',
    () => scheme(1, [
      nested('m', [
        repeat(0, [u8(0, 'v')]),
      ]),
      u8(0, 'x'),
    ]),
    {
      'm': {
        'v': [5, 6],
      },
      'x': 9,
    },
  );

  // e-when: a repeat under a when that is taken, then a field.
  probe(
    'e-when',
    () => scheme(1, [
      u8(0, 'k'),
      when(1, eq(0, 1), [
        repeat(1, [u8(1, 'v')]),
      ]),
      u8(2, 'x'),
    ]),
    {
      'k': 1,
      'v': [5, 6],
      'x': 9,
    },
  );

  // e-flags: a repeat under flags, then a field.
  probe(
    'e-flags',
    () => scheme(1, [
      flags(0, [
        repeat(0, [u8(0, 'v')]),
      ]),
      u8(1, 'x'),
    ]),
    {
      'v': [5, 6],
      'x': 9,
    },
  );

  // f: a repeat after a repeat. A name whose repeat read no round has no key in the map row that
  // comes back (a typed row holds an empty list of rounds there).
  probe(
    'f',
    () => scheme(1, [
      repeat(0, [u8(0, 'v')]),
      repeat(1, [u8(1, 'w')]),
    ]),
    {
      'v': [5],
      'w': [6],
    },
  );
}
