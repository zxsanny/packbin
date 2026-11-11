import 'dart:typed_data';

import 'package:packbin/src/crypto/chacha20.dart';
import 'package:packbin/src/crypto/hkdf_sha256.dart';
import 'package:packbin/src/crypto/hmac_sha256.dart';
import 'package:packbin/src/crypto/sha256.dart';
import 'package:test/test.dart';

import 'vectors.dart';

// AZ-4141: the wipes of key-holding buffers and the refusals of the
// internal crypto.

bool _allZero(List<TypedData> buffers) => buffers.every(
  (buffer) => buffer.buffer
      .asUint8List(buffer.offsetInBytes, buffer.lengthInBytes)
      .every((byte) => byte == 0),
);

void main() {
  final rows = parseRows(vectorsFile().readAsStringSync());
  VectorRow row(String primitive, String id) => rows.firstWhere(
    (row) => row.primitive == primitive && row.id == id,
    orElse: () => throw StateError('no row $primitive $id'),
  );

  group('wipes', () {
    test('a SHA-256 hasher reads zero after digest and after wipe', () {
      // Arrange
      final finished = Sha256()..update(filled(70, 0x61));
      final dropped = Sha256()..update(filled(70, 0x61));
      final before = _allZero(finished.workingBuffers);

      // Act
      finished.digest();
      dropped.wipe();

      // Assert
      expect(before, isFalse);
      expect(_allZero(finished.workingBuffers), isTrue);
      expect(_allZero(dropped.workingBuffers), isTrue);
    });

    test('an HMAC object reads zero after digest and after wipe', () {
      // Arrange
      final key = filled(32, 0x4b);
      final finished = HmacSha256(key)..update(filled(70, 0x61));
      final dropped = HmacSha256(key)..update(filled(3, 0x61));
      final before = _allZero(finished.workingBuffers);

      // Act
      finished.digest();
      dropped.wipe();

      // Assert
      expect(before, isFalse);
      expect(_allZero(finished.workingBuffers), isTrue);
      expect(_allZero(dropped.workingBuffers), isTrue);
    });

    test('a wiped hasher refuses more input until reset', () {
      // Arrange
      final hasher = Sha256()..wipe();
      final mac = HmacSha256(Uint8List(32))..digest();

      // Act
      void update() => hasher.update(Uint8List(1));
      void digest() => hasher.digest();
      void macUpdate() => mac.update(Uint8List(1));
      void macDigest() => mac.digest();

      // Assert
      expect(update, throwsStateError);
      expect(digest, throwsStateError);
      expect(macUpdate, throwsStateError);
      expect(macDigest, throwsStateError);
    });

    test('the inputs of every function are left as given', () {
      // Arrange
      final vector = row('hkdf256', 'rfc5869:a.1');
      final ikm = vector.bytes('ikm');
      final salt = vector.bytes('salt');
      final info = vector.bytes('info');
      final key = filled(32, 0x4b);
      final nonce = filled(12, 0x4e);

      // Act
      hkdfSha256(ikm, salt, info, 42);
      hmacSha256(key, ikm);
      chacha20Block(key, nonce, 1);
      chacha20XorInPlace(key, nonce, 1, Uint8List(70));

      // Assert
      expect(toHex(ikm), vector.text('ikm'));
      expect(toHex(salt), vector.text('salt'));
      expect(toHex(info), vector.text('info'));
      expect(toHex(key), '4b' * 32);
      expect(toHex(nonce), '4e' * 12);
    });
  });

  group('refusals', () {
    final key = Uint8List(32);
    final nonce = Uint8List(12);

    test('a key or nonce of the wrong length', () {
      for (final (k, n) in [
        (Uint8List(31), nonce),
        (Uint8List(33), nonce),
        (key, Uint8List(8)),
        (key, Uint8List(16)),
      ]) {
        // Act
        void block() => chacha20Block(k, n, 0);
        void stream() => chacha20XorInPlace(k, n, 0, Uint8List(10));

        // Assert
        expect(block, throwsArgumentError);
        expect(stream, throwsArgumentError);
      }
    });

    test('a counter outside 0 to 2^32 - 1', () {
      for (final counter in [-1, 0x100000000]) {
        // Act
        void block() => chacha20Block(key, nonce, counter);
        void stream() => chacha20Xor(key, nonce, counter, Uint8List(10));

        // Assert
        expect(block, throwsRangeError);
        expect(stream, throwsRangeError);
      }
    });

    test('a stream past the last counter is refused before any write', () {
      // Arrange
      final buffer = filled(65, 0xee);

      // Act
      void pastTheLast() => chacha20XorInPlace(key, nonce, 0xffffffff, buffer);

      // Assert
      expect(pastTheLast, throwsRangeError);
      expect(toHex(buffer), 'ee' * 65);
    });

    test('a range outside the buffer', () {
      // Act
      void stream() => chacha20XorInPlace(key, nonce, 0, Uint8List(4), 2, 5);
      void hash() => Sha256().update(Uint8List(4), 3, 2);
      void shortOut() => Sha256().digestInto(Uint8List(40), 9);

      // Assert
      expect(stream, throwsRangeError);
      expect(hash, throwsRangeError);
      expect(shortOut, throwsRangeError);
    });

    test('HKDF gives at most 255 blocks', () {
      // Arrange
      final vector = row('hkdf256', 'rfc5869:a.3');
      final ikm = vector.bytes('ikm');
      final empty = Uint8List(0);

      // Act
      final longest = hkdfSha256(ikm, empty, empty, hkdfMaxLength);
      void tooLong() => hkdfSha256(ikm, empty, empty, hkdfMaxLength + 1);
      void negative() => hkdfExpand(Uint8List(32), empty, -1);

      // Assert
      expect(longest.length, 8160);
      expect(toHex(Uint8List.sublistView(longest, 0, 42)), vector.text('okm'));
      expect(tooLong, throwsRangeError);
      expect(negative, throwsRangeError);
    });
  });
}
