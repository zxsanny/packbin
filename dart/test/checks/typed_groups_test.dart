import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

/// One typed row for every scheme here: a group of a typed scheme has no
/// row of its own, so its members are members of the row around it.
class Cell {
  int? a;
  int? b;
  int? c;
  int? d;
  int? mode;
  int? extra;
  int? speed;
  int? heading;
  bool? mark;
  int? n;
}

Field f(
  ValueField<int> field,
  int? Function(Cell) get,
  void Function(Cell, int) set,
) => field.bind<Cell>(get: get, set: set);

Field a(int id) => f(u8(id, 'a'), (r) => r.a, (r, v) => r.a = v);
Field b(int id) => f(u8(id, 'b'), (r) => r.b, (r, v) => r.b = v);
Field c(int id) => f(u8(id, 'c'), (r) => r.c, (r, v) => r.c = v);
Field d(int id) => f(u8(id, 'd'), (r) => r.d, (r, v) => r.d = v);
Field mode(int id) => f(u8(id, 'mode'), (r) => r.mode, (r, v) => r.mode = v);
Field d16(int id) => f(u16(id, 'd'), (r) => r.d, (r, v) => r.d = v);
Field extra(int id) =>
    f(u8(id, 'extra'), (r) => r.extra, (r, v) => r.extra = v);
Field speed(int id) =>
    f(u8(id, 'speed'), (r) => r.speed, (r, v) => r.speed = v);
Field heading(int id) =>
    f(u16(id, 'heading'), (r) => r.heading, (r, v) => r.heading = v);
Field num(int id) => f(u8(id, 'n'), (r) => r.n, (r, v) => r.n = v);
Field mark() => groupOf(
  0,
  'mark',
  [],
).bind<Cell>(get: (r) => r.mark, set: (r, v) => r.mark = v);

Scheme<Cell> t(List<Field> fields) => rowScheme(1, Cell.new, fields);

Scheme<Cell> anchoredFlags() => t([
  a(0),
  groupOf(1, 'g', [
    b(1),
    flags(2, [c(2)]),
  ]),
]);

Scheme<Cell> groupUnderFlags() => t([
  a(0),
  flags(1, [
    groupOf(1, 'g', [
      b(1),
      flags(2, [c(2)]),
    ]),
  ]),
]);

Scheme<Cell> splitInGroup() {
  final m = flagByte('m');
  return t([
    groupOf(0, 'g', [m, m.bit(c(0)), m.bit(d16(1))]),
  ]);
}

Scheme<Cell> lateWhen() {
  final fb = flagByte('fb');
  return t([
    fb,
    mode(0),
    fb.bit(
      groupOf(1, 'g', [
        d(1),
        when(2, eq(0, 1), [a(2)]),
        when(3, eq(0, 2), [b(3)]),
      ]),
    ),
  ]);
}

Scheme<Cell> whenInGroup() => t([
  mode(0),
  flags(1, [
    groupOf(1, 'g', [
      when(1, eq(0, 1), [speed(1)]),
    ]),
    heading(2),
  ]),
]);

Scheme<Cell> groupSibling() => t([
  mode(0),
  flags(1, [
    groupOf(1, 'g', [
      extra(1),
      when(2, eq(0, 1), [speed(2)]),
    ]),
    heading(3),
  ]),
]);

Cell cell({
  int? a,
  int? b,
  int? c,
  int? d,
  int? mode,
  int? extra,
  int? speed,
  int? heading,
  bool? mark,
  int? n,
}) => Cell()
  ..a = a
  ..b = b
  ..c = c
  ..d = d
  ..mode = mode
  ..extra = extra
  ..speed = speed
  ..heading = heading
  ..mark = mark
  ..n = n;

List<int?> fieldsOf(Cell r) => [
  r.a,
  r.b,
  r.c,
  r.d,
  r.mode,
  r.extra,
  r.speed,
  r.heading,
  r.n,
];

