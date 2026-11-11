import 'dart:typed_data';

const int sha256DigestSize = 32;
const int sha256BlockSize = 64;

const int _mask32 = 0xffffffff;

final Uint32List _k = Uint32List.fromList(const [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

/// `value` must already be a 32-bit word: the left shift is masked because a
/// Dart `int` keeps the bits a 32-bit register would drop.
int _rotr(int value, int bits) =>
    ((value >>> bits) | (value << (32 - bits))) & _mask32;

/// Incremental SHA-256 (FIPS 180-4).
///
/// [digest] wipes the hasher: the chaining state, the block buffer and the
/// message schedule read zero afterwards, and [reset] makes it usable again.
final class Sha256 {
  final Uint32List _state = Uint32List(8);
  final Uint8List _block = Uint8List(sha256BlockSize);
  final Uint32List _schedule = Uint32List(64);
  int _blockLength = 0;
  int _messageLength = 0;
  bool _open = true;

  Sha256() {
    reset();
  }

  /// The buffers a wipe overwrites, for the wipe tests.
  List<TypedData> get workingBuffers => [_state, _block, _schedule];

  void reset() {
    wipe();
    _state[0] = 0x6a09e667;
    _state[1] = 0xbb67ae85;
    _state[2] = 0x3c6ef372;
    _state[3] = 0xa54ff53a;
    _state[4] = 0x510e527f;
    _state[5] = 0x9b05688c;
    _state[6] = 0x1f83d9ab;
    _state[7] = 0x5be0cd19;
    _open = true;
  }

  /// Hashes `data[start..end)`; `data` is read, never kept.
  void update(Uint8List data, [int start = 0, int? end]) {
    if (!_open) throw StateError('Sha256 used after digest() or wipe()');
    final stop = RangeError.checkValidRange(start, end, data.length);
    _messageLength += stop - start;
    var at = start;
    if (_blockLength > 0) {
      while (at < stop && _blockLength < sha256BlockSize) {
        _block[_blockLength++] = data[at++];
      }
      if (_blockLength < sha256BlockSize) return;
      _compress(_block, 0);
      _blockLength = 0;
    }
    while (stop - at >= sha256BlockSize) {
      _compress(data, at);
      at += sha256BlockSize;
    }
    while (at < stop) {
      _block[_blockLength++] = data[at++];
    }
  }

  /// The 32-byte digest; the hasher is wiped.
  Uint8List digest() {
    final out = Uint8List(sha256DigestSize);
    digestInto(out);
    return out;
  }

  /// Writes the digest to `out[offset..offset + 32)`; the hasher is wiped.
  void digestInto(Uint8List out, [int offset = 0]) {
    if (!_open) throw StateError('Sha256 used after digest() or wipe()');
    RangeError.checkValidRange(offset, offset + sha256DigestSize, out.length);
    final bytes = _messageLength;
    _block[_blockLength++] = 0x80;
    if (_blockLength > sha256BlockSize - 8) {
      _block.fillRange(_blockLength, sha256BlockSize, 0);
      _compress(_block, 0);
      _blockLength = 0;
    }
    _block.fillRange(_blockLength, sha256BlockSize - 8, 0);
    // The length in bits, 64-bit big-endian, from the byte count.
    _writeBigEndian(_block, 56, (bytes >>> 29) & _mask32);
    _writeBigEndian(_block, 60, (bytes << 3) & _mask32);
    _compress(_block, 0);
    for (var i = 0; i < 8; i++) {
      _writeBigEndian(out, offset + i * 4, _state[i]);
    }
    wipe();
  }

  /// Zeroes the state, the block buffer and the schedule; [reset] reopens.
  void wipe() {
    _state.fillRange(0, _state.length, 0);
    _block.fillRange(0, _block.length, 0);
    _schedule.fillRange(0, _schedule.length, 0);
    _blockLength = 0;
    _messageLength = 0;
    _open = false;
  }

  void _compress(Uint8List data, int offset) {
    final w = _schedule;
    for (var i = 0; i < 16; i++) {
      final at = offset + i * 4;
      w[i] =
          (data[at] << 24) |
          (data[at + 1] << 16) |
          (data[at + 2] << 8) |
          data[at + 3];
    }
    for (var i = 16; i < 64; i++) {
      final x = w[i - 15];
      final y = w[i - 2];
      final s0 = _rotr(x, 7) ^ _rotr(x, 18) ^ (x >>> 3);
      final s1 = _rotr(y, 17) ^ _rotr(y, 19) ^ (y >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & _mask32;
    }

    var a = _state[0];
    var b = _state[1];
    var c = _state[2];
    var d = _state[3];
    var e = _state[4];
    var f = _state[5];
    var g = _state[6];
    var h = _state[7];
    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & _mask32) & g);
      final t1 = (h + s1 + ch + _k[i] + w[i]) & _mask32;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & _mask32;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _mask32;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask32;
    }
    _state[0] = (_state[0] + a) & _mask32;
    _state[1] = (_state[1] + b) & _mask32;
    _state[2] = (_state[2] + c) & _mask32;
    _state[3] = (_state[3] + d) & _mask32;
    _state[4] = (_state[4] + e) & _mask32;
    _state[5] = (_state[5] + f) & _mask32;
    _state[6] = (_state[6] + g) & _mask32;
    _state[7] = (_state[7] + h) & _mask32;
  }
}

void _writeBigEndian(Uint8List out, int offset, int word) {
  out[offset] = (word >>> 24) & 0xff;
  out[offset + 1] = (word >>> 16) & 0xff;
  out[offset + 2] = (word >>> 8) & 0xff;
  out[offset + 3] = word & 0xff;
}

/// SHA-256 of `data` in one piece.
Uint8List sha256(Uint8List data) => (Sha256()..update(data)).digest();
