import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

class Point {
  int? lat;
  int? lon;
}

class Route {
  int? n;
  List<Point>? points;
  int? tail;
}

class Other {
  int? x;
}

Point point(int lat, int lon) => Point()
  ..lat = lat
  ..lon = lon;

Field latField() =>
    i32(1, 'lat').bind<Point>(get: (r) => r.lat, set: (r, v) => r.lat = v);
Field lonField() =>
    i32(2, 'lon').bind<Point>(get: (r) => r.lon, set: (r, v) => r.lon = v);

Scheme<Route> routeScheme() => rowScheme<Route>(1, Route.new, [
  u8(0, 'n').bind<Route>(get: (r) => r.n, set: (r, v) => r.n = v),
  times(1, 0, [latField(), lonField()]).bind<Route, Point>(
    create: Point.new,
    get: (r) => r.points,
    set: (r, v) => r.points = v,
  ),
  u8(3, 'tail').bind<Route>(get: (r) => r.tail, set: (r, v) => r.tail = v),
]);

class Track {
  List<Point>? points;
}

Scheme<Track> repeatScheme() => rowScheme<Track>(1, Track.new, [
  repeat(0, [
    i32(0, 'lat').bind<Point>(get: (r) => r.lat, set: (r, v) => r.lat = v),
    i32(1, 'lon').bind<Point>(get: (r) => r.lon, set: (r, v) => r.lon = v),
  ]).bind<Track, Point>(
    create: Point.new,
    get: (r) => r.points,
    set: (r, v) => r.points = v,
  ),
]);

class Item {
  int? len;
  Uint8List? payload;
  int? a;
  int? b;
  List<int>? marks;
}

class Batch {
  int? count;
  List<Item>? items;
}

Scheme<Batch> batchScheme() => rowScheme<Batch>(1, Batch.new, [
  u8(0, 'count').bind<Batch>(get: (r) => r.count, set: (r, v) => r.count = v),
  times(1, 0, [
    u8(1, 'len').bind<Item>(get: (r) => r.len, set: (r, v) => r.len = v),
    sized(
      2,
      'payload',
      1,
    ).bind<Item>(get: (r) => r.payload, set: (r, v) => r.payload = v),
    u2([
      slot(3, 'a').bind<Item>(get: (r) => r.a, set: (r, v) => r.a = v),
      slot(4, 'b').bind<Item>(get: (r) => r.b, set: (r, v) => r.b = v),
    ]),
    bits(
      5,
      'marks',
      1,
    ).bind<Item>(get: (r) => r.marks, set: (r, v) => r.marks = v),
  ]).bind<Batch, Item>(
    create: Item.new,
    get: (r) => r.items,
    set: (r, v) => r.items = v,
  ),
]);

