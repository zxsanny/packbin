import 'dart:io';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

/// One data row of an ECC vector file: its kind word, its id and the rest.
final class EccRow {
  EccRow(this.kind, this.id, this.args);

  final String kind;
  final String id;
  final List<String> args;

  String get name => '$kind $id';

  int number(int i) => int.parse(args[i]);

  /// The bytes of argument [i]; `-` is the empty buffer.
  Uint8List bytes(int i) => args[i] == '-' ? Uint8List(0) : unhex(args[i]);
}

/// The shared file at [relative] under the repository root, found by
/// walking up from the current directory until `fixtures/ecc/vectors.txt`
/// exists.
File eccFile(String relative) {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/fixtures/ecc/vectors.txt').existsSync()) {
      return File('${dir.path}/$relative');
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'fixtures/ecc/vectors.txt not found above ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

/// The lines of the file that are neither empty nor a comment.
List<String> dataLines(String relative) => [
  for (final line in eccFile(relative).readAsStringSync().split('\n'))
    if (line.trim().isNotEmpty && !line.startsWith('#')) line.trim(),
];

/// Every data row of the file at [relative], in file order. A row with no
/// id fails the load.
List<EccRow> loadRows(String relative) {
  final rows = <EccRow>[];
  for (final line in dataLines(relative)) {
    final words = line.split(RegExp(r'\s+'));
    if (words.length < 3) throw FormatException('short row', line);
    rows.add(EccRow(words[0], words[1], words.sublist(2)));
  }
  return rows;
}

/// How many rows of each kind.
Map<String, int> countByKind(List<EccRow> rows) {
  final counts = <String, int>{};
  for (final row in rows) {
    counts[row.kind] = (counts[row.kind] ?? 0) + 1;
  }
  return counts;
}

const countFile = 'fixtures/ecc/vectors.txt';
const percentFile = 'fixtures/ecc/percent-vectors.txt';

/// The row word of a refusal.
String word(PackbinError error) =>
    error.kind == ErrorKind.short ? 'short' : error.kind.term;

PackbinException thrown(void Function() body) {
  try {
    body();
  } on PackbinException catch (e) {
    return e;
  }
  fail('nothing was thrown');
}
