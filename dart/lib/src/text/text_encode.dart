import 'dart:typed_data';

import 'text_model.dart';
import 'text_types.dart';

/// The field bytes of one string: the count, then the payload (the optimal
/// parse with the contract's tie-break, or raw UTF-8 when that is not
/// smaller). Throws [TextEncodeException] for an unpaired surrogate and for a
/// text over 65,535 UTF-8 bytes.
Uint8List encodeText(String text, [TextCache? cache]) {
  if (cache != null && text == cache.text) return cache.field;
  final field = text.isEmpty ? Uint8List(1) : _encoder.encode(text);
  if (cache != null) {
    cache.text = text;
    cache.field = field;
  }
  return field;
}

final _Encoder _encoder = _Encoder();
final Uint8List _noBytes = Uint8List(0);

final class _Encoder {
  static const int _inf = 0x3fffffff;
  static const int _scratchChars = 4096;

  final TextModel _model = textModel;

  // The edges that consume one character in one state: first symbol index,
  // bits, the second symbol (-1 for none) and the UTF-8 length written after
  // an ESC (0 for none).
  int _edgeCount = 0;
  final Int32List _edgeFirst = Int32List(4);
  final Int32List _edgeBits = Int32List(4);
  final Int32List _edgeSecond = Int32List(4);
  final Int32List _edgeEsc = Int32List(4);

  Uint8List _out = _noBytes;
  int _pos = 0;
  int _acc = 0;
  int _accBits = 0;

  final Int32List _scratchPoints = Int32List(_scratchChars);
  final Int32List _scratchCosts = Int32List((_scratchChars + 1) * 8);
  int _pointBytes = 0;

  Uint8List encode(String text) {
    final size = text.length;
    // 65,535 UTF-8 bytes are at most 65,535 UTF-16 units.
    if (size > maxTextBytes) {
      throw TextEncodeException(TextEncodeProblem.tooLong, _utf8Bytes(text));
    }
    final shared = size <= _scratchChars;
    final points = shared ? _scratchPoints : Int32List(size);
    final costs = shared ? _scratchCosts : Int32List((size + 1) * 8);
    try {
      final n = _codePoints(text, points);
      if (_pointBytes > maxTextBytes) {
        throw TextEncodeException(TextEncodeProblem.tooLong, _pointBytes);
      }
      return _parse(points, costs, n, _pointBytes);
    } finally {
      // The encoder is shared by every call: nothing of this text stays.
      _out = _noBytes;
      if (shared) {
        _scratchPoints.fillRange(0, size, 0);
        _scratchCosts.fillRange(0, (size + 1) * 8, 0);
      }
    }
  }

  /// The UTF-8 length of [text]; each half of a surrogate pair adds 2.
  static int _utf8Bytes(String text) {
    var bytes = 0;
    for (var j = 0; j < text.length; j++) {
      final c = text.codeUnitAt(j);
      bytes += c >= 0xd800 && c <= 0xdfff ? 2 : utf8Length(c);
    }
    return bytes;
  }

  int _codePoints(String text, Int32List points) {
    final size = text.length;
    var n = 0;
    var bytes = 0;
    for (var j = 0; j < size;) {
      var c = text.codeUnitAt(j++);
      if (c >= 0xd800 && c <= 0xdfff) {
        final low = c < 0xdc00 && j < size ? text.codeUnitAt(j) : 0;
        if (low < 0xdc00 || low > 0xdfff) {
          throw TextEncodeException(TextEncodeProblem.loneSurrogate, j - 1);
        }
        c = 0x10000 + ((c - 0xd800) << 10) + (low - 0xdc00);
        j++;
      }
      points[n++] = c;
      bytes += utf8Length(c);
    }
    _pointBytes = bytes;
    return n;
  }

  void _addEdge(int first, int bits, int second, int esc) {
    _edgeFirst[_edgeCount] = first;
    _edgeBits[_edgeCount] = bits;
    _edgeSecond[_edgeCount] = second;
    _edgeEsc[_edgeCount] = esc;
    _edgeCount++;
  }

  void _edgesOf(int m, int cp, int lock) {
    _edgeCount = 0;
    final len = _model.len[m];
    if (m < 3) {
      final letters = _model.alpha[m].length;
      final lower = cp < tableChars ? _model.lowerAt[m][cp] : -1;
      if (lower >= 0) {
        if (lock == 0 || _model.upper[m][lower] == 0) {
          _addEdge(lower, len[lower], -1, 0);
        }
      } else {
        final upper = cp < tableChars ? _model.upperAt[m][cp] : -1;
        if (upper >= 0) {
          if (lock == 1) {
            _addEdge(upper, len[upper], -1, 0);
          } else {
            final cap = _model.capAt[m];
            _addEdge(cap, len[cap] + len[upper], upper, 0);
          }
        } else {
          final shared = cp < 128 ? _model.sharedAt[cp] : -1;
          if (shared >= 0) {
            _addEdge(letters + shared, len[letters + shared], -1, 0);
          }
        }
      }
    } else {
      final num = cp < 128 ? _model.numAt[cp] : -1;
      if (num >= 0) _addEdge(num, len[num], -1, 0);
    }
    final esc = utf8Length(cp);
    _addEdge(_model.escAt[m], len[_model.escAt[m]] + 8 * esc, -1, esc);
  }