void main() {
  group('typed rounds: a list of rows through a factory closure', () {
    test('a times packs and unpacks the README hex', () {
      // Arrange
      final layout = routeScheme();
      final row = Route()
        ..n = 2
        ..points = [point(10, 20), point(30, 40)]
        ..tail = 7;

      // Act
      final raw = pack(layout, row);
      final back = unpackRow(raw, layout).row!;

      // Assert
      expect(hex(raw), '01020a000000140000001e0000002800000007');
      expect(back.points!.map((p) => (p.lat, p.lon)), [(10, 20), (30, 40)]);
      expect([back.n, back.tail], [2, 7]);
    });

    test('zero rounds unpack to an empty list, not null', () {
      // Arrange
      final layout = routeScheme();

      // Act
      final back = unpackRow(unhex('010007'), layout).row!;

      // Assert
      expect(back.points, isEmpty);
      expect(back.points, isNotNull);
    });

    test('a null list packs no round for a count of 0, as an empty one', () {
      // Arrange
      final layout = routeScheme();
      final none = Route()
        ..n = 0
        ..tail = 7;
      final empty = Route()
        ..n = 0
        ..points = []
        ..tail = 7;

      // Act
      final wires = [hex(pack(layout, none)), hex(pack(layout, empty))];

      // Assert
      expect(wires, ['010007', '010007']);
    });

    test('a count that differs from the rows is refused naming the member', () {
      // Arrange
      final layout = routeScheme();
      final row = Route()
        ..n = 3
        ..points = [point(1, 2), point(3, 4)]
        ..tail = 7;

      // Act
      final error = packRefusal(() => pack(layout, row));

      // Assert
      expect(
        [error.name, error.reason],
        ['lat', contains('the times count is 3, but the row holds 2 rounds')],
      );
    });

    test('a count of 0 with rows is refused', () {
      // Arrange
      final layout = routeScheme();
      final row = Route()
        ..n = 0
        ..points = [point(1, 2)]
        ..tail = 7;

      // Act
      final error = packRefusal(() => pack(layout, row));

      // Assert
      expect(error.reason, contains('holds 1 rounds'));
    });

    test('a repeat has one row a round, and none for no round', () {
      // Arrange
      final layout = repeatScheme();
      final track = Track()..points = [point(10, 20), point(30, 40)];

      // Act
      final raw = pack(layout, track);
      final back = unpackRow(raw, layout).row!;
      final nothing = unpackRow(unhex('01'), layout).row!;

      // Assert
      expect(hex(raw), '010a000000140000001e00000028000000');
      expect(back.points!.map((p) => p.lon), [20, 40]);
      expect(nothing.points, isEmpty);
      expect(hex(pack(layout, Track())), '01');
    });

    test(
      'sized, two-bit slots and bits bind to the members of a round row',
      () {
        // Arrange
        final layout = batchScheme();
        final row = Batch()
          ..count = 2
          ..items = [
            Item()
              ..len = 2
              ..payload = Uint8List.fromList([9, 8])
              ..a = 1
              ..b = 2
              ..marks = [1, 0],
            Item()
              ..len = 1
              ..payload = Uint8List.fromList([7])
              ..a = 3
              ..b = 0
              ..marks = [1],
          ];

        // Act
        final raw = pack(layout, row);
        final back = unpackRow(raw, layout).row!;

        // Assert
        expect(hex(raw), '0102020908090101070301');
        expect(back.items![0].payload, [9, 8]);
        expect(back.items!.map((i) => i.marks), [
          [1, 0],
          [1],
        ]);
        expect(back.items!.map((i) => (i.a, i.b)), [(1, 2), (3, 0)]);
      },
    );

    test('a short packet inside a typed round names the field', () {
      // Arrange
      final layout = routeScheme();
      final cut = unhex('01020a000000140000001e00');

      // Act
      final result = unpackRow(cut, layout);

      // Assert
      expect(result.row, isNull);
      expect(
        [result.error!.name, result.error!.needed, result.error!.left],
        ['lat', 4, 2],
      );
    });

    test('a scheme of typed rows needs every round bound', () {
      // Arrange and Act
      final error = refusal(
        () => rowScheme<Route>(1, Route.new, [
          u8(0, 'n').bind<Route>(get: (r) => r.n, set: (r, v) => r.n = v),
          times(1, 0, [latField(), lonField()]),
        ]),
      );

      // Assert
      expect(error.reason, contains('needs every round bound'));
    });

    test('the body must be bound to the round row type', () {
      // Arrange and Act
      final error = refusal(
        () => rowScheme<Route>(1, Route.new, [
          u8(0, 'n').bind<Route>(get: (r) => r.n, set: (r, v) => r.n = v),
          times(1, 0, [
            i32(1, 'lat').bind<Other>(get: (r) => r.x, set: (r, v) => r.x = v),
          ]).bind<Route, Point>(
            create: Point.new,
            get: (r) => r.points,
            set: (r, v) => r.points = v,
          ),
        ]),
      );

      // Assert
      expect(error.name, 'lat');
    });

    test('a round bound to another row type is refused', () {
      // Arrange and Act
      final error = refusal(
        () => rowScheme<Route>(1, Route.new, [
          u8(0, 'n').bind<Route>(get: (r) => r.n, set: (r, v) => r.n = v),
          times(1, 0, [latField()]).bind<Track, Point>(
            create: Point.new,
            get: (r) => r.points,
            set: (r, v) => r.points = v,
          ),
        ]),
      );

      // Assert
      expect(error.reason, contains('the scheme\'s row is'));
    });

    test('a map scheme ignores the binding of a round', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        times(1, 0, [u8(1, 'x')]).bind<Route, Point>(
          create: Point.new,
          get: (r) => r.points,
          set: (r, v) => r.points = v,
        ),
      ]);

      // Act
      final raw = pack(layout, {
        'n': 2,
        'x': [1, 2],
      });

      // Assert
      expect(hex(raw), '01020102');
    });
  });
}
