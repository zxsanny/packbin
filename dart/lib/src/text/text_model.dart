import 'dart:typed_data';

import 'text_tables.dart';

const int maxTextBytes = 65535;
const int rawPrefix = 0x10;

/// The first code point above every letter and character a mode names (the
/// Cyrillic block ends at U+04FF); from here on a character has only `ESC`.
const int tableChars = 0x500;

int utf8Length(int cp) => cp < 0x80
    ? 1
    : cp < 0x800
    ? 2
    : cp < 0x10000
    ? 3
    : 4;

/// The lookups built once from the generated tables. Symbol order of a text
/// mode: the letters, the 32 shared characters, three switches, `CAP`, `LOCK`,
/// `ESC`; of the number mode: the 15 number characters, three switches, `ESC`.
final class TextModel {
  TextModel() {
    for (var m = 0; m < 3; m++) {
      switchAt[m] = alpha[m].length + textShared.length;
      capAt[m] = switchAt[m] + 3;
      lockAt[m] = capAt[m] + 1;
      escAt[m] = lockAt[m] + 1;
    }
    switchAt[3] = textNumset.length;
    capAt[3] = -1;
    lockAt[3] = -1;
    escAt[3] = textNumset.length + 3;
    for (var m = 0; m < 4; m++) {
      _buildCodes(_lengths[m]);
    }
    for (var m = 0; m < 3; m++) {
      lowerAt.add(_indexTable(alpha[m], tableChars));
      upperAt.add(_indexTable(upper[m], tableChars));
    }
    for (var s = 0; s < 8; s++) {
      _buildControls(s);
    }
  }

  static const List<List<int>> _lengths = [
    textLengthsUa,
    textLengthsRu,
    textLengthsEn,
    textLengthsNum,
  ];

  final List<List<int>> alpha = const [textUa, textRu, textEn];

  /// The capital of each letter, 0 when it has none (the apostrophe).
  final List<List<int>> upper = const [textUaUpper, textRuUpper, textEnUpper];

  final Int32List switchAt = Int32List(4);
  final Int32List capAt = Int32List(4);
  final Int32List lockAt = Int32List(4);
  final Int32List escAt = Int32List(4);

  final List<Uint16List> code = [];
  final List<Uint8List> len = [];

  /// `decode[m][next 16 bits] = (code length << 8) | symbol index`. Every
  /// table is a complete code, so every pattern decodes.
  final List<Uint16List> decode = [];

  final List<Int16List> lowerAt = [];
  final List<Int16List> upperAt = [];
  late final Int16List sharedAt = _indexTable(textShared, 128);
  late final Int16List numAt = _indexTable(textNumset, 128);

  /// Control edges of a state (`mode * 2 + lock`): the switches to the other
  /// modes and the lock toggle, as (symbol index, bits, target state) triples
  /// in symbol-index order, 4 triples a state.
  final Int32List ctlCount = Int32List(8);
  final Int32List ctl = Int32List(8 * 4 * 3);

  void _buildCodes(List<int> lengths) {
    final order = List<int>.generate(lengths.length, (i) => i)
      ..sort((a, b) {
        final d = lengths[a] - lengths[b];
        return d != 0 ? d : a - b;
      });
    final codes = Uint16List(lengths.length);
    final table = Uint16List(65536);
    var next = 0;
    var prev = 0;
    for (final sym in order) {
      final length = lengths[sym];
      next <<= length - prev;
      codes[sym] = next;
      final first = next << (16 - length);
      table.fillRange(first, first + (1 << (16 - length)), (length << 8) | sym);
      next++;
      prev = length;
    }
    code.add(codes);
    len.add(Uint8List.fromList(lengths));
    decode.add(table);
  }

  void _buildControls(int s) {
    final m = s >> 1;
    final k = s & 1;
    final list = <List<int>>[];
    for (var t = 0; t < 4; t++) {
      if (t == m) continue;
      final sym = switchAt[m] + (t < m ? t : t - 1);
      list.add([sym, len[m][sym], t * 2 + k]);
    }
    if (m < 3) list.add([lockAt[m], len[m][lockAt[m]], m * 2 + (1 - k)]);
    list.sort((a, b) => a[0] - b[0]);
    ctlCount[s] = list.length;
    for (var j = 0; j < list.length; j++) {
      ctl.setRange(s * 12 + j * 3, s * 12 + j * 3 + 3, list[j]);
    }
  }

  static Int16List _indexTable(List<int> chars, int size) {
    final t = Int16List(size)..fillRange(0, size, -1);
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] != 0) t[chars[i]] = i;
    }
    return t;
  }
}

final TextModel textModel = TextModel();
