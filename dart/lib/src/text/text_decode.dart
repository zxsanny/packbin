import 'dart:typed_data';

import 'text_model.dart';
import 'text_tables.dart';
import 'text_types.dart';

TextFailure _refuse(TextRefusal kind, int left) => TextFailure(kind, 0, left);

/// Decodes the string field at [offset] of [buf]. Never throws: every refusal
/// is a [TextFailure]. Time and memory follow the payload length, and the
/// text stops growing at 65,535 UTF-8 bytes.
TextRead decodeText(Uint8List buf, [int offset = 0]) {
  final size = buf.length;
  if (offset < 0 || offset > size) {
    return const TextFailure(TextRefusal.short, 1, 0);
  }
  final left = size - offset;
  var p = offset;
  var count = 0;
  for (var k = 0; ; k++) {
    if (k == 3) return _refuse(TextRefusal.varint, left);
    if (p >= size) return TextFailure(TextRefusal.short, k + 1, left);
    final b = buf[p++];
    count |= (b & 0x7f) << (7 * k);
    if (b & 0x80 == 0) {
      if (k > 0 && b == 0) return _refuse(TextRefusal.varint, left);
      break;
    }
  }
  if (count == 0) return TextValue('', p);
  if (count > size - p) return TextFailure(TextRefusal.short, count, size - p);
  final end = p + count;
  final first = buf[p];
  final start = (first >> 2) & 7;
  if (start == 4) {
    if (first != rawPrefix) return _refuse(TextRefusal.raw, left);
    if (count - 1 > maxTextBytes) return _refuse(TextRefusal.length, left);
    final text = _strictUtf8(buf, p + 1, end);
    if (text == null) return _refuse(TextRefusal.utf8, left);
    return TextValue(text, end);
  }
  if (start > 4) return _refuse(TextRefusal.mode, left);
  final pad = first >> 5;
  final total = 8 * count - pad;
  if (total < 6) return _refuse(TextRefusal.pad, left);
  if (buf[end - 1] & ((1 << pad) - 1) != 0) {
    return _refuse(TextRefusal.pad, left);
  }
  return _symbols(buf, p, end, start, total, left);
}

TextRead _symbols(
  Uint8List buf,
  int p,
  int end,
  int start,
  int total,
  int left,
) {
  final model = textModel;
  var mode = start;
  var lock = false;
  var cap = false;
  var bytes = 0;
  var pos = 6;
  // A symbol is at least one bit and a text has at most 65,535 code points.
  final symbolBits = total - 6;
  final points = Uint32List(
    symbolBits < maxTextBytes ? symbolBits : maxTextBytes,
  );
  var n = 0;
  while (pos < total) {
    final at = p + (pos >> 3);
    final window =
        (buf[at] << 16) |
        ((at + 1 < end ? buf[at + 1] : 0) << 8) |
        (at + 2 < end ? buf[at + 2] : 0);
    final entry = model.decode[mode][(window >> (8 - (pos & 7))) & 0xffff];
    final sym = entry & 0xff;
    pos += entry >> 8;
    if (pos > total) return _refuse(TextRefusal.code, left);
    final letters = mode == 3 ? 0 : model.alpha[mode].length;
    int cp;
    if (sym < letters) {
      final upper = model.upper[mode][sym];
      if (cap) {
        if (upper == 0) return _refuse(TextRefusal.cap, left);
        cp = upper;
        cap = false;
      } else {
        cp = lock && upper != 0 ? upper : model.alpha[mode][sym];
      }
    } else if (mode == 3
        ? sym < textNumset.length
        : sym < letters + textShared.length) {
      if (cap) return _refuse(TextRefusal.cap, left);
      cp = mode == 3 ? textNumset[sym] : textShared[sym - letters];
    } else if (sym < model.switchAt[mode] + 3) {
      if (cap) return _refuse(TextRefusal.cap, left);
      final target = sym - model.switchAt[mode];
      mode = target < mode ? target : target + 1;
      continue;
    } else if (sym == model.capAt[mode]) {
      if (lock || cap) return _refuse(TextRefusal.cap, left);
      cap = true;
      continue;
    } else if (sym == model.escAt[mode]) {
      if (cap) return _refuse(TextRefusal.cap, left);
      if (pos + 8 > total) return _refuse(TextRefusal.esc, left);
      final b0 = _bitsByte(buf, p, end, pos);
      final width = _utf8Width(b0);
      if (width == 0) return _refuse(TextRefusal.utf8, left);
      if (pos + 8 * width > total) return _refuse(TextRefusal.esc, left);
      cp = width == 1 ? b0 : b0 & (0xff >> (width + 1));
      for (var j = 1; j < width; j++) {
        final b = _bitsByte(buf, p, end, pos + 8 * j);
        if (b & 0xc0 != 0x80) return _refuse(TextRefusal.utf8, left);
        cp = (cp << 6) | (b & 0x3f);
      }
      pos += 8 * width;
      if (!_scalarOfWidth(cp, width)) return _refuse(TextRefusal.utf8, left);
    } else {
      if (cap) return _refuse(TextRefusal.cap, left);
      lock = !lock;
      continue;
    }
    bytes += utf8Length(cp);
    if (bytes > maxTextBytes) return _refuse(TextRefusal.length, left);
    points[n++] = cp;
  }
  if (cap) return _refuse(TextRefusal.cap, left);
  return TextValue(String.fromCharCodes(points, 0, n), end);
}

/// The byte count a UTF-8 lead byte announces, 0 for a byte that leads nothing.
int _utf8Width(int lead) => lead < 0x80
    ? 1
    : lead >> 5 == 6
    ? 2
    : lead >> 4 == 14
    ? 3
    : lead >> 3 == 30
    ? 4
    : 0;

/// Overlong forms, surrogates and values above U+10FFFF are not UTF-8.
bool _scalarOfWidth(int cp, int width) {
  final least = width == 1
      ? 0
      : width == 2
      ? 0x80
      : width == 3
      ? 0x800
      : 0x10000;
  return cp >= least && (cp < 0xd800 || cp > 0xdfff) && cp <= 0x10ffff;
}

/// The 8 bits at bit [at] of the payload that starts at byte [p] and ends
/// before [end].
int _bitsByte(Uint8List buf, int p, int end, int at) {
  final i = p + (at >> 3);
  final shift = at & 7;
  final next = shift > 0 && i + 1 < end ? buf[i + 1] : 0;
  return (((buf[i] << 8) | next) >> (8 - shift)) & 0xff;
}

/// The text of the UTF-8 bytes `buf[from..end)`, or null when they are not
/// valid UTF-8. Written here because `dart:convert` drops a leading U+FEFF.
String? _strictUtf8(Uint8List buf, int from, int end) {
  final points = Uint32List(end - from);
  var n = 0;
  var i = from;
  while (i < end) {
    final b0 = buf[i];
    final width = _utf8Width(b0);
    if (width == 0 || i + width > end) return null;
    var cp = width == 1 ? b0 : b0 & (0xff >> (width + 1));
    for (var j = 1; j < width; j++) {
      final b = buf[i + j];
      if (b & 0xc0 != 0x80) return null;
      cp = (cp << 6) | (b & 0x3f);
    }
    if (!_scalarOfWidth(cp, width)) return null;
    points[n++] = cp;
    i += width;
  }
  return String.fromCharCodes(points, 0, n);
}
