import 'dart:io';

import 'package:packbin/packbin.dart';

import 'ecc.dart';
import 'frame.dart';
import 'hex.dart';
import 'kinds.dart';
import 'render.dart';

/// The commands of the Dart member of the cross-language ring, the same as the other drivers:
///
///   pack-<kind>                 prints the hex of the kind's row and a newline, exits 0
///   unpack-<kind> <hex>         exits 0 only if the packet unpacks to the kind's row (the round kinds also repack
///                               to the same hex)
///   unpack-<kind>-short <hex>   listgroup, dictgroup and listflags only: exits 0 only if the packet is refused (an
///                               error value) and no row comes back
///   ecc-batch <file>, frame-batch <file>   see ecc.dart and frame.dart
///
/// Any other command, or a missing hex, exits 2; hex that is not hex exits 1 with a message. The position program is
/// bin/position.dart; ring-dart.sh builds both.
int fail(String message) {
  stderr.writeln(message);
  return 1;
}

/// Reads "pack-user", "unpack-user" and "unpack-listgroup-short"; null when it is none of these forms.
({String name, String op, bool short})? splitCommand(String cmd) {
  String op;
  String rest;
  if (cmd.startsWith('pack-')) {
    op = 'pack';
    rest = cmd.substring('pack-'.length);
  } else if (cmd.startsWith('unpack-')) {
    op = 'unpack';
    rest = cmd.substring('unpack-'.length);
  } else {
    return null;
  }
  final short = rest.endsWith('-short');
  if (short) rest = rest.substring(0, rest.length - '-short'.length);
  return (name: rest, op: op, short: short);
}

int _unpackKind(String cmd, Kind k, String text, {required bool short}) {
  final buf = hexBytes(text);
  if (buf == null) return fail('$cmd: bad hex: "$text"');
  final got = unpackRow(buf, k.scheme);
  if (short) {
    // A short element is refused and no row comes back.
    if (got.error != null && got.row == null) return 0;
    return fail('$cmd: read ${render(got.row)}, expected a refusal');
  }
  final row = got.row;
  if (row == null) return fail('$cmd: ${got.error}');
  if (render(row) != render(k.want)) {
    return fail('$cmd: read ${render(row)}, expected ${render(k.want)}');
  }
  if (k.repack) {
    final again = hexString(pack(k.scheme, row));
    if (again != text.toLowerCase()) {
      return fail('$cmd: repacked $again, expected $text');
    }
  }
  return 0;
}

int _kindCommand(String cmd, List<String> args) {
  final parts = splitCommand(cmd);
  if (parts == null) return 2;
  final Kind? k;
  try {
    k = kindOf(parts.name);
  } on PackbinException catch (e) {
    return fail('$cmd: scheme: $e');
  }
  if (k == null || (parts.short && !shortKinds.contains(parts.name))) return 2;
  if (parts.op == 'pack' && !parts.short) {
    try {
      stdout.writeln(hexString(pack(k.scheme, k.pack)));
      return 0;
    } on PackbinException catch (e) {
      return fail('$cmd: $e');
    }
  }
  if (parts.op == 'unpack' && args.length >= 2) {
    return _unpackKind(cmd, k, args[1], short: parts.short);
  }
  return 2;
}

/// Runs the command in [args] and returns the exit status.
int run(List<String> args) {
  if (args.isEmpty) return 2;
  final cmd = args[0];
  if (cmd.startsWith('frame-')) return runFrame(args);
  if (cmd.startsWith('ecc-')) return runEcc(args);
  return _kindCommand(cmd, args);
}
