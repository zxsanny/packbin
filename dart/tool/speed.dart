// The compiled speed measurement (AC-8): build with
// `dart compile exe tool/speed.dart -o <path>` and run the result. It exits
// 1 when a bound is missed.
import 'dart:typed_data';

import 'package:packbin/packbin.dart';

class Target {
  int sid = 0;
  int lat = 0;
  int lon = 0;
  int profile = 0;
  int? heading;
  int? speed;
  int? altitude;
}

class Frame extends Target {
  int time = 0;
  double climb = 0;
  double range = 0;
  int battery = 0;
}

List<Field> targetFields() => [
  u16(0, 'sid').bind<Target>(get: (r) => r.sid, set: (r, v) => r.sid = v),
  i32(1, 'lat').bind<Target>(get: (r) => r.lat, set: (r, v) => r.lat = v),
  i32(2, 'lon').bind<Target>(get: (r) => r.lon, set: (r, v) => r.lon = v),
  u8(
    3,
    'profile',
  ).bind<Target>(get: (r) => r.profile, set: (r, v) => r.profile = v),
  flags(4, [
    u16(
      4,
      'heading',
    ).bind<Target>(get: (r) => r.heading, set: (r, v) => r.heading = v),
    u8(
      5,
      'speed',
    ).bind<Target>(get: (r) => r.speed, set: (r, v) => r.speed = v),
    i16(
      6,
      'altitude',
    ).bind<Target>(get: (r) => r.altitude, set: (r, v) => r.altitude = v),
  ]),
];

/// The AC-1 scheme.
Scheme<Target> targetScheme() => rowScheme(0x40, Target.new, targetFields());

/// The AC-1 row: its packet is `fixtures/golden.hex`.
Target goldenTarget() => Target()
  ..sid = 1
  ..lat = 500000000
  ..lon = 300000000
  ..profile = 1;

/// A target frame of 40 bytes: the AC-1 fields with every motion field set,
/// then a u64, an f32, an f64 and a u16.
Scheme<Frame> frameScheme() => rowScheme(0x41, Frame.new, [
  ...targetFields(),
  u64(7, 'time').bind<Frame>(get: (r) => r.time, set: (r, v) => r.time = v),
  f32(8, 'climb').bind<Frame>(get: (r) => r.climb, set: (r, v) => r.climb = v),
  f64(9, 'range').bind<Frame>(get: (r) => r.range, set: (r, v) => r.range = v),
  u16(
    10,
    'battery',
  ).bind<Frame>(get: (r) => r.battery, set: (r, v) => r.battery = v),
]);

Uint8List framePacket() => pack(
  frameScheme(),
  Frame()
    ..sid = 7
    ..lat = 500000000
    ..lon = 300000000
    ..profile = 1
    ..heading = 90
    ..speed = 12
    ..altitude = -40
    ..time = 1790000000000
    ..climb = 1.5
    ..range = 1234.5
    ..battery = 4100,
);

const roundTrips = 100000;
const roundTripBoundMs = 1000;
const frameUnpacks = 1000;
const frameBoundMs = 10;

/// Milliseconds for [roundTrips] pack-then-unpack round trips of the AC-1
/// row; -1 when a round trip gave a wrong row.
double timeRoundTrips() {
  final layout = targetScheme();
  final row = goldenTarget();
  var wrong = 0;
  final watch = Stopwatch()..start();
  for (var i = 0; i < roundTrips; i++) {
    final got = unpackRow(pack(layout, row), layout).row;
    if (got == null || got.lat != 500000000 || got.heading != null) wrong++;
  }
  watch.stop();
  return wrong == 0 ? watch.elapsedMicroseconds / 1000 : -1;
}

/// Milliseconds for [frameUnpacks] unpacks of the 40-byte frame; -1 when an
/// unpack gave a wrong row.
double timeFrameUnpacks() {
  final layout = frameScheme();
  final packet = framePacket();
  var wrong = 0;
  final watch = Stopwatch()..start();
  for (var i = 0; i < frameUnpacks; i++) {
    final got = unpackRow(packet, layout).row;
    if (got == null || got.battery != 4100 || got.altitude != -40) wrong++;
  }
  watch.stop();
  return wrong == 0 ? watch.elapsedMicroseconds / 1000 : -1;
}

int main() {
  timeRoundTrips();
  timeFrameUnpacks();
  final trips = timeRoundTrips();
  final frames = timeFrameUnpacks();
  print(
    'round trips: $roundTrips in ${trips.toStringAsFixed(2)} ms (bound $roundTripBoundMs ms)',
  );
  print(
    'frame unpacks: $frameUnpacks x ${framePacket().length} bytes in ${frames.toStringAsFixed(3)} ms (bound $frameBoundMs ms)',
  );
  final ok =
      trips >= 0 &&
      trips <= roundTripBoundMs &&
      frames >= 0 &&
      frames <= frameBoundMs;
  print(ok ? 'PASS' : 'FAIL');
  return ok ? 0 : 1;
}
