import 'dart:typed_data';

import 'package:packbin/packbin.dart';

/// A typed row: each field is bound to a member by a getter and a setter.
/// `null` is no value, so a null `heading`, `speed` or `altitude` leaves its
/// bit in the flag byte clear and takes no space.
class Position {
  int sid = 0;
  int lat = 0;
  int lon = 0;
  int profile = 0;
  int? heading;
  int? speed;
  int? altitude;
}

String hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  final position = rowScheme<Position>(0x40, Position.new, [
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
  ]);

  final raw = pack(
    position,
    Position()
      ..sid = 1
      ..lat = 500000000
      ..lon = 300000000
      ..profile = 1,
  );
  print(hex(raw));

  final got = unpackRow(raw, position);
  print('${got.row!.lat} ${got.row!.heading == null}');
}
