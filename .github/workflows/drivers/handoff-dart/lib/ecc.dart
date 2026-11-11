import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';

import 'hex.dart';
import 'position_scheme.dart';

// The message ECC commands of the handoff driver (AZ-2689; contract message-ecc.md).
//
//   ecc-protect <n> <clear hex>   prints the clear position message packed again with n parity bytes, or the error kind
//   ecc-repair <n> <t> <hex>      prints the position message repaired (hex, then the repaired count), or the error kind
//   ecc-batch <file>              one line per line of the file: `protect <n> <hex>` or `repair <n> <t> <hex>`
//
// The word in the n place is an integer parity count, or p<N>: a parity percentage N (withParityPercent, 0..100).
// "-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
// bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.

/// The parity setting word: a count, or a percentage when [percent] is set.
final class _Setting {
  const _Setting(this.percent, this.n);

  final bool percent;
  final int n;

  Scheme<Map<String, Object?>> apply(Scheme<Map<String, Object?>> s) =>
      percent ? s.withParityPercent(n) : s.withParity(n);
}

_Setting? _parseSetting(String word) {
  if (word.startsWith('p')) {
    final digits = word.substring(1);
    if (digits.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(digits)) return null;
    final n = int.tryParse(digits);
    return n == null ? null : _Setting(true, n);
  }
  final n = int.tryParse(word);
  return n == null ? null : _Setting(false, n);
}

Uint8List? _bytes(String token) =>
    token == '-' ? Uint8List(0) : hexBytes(token);

String _kind(PackbinError e) => switch (e.kind) {
  ErrorKind.uncorrectable => 'uncorrectable',
  ErrorKind.tooLong => 'too_long',
  ErrorKind.short when e.name == 'parity' => 'short',
  ErrorKind.trailing => 'trailing',
  ErrorKind.unknownType => 'type_mismatch',
  _ => 'unpack_failed',
};

String _protect(_Setting n, Uint8List clear) {
  final position = positionScheme();
  final row = unpackRow(clear, position).row;
  if (row == null) return 'unpack_failed';
  final Scheme<Map<String, Object?>> protected;
  try {
    protected = n.apply(position);
  } on PackbinException {
    return 'bad_parity';
  }
  try {
    return hexString(pack(protected, row));
  } on PackbinException {
    return 'pack_error';
  }
}

String _repair(_Setting n, int t, Uint8List received) {
  final position = positionScheme();
  final Scheme<Map<String, Object?>> protected;
  try {
    protected = n.apply(position);
  } on PackbinException {
    return 'bad_parity';
  }
  final Unpacked<Map<String, Object?>> got;
  try {
    got = unpackRowRepair(received, protected, t);
  } on PackbinException {
    return 'bad_limit';
  }
  final row = got.row;
  if (row == null) return _kind(got.error!);
  try {
    return '${hexString(pack(position, row))} ${got.repaired}';
  } on PackbinException {
    return 'pack_error';
  }
}

/// The answer to one line, or null when the line is not a protect or repair line.
String? _line(List<String> w) {
  if (w.length == 3 && w[0] == 'protect') {
    final n = _parseSetting(w[1]);
    final clear = _bytes(w[2]);
    if (n == null || clear == null) return null;
    return _protect(n, clear);
  }
  if (w.length == 4 && w[0] == 'repair') {
    final n = _parseSetting(w[1]);
    final t = int.tryParse(w[2]);
    final received = _bytes(w[3]);
    if (n == null || t == null || received == null) return null;
    return _repair(n, t, received);
  }
  return null;
}

/// Runs one ecc command and returns the exit status.
int runEcc(List<String> args) {
  final List<List<String>> lines;
  if (args[0] == 'ecc-protect' && args.length == 3) {
    lines = [
      ['protect', args[1], args[2]],
    ];
  } else if (args[0] == 'ecc-repair' && args.length == 4) {
    lines = [
      ['repair', args[1], args[2], args[3]],
    ];
  } else if (args[0] == 'ecc-batch' && args.length == 2) {
    final String text;
    try {
      text = utf8.decode(File(args[1]).readAsBytesSync(), allowMalformed: true);
    } on FileSystemException catch (e) {
      stderr.writeln('ecc-batch: ${e.message}: ${e.path}');
      return 1;
    }
    lines = [
      for (final w in wordLines(text))
        if (w.isNotEmpty) w,
    ];
  } else {
    return 2;
  }
  for (final w in lines) {
    final out = _line(w);
    if (out == null) {
      stderr.writeln('ecc line: ${w.join(' ')}');
      return 1;
    }
    stdout.writeln(out);
  }
  return 0;
}
