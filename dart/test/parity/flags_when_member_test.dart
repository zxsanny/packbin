import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript table `flags-when-member.test.ts` (the AC-3 hex tables, shapes
// WA, WS, WG, W2, GS, WE). A group's values are a nested map in Dart (owner
// decision Go-4): the bytes are TypeScript's, the row shape is not.

Field speed() => when(1, eq(0, 1), [u8(1, 'speed')]);
Field mode() => u8(0, 'mode');
Field heading() => u16(2, 'heading');

Scheme<Row> wa() => scheme(1, [
  mode(),
  flags(1, [speed(), heading()]),
]);

Scheme<Row> ws() {
  final fb = flagByte('m');
  return scheme(1, [mode(), fb, fb.bit(speed()), fb.bit(heading())]);
}

Scheme<Row> wg() => scheme(1, [
  mode(),
  flags(1, [
    groupOf(1, 'g', [speed()]),
    heading(),
  ]),
]);

Scheme<Row> w2() => scheme(1, [
  mode(),
  flags(1, [
    when(1, eq(0, 1), [u8(1, 'speed'), u8(2, 'extra')]),
    u16(3, 'heading'),
  ]),
]);

Scheme<Row> gs() => scheme(1, [
  mode(),
  flags(1, [
    groupOf(1, 'g', [
      u8(1, 'extra'),
      when(2, eq(0, 1), [u8(2, 'speed')]),
    ]),
    u16(3, 'heading'),
  ]),
]);

Scheme<Row> we() => scheme(1, [
  flags(0, [
    u8(0, 'mode'),
    when(1, eq(0, 1), [u8(1, 'speed')]),
  ]),
]);

final shapes = <(String, Scheme<Row> Function())>[
  ('flags', wa),
  ('split', ws),
  ('group', wg),
];

/// The row of a shape: for the group shape, `speed` goes into the map `g`.
Row shaped(String kind, Row row) {
  if (kind != 'group' || !row.containsKey('speed')) return row;
  final out = {...row}..remove('speed');
  out['g'] = {'speed': row['speed']};
  return out;
}

/// What unpack gives for [row]: the group's value in its map; a clear bit
/// gives no key.
Row backOf(String kind, Row row) => shaped(kind, row);

final rows = <ParityRow>[
  for (final (kind, build) in shapes) ...[
    ParityRow(
      'AC-3 $kind when true',
      build,
      shaped(kind, {'mode': 1, 'speed': 7, 'heading': 90}),
      const Pin.wire('010103075a00'),
      back: backOf(kind, {'mode': 1, 'speed': 7, 'heading': 90}),
    ),
    ParityRow(
      'AC-3 $kind when false',
      build,
      {'mode': 0, 'heading': 90},
      const Pin.wire('0100025a00'),
      back: backOf(kind, {'mode': 0, 'heading': 90}),
    ),
    ParityRow(
      'AC-3 $kind when true without body',
      build,
      {'mode': 1, 'heading': 90},
      const Pin.wire('0101025a00'),
      back: backOf(kind, {'mode': 1, 'heading': 90}),
    ),
    if (kind != 'group')
      ParityRow(
        'AC-3 $kind when false with a body given',
        build,
        {'mode': 0, 'speed': 7, 'heading': 90},
        const Pin.wire('0100025a00'),
        back: {'mode': 0, 'heading': 90},
      ),
  ],
  // WG when false with a body given (Go-4): TypeScript packs the flat row to
  // 0100025a00, and the same row with the body in the group's object to
  // 0100035a00 (the group is given, so its bit is set). Dart has only the
  // nested form; the flat row is refused naming speed.
  ParityRow(
    'AC-3 group when false with a body given: the nested form',
    wg,
    {
      'mode': 0,
      'g': {'speed': 7},
      'heading': 90,
    },
    const Pin.wire('0100035a00'),
    back: {'mode': 0, 'g': <String, Object?>{}, 'heading': 90},
  ),
  ParityRow(
    'AC-3 group when false with a body given: the flat row is refused',
    wg,
    {'mode': 0, 'speed': 7, 'heading': 90},
    const Pin.names('speed'),
  ),
  for (final (kind, build) in [('flags', wa), ('group', wg)])
    ParityRow(
      'AC-3 $kind only the when',
      build,
      shaped(kind, {'mode': 1, 'speed': 7}),
      const Pin.wire('01010107'),
      back: backOf(kind, {'mode': 1, 'speed': 7}),
    ),
  ParityRow(
    'AC-3 flags only mode',
    wa,
    {'mode': 0},
    const Pin.wire('010000'),
    back: {'mode': 0},
  ),
  ParityRow(
    'AC-3 two body values',
    w2,
    {'mode': 1, 'speed': 7, 'extra': 8, 'heading': 90},
    const Pin.wire('01010307085a00'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-3 group sibling with the when true',
    gs,
    {
      'mode': 1,
      'g': {'extra': 4, 'speed': 7},
      'heading': 90,
    },
    const Pin.wire('01010304075a00'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-3 group sibling with the when false',
    gs,
    {
      'mode': 0,
      'g': {'extra': 4},
      'heading': 90,
    },
    const Pin.wire('010003045a00'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-3 group with nothing in it',
    gs,
    {'mode': 1, 'heading': 90},
    const Pin.wire('0101025a00'),
    back: {'mode': 1, 'heading': 90},
  ),
  ParityRow(
    'AC-3 when names an earlier member of its own flags',
    we,
    {'mode': 1, 'speed': 7},
    const Pin.wire('01030107'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-3 same-flags when false',
    we,
    {'mode': 0, 'speed': 7},
    const Pin.wire('010100'),
    back: {'mode': 0},
  ),
  ParityRow(
    'AC-3 same-flags when without body',
    we,
    {'mode': 1},
    const Pin.wire('010101'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-3 same-flags when without mode',
    we,
    {'speed': 7},
    const Pin.wire('0100'),
    back: <String, Object?>{},
  ),
  ParityRow('AC-3 W2 body value missing', w2, {
    'mode': 1,
    'speed': 7,
    'heading': 90,
  }, const Pin.names('extra')),
  ParityRow('AC-3 GS when body missing', gs, {
    'mode': 1,
    'g': {'extra': 4},
    'heading': 90,
  }, const Pin.names('speed')),
  ParityRow('AC-3 GS sibling missing, group on through the when', gs, {
    'mode': 1,
    'g': {'speed': 7},
    'heading': 90,
  }, const Pin.names('extra')),
  ParityRow(
    'AC-3 a body value outside its field range fails naming the field',
    wa,
    {'mode': 1, 'speed': 300, 'heading': 90},
    const Pin.names('speed'),
  ),
  ParityRow(
    'AC-6 a row that does not use the shape is unchanged',
    () => scheme(1, [
      flags(0, [u8(0, 'a'), u16(1, 'b')]),
    ]),
    {'a': 1, 'b': 2},
    const Pin.wire('0103010200'),
  ),
];

final unpackOnly = <UnpackRow>[
  for (final (kind, build) in shapes)
    UnpackRow(
      'AC-5 $kind old packet',
      build,
      '0101025a00',
      backOf(kind, {'mode': 1, 'heading': 90}),
    ),
  UnpackRow('AC-5 flags new packet', wa, '010103075a00', {
    'mode': 1,
    'speed': 7,
    'heading': 90,
  }),
];

void main() {
  group('flags-when-member', () => runParity(rows, unpackOnly));
}
