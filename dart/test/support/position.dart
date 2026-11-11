import 'package:packbin/packbin.dart';

/// The typed row of the first example (AC-1).
class Position {
  int sid = 0;
  int lat = 0;
  int lon = 0;
  int profile = 0;
  int? heading;
  int? speed;
  int? altitude;
}

/// The fields of the first example, bound to [Position]; a map scheme reads
/// the same list by name.
List<Field> positionFields() => [
  u16(0, 'sid').bind<Position>(get: (r) => r.sid, set: (r, v) => r.sid = v),
  i32(1, 'lat').bind<Position>(get: (r) => r.lat, set: (r, v) => r.lat = v),
  i32(2, 'lon').bind<Position>(get: (r) => r.lon, set: (r, v) => r.lon = v),
  u8(
    3,
    'profile',
  ).bind<Position>(get: (r) => r.profile, set: (r, v) => r.profile = v),
  flags(4, [
    u16(
      4,
      'heading',
    ).bind<Position>(get: (r) => r.heading, set: (r, v) => r.heading = v),
    u8(
      5,
      'speed',
    ).bind<Position>(get: (r) => r.speed, set: (r, v) => r.speed = v),
    i16(
      6,
      'altitude',
    ).bind<Position>(get: (r) => r.altitude, set: (r, v) => r.altitude = v),
  ]),
];

Scheme<Position> positionScheme() =>
    rowScheme(0x40, Position.new, positionFields());

Scheme<Map<String, Object?>> positionMapScheme() =>
    scheme(0x40, positionFields());

Position goldenPosition() => Position()
  ..sid = 1
  ..lat = 500000000
  ..lon = 300000000
  ..profile = 1;

Map<String, Object?> goldenMap() => {
  'sid': 1,
  'lat': 500000000,
  'lon': 300000000,
  'profile': 1,
};
