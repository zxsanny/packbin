import 'dart:io';
import 'dart:typed_data';

/// One data row of `fixtures/crypto/vectors.txt`.
final class VectorRow {
  final String primitive;
  final String id;
  final Map<String, String> fields;

  VectorRow(this.primitive, this.id, this.fields);

  String get name => '$primitive $id';

  bool has(String field) => fields.containsKey(field);

  String text(String field) {
    final value = fields[field];
    if (value == null) throw FormatException('$name: no $field=');
    return value;
  }

  Uint8List bytes(String field) => fromHex(text(field), '$name $field');

  int number(String field) => int.parse(text(field));
}

const List<String> primitives = [
  'sha256',
  'hmac256',
  'hkdf256',
  'chacha-block',
  'chacha-xor',
];

/// The shared file, found by walking up from the current directory, so the
/// tests run from `dart/` and from the repository root alike.
File vectorsFile() {
  var dir = Directory.current.absolute;
  while (true) {
    final file = File('${dir.path}/fixtures/crypto/vectors.txt');
    if (file.existsSync()) return file;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'fixtures/crypto/vectors.txt not found above ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

/// The lines that are neither empty nor a comment.
List<String> dataLines(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty && !line.startsWith('#')) line.trimRight(),
];

List<VectorRow> parseRows(String text) {
  final rows = <VectorRow>[];
  for (final line in dataLines(text)) {
    final words = line.split(' ');
    if (words.length < 3) throw FormatException('short row: $line');
    final fields = <String, String>{};
    for (final pair in words.skip(2)) {
      final at = pair.indexOf('=');
      if (at <= 0) {
        throw FormatException('${words[0]} ${words[1]}: "$pair" not key=value');
      }
      fields[pair.substring(0, at)] = pair.substring(at + 1);
    }
    rows.add(VectorRow(words[0], words[1], fields));
  }
  return rows;
}

final RegExp _hex = RegExp(r'^(?:[0-9a-f]{2})+$');

/// Lowercase hex to bytes; `-` is the empty byte string.
Uint8List fromHex(String value, [String what = 'value']) {
  if (value == '-') return Uint8List(0);
  if (!_hex.hasMatch(value)) {
    throw FormatException('$what is not lowercase hex');
  }
  final out = Uint8List(value.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String toHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List filled(int length, int byte) =>
    Uint8List(length)..fillRange(0, length, byte);