void main() {
  group('an anchored group of a typed row binds its members to the row', () {
    test('an anchored group packs and unpacks the README hex', () {
      // Arrange
      final layout = anchoredFlags();

      // Act
      final both = pack(layout, cell(a: 1, b: 2, c: 3));
      final one = pack(layout, cell(a: 1, b: 2));
      final back = unpackRow(both, layout).row!;

      // Assert
      expect([hex(both), hex(one)], ['0101020103', '01010200']);
      expect([back.a, back.b, back.c], [1, 2, 3]);
    });

    test('a group under flags is on when a member holds a value', () {
      // Arrange
      final layout = groupUnderFlags();

      // Act
      final given = pack(layout, cell(a: 1, b: 2, c: 3));
      final absent = pack(layout, cell(a: 1));
      final back = unpackRow(unhex('010101020103'), layout).row!;
      final none = unpackRow(unhex('010100'), layout).row!;

      // Assert
      expect([hex(given), hex(absent)], ['010101020103', '010100']);
      expect([back.a, back.b, back.c], [1, 2, 3]);
      expect([none.a, none.b, none.c], [1, null, null]);
    });

    test('a group under flags with only a nested member set is on', () {
      // Arrange
      final layout = t([
        flags(0, [
          groupOf(0, 'g', [
            flags(0, [c(0)]),
          ]),
        ]),
      ]);

      // Act
      final raw = pack(layout, cell(c: 5));
      final off = pack(layout, cell());

      // Assert
      expect([hex(raw), hex(off)], ['01010105', '0100']);
    });

    test('a split byte inside a group finds its bits in the group', () {
      // Arrange
      final layout = splitInGroup();

      // Act
      final both = pack(layout, cell(c: 3, d: 4));
      final one = pack(layout, cell(d: 4));
      final back = unpackRow(both, layout).row!;

      // Assert
      expect([hex(both), hex(one)], ['0103030400', '01020400']);
      expect([back.c, back.d], [3, 4]);
    });

    test('the README late when in a group under a split bit', () {
      // Arrange
      final layout = lateWhen();

      // Act
      final raw = pack(layout, cell(mode: 1, d: 5, a: 9));
      final back = unpackRow(raw, layout).row!;

      // Assert
      expect(hex(raw), '0101010509');
      expect(fieldsOf(back), [9, null, null, 5, 1, null, null, null, null]);
    });

    test('a when inside a group names a member outside it', () {
      // Arrange
      final layout = whenInGroup();

      // Act
      final taken = pack(layout, cell(mode: 1, speed: 7, heading: 90));
      final skipped = pack(layout, cell(mode: 0, heading: 90));
      final only = pack(layout, cell(mode: 1, speed: 7));

      // Assert
      expect(
        [hex(taken), hex(skipped), hex(only)],
        ['010103075a00', '0100025a00', '01010107'],
      );
    });

    test('a sibling missing from a group that is on is named', () {
      // Arrange
      final layout = groupSibling();

      // Act
      final error = packRefusal(
        () => pack(layout, cell(mode: 1, speed: 7, heading: 90)),
      );

      // Assert
      expect([error.field, error.name], [1, 'extra']);
    });
  });

  group('an empty group of a typed row is a bool mark', () {
    test('the mark sets its bit for true only', () {
      // Arrange
      final layout = t([
        flags(0, [mark()]),
        num(0),
      ]);

      // Act
      final set = pack(layout, cell(mark: true, n: 3));
      final clear = pack(layout, cell(mark: false, n: 3));
      final none = pack(layout, cell(n: 3));
      final back = unpackRow(set, layout).row!;
      final gone = unpackRow(clear, layout).row!;

      // Assert
      expect([hex(set), hex(clear), hex(none)], ['010103', '010003', '010003']);
      expect([back.mark, back.n], [true, 3]);
      expect([gone.mark, gone.n], [null, 3]);
    });

    test('the mark on a split bit', () {
      // Arrange
      final m = flagByte('m');
      final layout = t([m, m.bit(mark()), m.bit(num(0))]);

      // Act
      final raw = pack(layout, cell(mark: true, n: 3));

      // Assert
      expect(hex(raw), '010303');
    });
  });
}
