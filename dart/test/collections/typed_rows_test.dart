import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

typedef Row = Map<String, Object?>;

final class Point {
  Point([this.x = 0, this.y = 0]);
  int x;
  int y;
}

final class Trip {
  int sid = 0;
  String? note;
  Point? start;
  List<int>? tags;
  int tail = 0;
  Point origin = Point();
  List<Point> stops = [];
  Map<String, Point> byName = {};
}

Field px(int id, String name) => u8(id, name);

/// `u16 sid; flags(utf8 note, nested start {u8 x, u8 y}, list tags of u8);
/// u8 tail; nested origin {x, y}; list stops of {x, y}; dict byName of {x, y}`.
Scheme<Row> tripMap() => scheme(1, [
  u16(0, 'sid'),
  flags(1, [
    utf8Field(1, 'note'),
    nested('start', [px(0, 'x'), px(1, 'y')]),
    list('tags', u8(0, 't')),
  ]),
  u8(2, 'tail'),
  nested('origin', [px(0, 'x'), px(1, 'y')]),
  list('stops', nested('stop', [px(0, 'x'), px(1, 'y')])),
  dict('byName', nested('stop', [px(0, 'x'), px(1, 'y')])),
]);

NestedField<Point> pointRow(String name) => nestedRow<Point>(name, Point.new, [
  u8(0, 'x').bind<Point>(get: (p) => p.x, set: (p, v) => p.x = v),
  u8(1, 'y').bind<Point>(get: (p) => p.y, set: (p, v) => p.y = v),
]);

Scheme<Trip> tripTyped() => rowScheme<Trip>(1, Trip.new, [
  u16(0, 'sid').bind<Trip>(get: (t) => t.sid, set: (t, v) => t.sid = v),
  flags(1, [
    utf8Field(
      1,
      'note',
    ).bind<Trip>(get: (t) => t.note, set: (t, v) => t.note = v),
    pointRow('start')
        .bind<Trip>(get: (t) => t.start, set: (t, v) => t.start = v),
    list(
      'tags',
      u8(0, 't'),
    ).bind<Trip>(get: (t) => t.tags, set: (t, v) => t.tags = v),
  ]),
  u8(2, 'tail').bind<Trip>(get: (t) => t.tail, set: (t, v) => t.tail = v),
  pointRow('origin')
      .bind<Trip>(get: (t) => t.origin, set: (t, v) => t.origin = v),
  list(
    'stops',
    pointRow('stop'),
  ).bind<Trip>(get: (t) => t.stops, set: (t, v) => t.stops = v),
  dict(
    'byName',
    pointRow('stop'),
  ).bind<Trip>(get: (t) => t.byName, set: (t, v) => t.byName = v),
]);

Trip trip() => Trip()
  ..sid = 7
  ..start = Point(1, 2)
  ..tags = <int>[]
  ..tail = 9
  ..origin = Point(3, 4)
  ..stops = [Point(5, 6), Point(7, 8)]
  ..byName = {'b': Point(1, 1), 'a': Point(2, 2)};

Row tripRow() => {
  'sid': 7,
  'note': null,
  'start': {'x': 1, 'y': 2},
  'tags': <int>[],
  'tail': 9,
  'origin': {'x': 3, 'y': 4},
  'stops': [
    {'x': 5, 'y': 6},
    {'x': 7, 'y': 8},
  ],
  'byName': {
    'b': {'x': 1, 'y': 1},
    'a': {'x': 2, 'y': 2},
  },
};

const tripHex =
    '01 0700 06 0102 0000 09 0304 0200 0506 0708 0200 0210 61 0202 0210 62 0101';

void main() {
  group('a typed row and a map row give the same bytes', () {
    test('with nested rows, a null member and an empty list', () {
      // Arrange
      final typed = tripTyped();
      final map = tripMap();

      // Act
      final fromRow = pack(typed, trip());
      final fromMap = pack(map, tripRow());

      // Assert
      expect(hex(fromRow), tripHex.replaceAll(' ', ''));
      expect(hex(fromMap), hex(fromRow));
    });

    test('the null member clears its flags bit and writes nothing', () {
      // Arrange and Act
      final wire = pack(tripMap(), tripRow());

      // Assert
      expect(wire[3], 0x06, reason: 'bit 0 (note) clear; start and tags set');
    });

    test('an empty list is a value: count 0, its bit set', () {
      // Arrange
      final row = tripRow()..['tags'] = <int>[];

      // Act
      final wire = pack(tripMap(), row);

      // Assert
      expect(hex(wire).substring(0, 18), '010700060102000009');
      expect(wire.sublist(6, 8), [0x00, 0x00], reason: 'count 0');
      expect(wire[3], 0x06);
    });

    test(
      'a null list is no value: its bit is clear and no count is written',
      () {
        // Arrange and Act
        final wire = pack(tripMap(), tripRow()..['tags'] = null);

        // Assert
        expect(wire[3], 0x02);
        expect(wire.length, hex(pack(tripMap(), tripRow())).length ~/ 2 - 2);
      },
    );

    test('the typed row unpacks to the same values', () {
      // Arrange
      final typed = tripTyped();

      // Act
      final got = readRow(typed, tripHex);

      // Assert
      expect(got.sid, 7);
      expect(got.note, isNull);
      expect([got.start!.x, got.start!.y], [1, 2]);
      expect(got.tags, <int>[]);
      expect(got.tail, 9);
      expect([got.origin.x, got.origin.y], [3, 4]);
      expect([for (final p in got.stops) p.x * 10 + p.y], [56, 78]);
      expect(got.byName.keys, ['a', 'b']);
      expect(got.byName['a']!.x, 2);
    });

    test('the map row unpacks to the nested maps, and packs again', () {
      // Arrange
      final map = tripMap();

      // Act
      final got = readRow(map, tripHex);
      final again = pack(map, got);

      // Assert
      expect(got['start'], {'x': 1, 'y': 2});
      expect(got['origin'], {'x': 3, 'y': 4});
      expect(got.containsKey('note'), isFalse);
      expect(got['tags'], <int>[]);
      expect(hex(again), tripHex.replaceAll(' ', ''));
    });

    test('a typed list and dict unpack with their element types', () {
      // Arrange and Act
      final got = readRow(tripTyped(), tripHex);

      // Assert
      expect(got.tags, isA<List<int>>());
      expect(got.stops, isA<List<Point>>());
      expect(got.byName, isA<Map<String, Point>>());
    });

    test('the nested group is read from the nested map, not the flat row', () {
      // Arrange: x and y flat in the row, and no map for origin
      final row = tripRow()
        ..remove('origin')
        ..['x'] = 3
        ..['y'] = 4;

      // Act
      final error = packRefusal(() => pack(tripMap(), row));

      // Assert
      expect(error.name, 'origin');
      expect(error.reason, contains('missing origin'));
    });

    test('a nested row that is not a map is refused naming the field', () {
      // Arrange
      final row = tripRow()..['origin'] = [3, 4];

      // Act
      final error = packRefusal(() => pack(tripMap(), row));

      // Assert
      expect(error.name, 'origin');
      expect(error.reason, contains('Map<String, Object?>'));
    });

    test('a typed null nested member, list and dict are no value', () {
      // Arrange
      final layout = tripTyped();
      final bare = trip()
        ..start = null
        ..tags = null;

      // Act
      final wire = pack(layout, bare);

      // Assert
      expect(wire[3], 0x00, reason: 'no bit set');
    });
  });
}
