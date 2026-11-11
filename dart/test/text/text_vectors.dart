import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One row of fixtures/text/vectors.txt: `kind id rest...` (the row syntax is
/// at the top of that file).
final class TextRow {
  TextRow(this.kind, this.id, this.rest);

  final String kind;
  final String id;
  final List<String> rest;

  /// The UTF-8 bytes of the text of an `enc` or `alt` row ("-" is empty).
  Uint8List get textBytes => rest[0] == '-' ? Uint8List(0) : unhex(rest[0]);

  /// The text of an `enc` or `alt` row. `utf8.decode` drops one leading
  /// U+FEFF, which is part of the text here.
  String get text {
    final b = textBytes;
    final mark = b.length >= 3 && b[0] == 0xef && b[1] == 0xbb && b[2] == 0xbf;
    return (mark ? '\ufeff' : '') + utf8.decode(b);
  }

  /// The field of an `enc` or `alt` row, the buffer of a `bad` row (after
  /// its kind) or the packet of a `ref` row.
  Uint8List get bytes => switch (kind) {
    'enc' || 'alt' => unhex(rest[1]),
    'bad' => rest.length > 1 ? unhex(rest[1]) : Uint8List(0),
    _ => unhex(rest[0]),
  };
}

/// The repository root: the first directory from the current one upwards
/// that holds fixtures/text/vectors.txt.
Directory repositoryRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/fixtures/text/vectors.txt').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'fixtures/text/vectors.txt not found above '
        '${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

/// Every row of fixtures/text/vectors.txt, in file order.
List<TextRow> loadTextRows() {
  final file = File('${repositoryRoot().path}/fixtures/text/vectors.txt');
  final rows = <TextRow>[];
  for (final line in file.readAsLinesSync()) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final f = line.split(' ');
    if (f.length < 2) throw FormatException('vectors.txt row: $line');
    rows.add(TextRow(f[0], f[1], f.sublist(2)));
  }
  return rows;
}

Uint8List unhex(String hex) {
  if (hex.length.isOdd) throw FormatException('odd hex: $hex');
  final out = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(2 * i, 2 * i + 2), radix: 16);
  }
  return out;
}

String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