  void _putBits(int value, int bits) {
    _acc = (_acc << bits) | value;
    _accBits += bits;
    while (_accBits >= 8) {
      _out[_pos++] = (_acc >> (_accBits - 8)) & 0xff;
      _accBits -= 8;
    }
    _acc &= (1 << _accBits) - 1;
  }

  void _putSymbol(int m, int sym) =>
      _putBits(_model.code[m][sym], _model.len[m][sym]);

  void _putUtf8(int cp) {
    if (cp < 0x80) {
      _putBits(cp, 8);
    } else if (cp < 0x800) {
      _putBits(0xc0 | (cp >> 6), 8);
      _putBits(0x80 | (cp & 0x3f), 8);
    } else if (cp < 0x10000) {
      _putBits(0xe0 | (cp >> 12), 8);
      _putBits(0x80 | ((cp >> 6) & 0x3f), 8);
      _putBits(0x80 | (cp & 0x3f), 8);
    } else {
      _putBits(0xf0 | (cp >> 18), 8);
      _putBits(0x80 | ((cp >> 12) & 0x3f), 8);
      _putBits(0x80 | ((cp >> 6) & 0x3f), 8);
      _putBits(0x80 | (cp & 0x3f), 8);
    }
  }

  /// Starts a field of [payloadBytes] payload bytes and writes its count.
  void _begin(int payloadBytes) {
    final header = payloadBytes < 0x80
        ? 1
        : payloadBytes < 0x4000
        ? 2
        : 3;
    _out = Uint8List(header + payloadBytes);
    _pos = 0;
    _acc = 0;
    _accBits = 0;
    var count = payloadBytes;
    for (var k = 1; k < header; k++) {
      _out[_pos++] = (count & 0x7f) | 0x80;
      count >>= 7;
    }
    _out[_pos++] = count;
  }

  /// Fills the cost table [f]: `f[i * 8 + s]` is the fewest bits that finish
  /// the text from code point `i` in state `s`.
  void _fillCosts(Int32List points, Int32List f, int n) {
    final ctl = _model.ctl;
    final ctlCount = _model.ctlCount;
    f.fillRange(n * 8, n * 8 + 8, 0);
    for (var i = n - 1; i >= 0; i--) {
      final base = i * 8;
      final cp = points[i];
      for (var s = 0; s < 8; s++) {
        _edgesOf(s >> 1, cp, s & 1);
        var best = _inf;
        final after = f[base + 8 + s];
        for (var e = 0; e < _edgeCount; e++) {
          final v = _edgeBits[e] + after;
          if (v < best) best = v;
        }
        f[base + s] = best;
      }
      var changed = true;
      while (changed) {
        changed = false;
        for (var s = 0; s < 8; s++) {
          for (var j = 0; j < ctlCount[s]; j++) {
            final at = s * 12 + j * 3;
            final v = ctl[at + 1] + f[base + ctl[at + 2]];
            if (v < f[base + s]) {
              f[base + s] = v;
              changed = true;
            }
          }
        }
      }
    }
  }

  Uint8List _parse(Int32List points, Int32List f, int n, int textBytes) {
    _fillCosts(points, f, n);
    var start = 0;
    for (var m = 1; m < 4; m++) {
      if (f[m * 2] < f[start * 2]) start = m;
    }
    final payloadBits = 6 + f[start * 2];
    final payloadBytes = (payloadBits + 7) >> 3;
    final rawBytes = 1 + textBytes;

    if (payloadBytes >= rawBytes) {
      _begin(rawBytes);
      _out[_pos++] = rawPrefix;
      for (var i = 0; i < n; i++) {
        _putUtf8(points[i]);
      }
      return _out;
    }

    _begin(payloadBytes);
    _putBits(8 * payloadBytes - payloadBits, 3);
    _putBits(start, 3);
    final ctl = _model.ctl;
    var state = start * 2;
    var i = 0;
    while (i < n) {
      final m = state >> 1;
      final want = f[i * 8 + state];
      var bestFirst = _inf;
      var bestControl = -1;
      var bestEdge = -1;
      for (var j = 0; j < _model.ctlCount[state]; j++) {
        final at = state * 12 + j * 3;
        if (ctl[at] < bestFirst &&
            ctl[at + 1] + f[i * 8 + ctl[at + 2]] == want) {
          bestFirst = ctl[at];
          bestControl = at;
        }
      }
      _edgesOf(m, points[i], state & 1);
      for (var e = 0; e < _edgeCount; e++) {
        if (_edgeFirst[e] < bestFirst &&
            _edgeBits[e] + f[i * 8 + 8 + state] == want) {
          bestFirst = _edgeFirst[e];
          bestControl = -1;
          bestEdge = e;
        }
      }
      _putSymbol(m, bestFirst);
      if (bestControl >= 0) {
        state = ctl[bestControl + 2];
      } else {
        final second = _edgeSecond[bestEdge];
        if (second >= 0) _putSymbol(m, second);
        if (_edgeEsc[bestEdge] > 0) _putUtf8(points[i]);
        i++;
      }
    }
    if (_accBits > 0) _out[_pos++] = (_acc << (8 - _accBits)) & 0xff;
    return _out;
  }
}
