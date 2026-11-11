import 'package:packbin/packbin.dart';

typedef Row = Map<String, Object?>;

Scheme<Row> s(List<Field> fields) => scheme(1, fields);

Field n(int id, String name) => u8(id, name);

/// `u8 a; group(1, g, u8 b, flags(2, u8 c))`.
Scheme<Row> anchoredFlags() => s([
  n(0, 'a'),
  groupOf(1, 'g', [
    n(1, 'b'),
    flags(2, [n(2, 'c')]),
  ]),
]);

/// `u8 a; flags(group(1, g, u8 b, flags(2, u8 c)))`.
Scheme<Row> groupUnderFlags() => s([
  n(0, 'a'),
  flags(1, [
    groupOf(1, 'g', [
      n(1, 'b'),
      flags(2, [n(2, 'c')]),
    ]),
  ]),
]);

Scheme<Row> nestedFlags() => s([
  flags(0, [
    groupOf(0, 'g', [
      flags(0, [n(0, 'n')]),
    ]),
  ]),
]);

Scheme<Row> nestedGroup() => s([
  flags(0, [
    groupOf(0, 'g', [
      groupOf(0, 'h', [n(0, 'n')]),
    ]),
  ]),
]);

Scheme<Row> siblingAndFlags() => s([
  flags(0, [
    groupOf(0, 'g', [
      n(0, 'a'),
      flags(1, [n(1, 'c')]),
    ]),
  ]),
]);

/// `u8 mode; flags(group(1, g, when(1, mode == 1, u8 speed)), u16 heading)`.
Scheme<Row> whenInGroup() => s([
  n(0, 'mode'),
  flags(1, [
    groupOf(1, 'g', [
      when(1, eq(0, 1), [n(1, 'speed')]),
    ]),
    u16(2, 'heading'),
  ]),
]);

Scheme<Row> groupSibling() => s([
  n(0, 'mode'),
  flags(1, [
    groupOf(1, 'g', [
      n(1, 'extra'),
      when(2, eq(0, 1), [n(2, 'speed')]),
    ]),
    u16(3, 'heading'),
  ]),
]);

Scheme<Row> splitInGroup() {
  final m = flagByte('m');
  return s([
    groupOf(0, 'g', [m, m.bit(n(0, 'c')), m.bit(u16(1, 'd'))]),
  ]);
}

Scheme<Row> whenBranchGroup() => s([
  n(0, 'kind'),
  when(1, eq(0, 0), [
    groupOf(1, 'g', [n(1, 'shape')]),
  ]),
  when(2, eq(0, 1), [u16(2, 'shape')]),
]);

/// The README late `when`: a group in a split bit whose `when`s name a field
/// written after the flag byte.
Scheme<Row> lateWhen() {
  final fb = flagByte('fb');
  return s([
    fb,
    n(0, 'mode'),
    fb.bit(
      groupOf(1, 'g', [
        n(1, 'd'),
        when(2, eq(0, 1), [n(2, 'a')]),
        when(3, eq(0, 2), [n(3, 'b')]),
      ]),
    ),
  ]);
}

Scheme<Row> nestedBit() {
  final m = flagByte('m');
  return s([
    m,
    m.bit(groupOf(0, 'g', [n(0, 'y'), m.bit(n(1, 'x'))])),
  ]);
}

Scheme<Row> flagByteInGroup() {
  final fb = flagByte('fb');
  return s([
    groupOf(0, 'g', [fb]),
    fb.bit(n(0, 'a')),
  ]);
}

Scheme<Row> markAndN() => s([
  flags(0, [groupOf(0, 'mark', [])]),
  n(0, 'n'),
]);
