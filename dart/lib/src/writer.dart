import 'dart:typed_data';

import 'errors.dart';
import 'limits.dart';

/// The bytes one pack call writes, type byte included. The buffer grows by
/// doubling.
final class Writer {
  Writer(int typeByte) : this._(Uint8List(64), typeByte);

  Writer._(this._buf, int typeByte) : _data = ByteData.sublistView(_buf) {
    _buf[0] = typeByte;
  }

  Uint8List _buf;
  ByteData _data;
  int _length = 1;

  int get length => _length;

  /// The index of the first of [size] bytes, which are then taken.
  int _take(int size) {
    final at = _length;
    final need = at + size;
    if (need > _buf.length) _grow(need);
    _length = need;
    return at;
  }

  void _grow(int need) {
    if (need > defaultMaxBytes) {
      throw packFail(
        null,
        '',
        'the packet would be $need bytes, above the limit of $defaultMaxBytes bytes',
      );
    }
    var capacity = _buf.length * 2;
    while (capacity < need) {
      capacity *= 2;
    }
    final next = Uint8List(capacity)..setRange(0, _length, _buf);
    _buf = next;
    _data = ByteData.sublistView(next);
  }

  void byte(int value) => _buf[_take(1)] = value;

  /// The low [size] bytes (1, 2, 4 or 8) of [value], two's complement.
  void integer(int value, int size, bool signed, Endian endian) {
    final at = _take(size);
    switch (size) {
      case 1:
        _buf[at] = value;
      case 2:
        signed
            ? _data.setInt16(at, value, endian)
            : _data.setUint16(at, value, endian);
      case 4:
        signed
            ? _data.setInt32(at, value, endian)
            : _data.setUint32(at, value, endian);
      default:
        _data.setInt64(at, value, endian);
    }
  }

  /// Writes [value] as an f32; false when a finite value became an infinity,
  /// in which case nothing is kept.
  bool float32(double value, Endian endian) {
    final at = _take(4);
    _data.setFloat32(at, value, endian);
    if (value.isFinite && _data.getFloat32(at, endian).isInfinite) {
      _length = at;
      return false;
    }
    return true;
  }

  void float64(double value, Endian endian) =>
      _data.setFloat64(_take(8), value, endian);

  void bytes(Uint8List value) {
    final at = _take(value.length);
    _buf.setRange(at, at + value.length, value);
  }

  /// Appends [size] zero bytes and returns the index of the first.
  int reserve(int size) {
    final at = _take(size);
    _buf.fillRange(at, at + size, 0);
    return at;
  }

  /// Sets [bits] in the byte at [at], which [reserve] made.
  void or(int at, int bits) => _buf[at] |= bits;

  /// A byte already written, set again.
  void patch(int at, int value) => _buf[at] = value;

  /// A copy of the bytes written, in a buffer of its own.
  Uint8List take() => _buf.sublist(0, _length);
}
