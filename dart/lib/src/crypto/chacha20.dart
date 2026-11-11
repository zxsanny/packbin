import 'dart:typed_data';

const int chacha20KeySize = 32;
const int chacha20NonceSize = 12;
const int chacha20BlockSize = 64;
const int chacha20MaxCounter = 0xffffffff;

const int _mask32 = 0xffffffff;

/// `value` must already be a 32-bit word; the left shift is masked because a
/// Dart `int` keeps the bits a 32-bit register would drop.
int _rotl(int value, int bits) =>
    ((value << bits) & _mask32) | (value >>> (32 - bits));

void _quarter(Uint32List w, int a, int b, int c, int d) {
  w[a] = (w[a] + w[b]) & _mask32;
  w[d] = _rotl(w[d] ^ w[a], 16);
  w[c] = (w[c] + w[d]) & _mask32;
  w[b] = _rotl(w[b] ^ w[c], 12);
  w[a] = (w[a] + w[b]) & _mask32;
  w[d] = _rotl(w[d] ^ w[a], 8);
  w[c] = (w[c] + w[d]) & _mask32;
  w[b] = _rotl(w[b] ^ w[c], 7);
}

int _readLittleEndian(Uint8List bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);

void _check(Uint8List key, Uint8List nonce, int counter) {
  if (key.length != chacha20KeySize) {
    throw ArgumentError.value(key.length, 'key', 'ChaCha20 key is 32 bytes');
  }
  if (nonce.length != chacha20NonceSize) {
    throw ArgumentError.value(
      nonce.length,
      'nonce',
      'ChaCha20 nonce is 12 bytes',
    );
  }
  if (counter < 0 || counter > chacha20MaxCounter) {
    throw RangeError.range(counter, 0, chacha20MaxCounter, 'counter');
  }
}

void _loadState(Uint32List state, Uint8List key, Uint8List nonce) {
  state[0] = 0x61707865;
  state[1] = 0x3320646e;
  state[2] = 0x79622d32;
  state[3] = 0x6b206574;
  for (var i = 0; i < 8; i++) {
    state[4 + i] = _readLittleEndian(key, i * 4);
  }
  state[13] = _readLittleEndian(nonce, 0);
  state[14] = _readLittleEndian(nonce, 4);
  state[15] = _readLittleEndian(nonce, 8);
}

/// The block of `state` at `counter`, written to `out[0..64)`; `work` is
/// scratch that holds key-dependent words afterwards.
void _blockInto(Uint32List state, Uint32List work, int counter, Uint8List out) {
  state[12] = counter;
  work.setRange(0, 16, state);
  for (var round = 0; round < 10; round++) {
    _quarter(work, 0, 4, 8, 12);
    _quarter(work, 1, 5, 9, 13);
    _quarter(work, 2, 6, 10, 14);
    _quarter(work, 3, 7, 11, 15);
    _quarter(work, 0, 5, 10, 15);
    _quarter(work, 1, 6, 11, 12);
    _quarter(work, 2, 7, 8, 13);
    _quarter(work, 3, 4, 9, 14);
  }
  for (var i = 0; i < 16; i++) {
    final word = (work[i] + state[i]) & _mask32;
    final at = i * 4;
    out[at] = word & 0xff;
    out[at + 1] = (word >>> 8) & 0xff;
    out[at + 2] = (word >>> 16) & 0xff;
    out[at + 3] = (word >>> 24) & 0xff;
  }
}

/// The 64-byte block (RFC 8439 section 2.3) of a 32-byte key, a 12-byte
/// nonce and a block counter of 0 to 2^32 - 1.
Uint8List chacha20Block(Uint8List key, Uint8List nonce, int counter) {
  _check(key, nonce, counter);
  final state = Uint32List(16);
  final work = Uint32List(16);
  final out = Uint8List(chacha20BlockSize);
  _loadState(state, key, nonce);
  _blockInto(state, work, counter, out);
  state.fillRange(0, 16, 0);
  work.fillRange(0, 16, 0);
  return out;
}

/// XORs `buffer[start..end)` in place with the key stream that starts at
/// block `counter` (the same call encrypts and decrypts).
///
/// A range that would need a block past counter 2^32 - 1 is refused before
/// any byte is written: a wrapped counter would repeat key stream.
void chacha20XorInPlace(
  Uint8List key,
  Uint8List nonce,
  int counter,
  Uint8List buffer, [
  int start = 0,
  int? end,
]) {
  _check(key, nonce, counter);
  final stop = RangeError.checkValidRange(start, end, buffer.length);
  final length = stop - start;
  final blocks = (length + chacha20BlockSize - 1) ~/ chacha20BlockSize;
  if (blocks > 0 && counter + blocks - 1 > chacha20MaxCounter) {
    throw RangeError(
      'ChaCha20 stream of $blocks blocks from counter $counter passes '
      'counter $chacha20MaxCounter',
    );
  }
  if (length == 0) return;
  final state = Uint32List(16);
  final work = Uint32List(16);
  final pad = Uint8List(chacha20BlockSize);
  _loadState(state, key, nonce);
  for (var index = 0; index < blocks; index++) {
    _blockInto(state, work, counter + index, pad);
    final at = start + index * chacha20BlockSize;
    final take = stop - at < chacha20BlockSize ? stop - at : chacha20BlockSize;
    for (var i = 0; i < take; i++) {
      buffer[at + i] ^= pad[i];
    }
  }
  state.fillRange(0, 16, 0);
  work.fillRange(0, 16, 0);
  pad.fillRange(0, pad.length, 0);
}

/// A copy of `data` XOR the key stream from block `counter`; `data` is not
/// written.
Uint8List chacha20Xor(
  Uint8List key,
  Uint8List nonce,
  int counter,
  Uint8List data,
) {
  final out = Uint8List.fromList(data);
  chacha20XorInPlace(key, nonce, counter, out);
  return out;
}
