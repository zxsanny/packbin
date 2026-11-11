// Prints the hex of the AC-1 position row (the golden 4001000065cd1d00a3e1110100), as the position programs of the
// other packages do. publish-position.sh builds it with ring-dart.sh.
import 'dart:io';

import 'package:handoff_dart/hex.dart';
import 'package:handoff_dart/position_scheme.dart';
import 'package:packbin/packbin.dart';

Future<void> main() async {
  try {
    final raw = pack(positionScheme(), {
      'sid': 1,
      'lat': 500000000,
      'lon': 300000000,
      'profile': 1,
    });
    stdout.writeln(hexString(raw));
  } on PackbinException catch (e) {
    stderr.writeln('position pack: $e');
    await stderr.flush();
    exit(1);
  }
  await stdout.flush();
}
