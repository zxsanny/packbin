import 'dart:typed_data';

import 'package:packbin/src/crypto/chacha20.dart';
import 'package:packbin/src/crypto/hkdf_sha256.dart';
import 'package:packbin/src/crypto/hmac_sha256.dart';
import 'package:packbin/src/crypto/sha256.dart';
import 'package:test/test.dart';

import 'vectors.dart';

// AZ-4141 AC-1 to AC-3 beyond the one-shot rows: parts, sub-ranges, 32-bit
// words and empty inputs. Expected bytes come from the rows
// of fixtures/crypto/vectors.txt; the few constants below are named with
// their origin.

// Not in the shared file. RFC 8439 block of key ff x32, nonce ff x12, counter
// 2^32 - 1, and of the zero key and nonce at counter 2^32 - 1: computed with
// scripts/crypto/chacha20.py and equal to `openssl enc -chacha20`.
const _onesBlock =
    'd72b21cfa4b6b0c41d61f62b8a11159c6a4f63bc56c2035796c7ad37811121bb'
    'ec56d54a530f3a933dd28a50feb23bfaf64f405be985f3718bdf4683e96be749';
const _lastCounterBlock =
    'ace4cd09e294d1912d4ad205d06f95d9c2f2bfcf453e8753f128765b62215f4d'
    '92c74f2f626c6a640c0b1284d839ec81f1696281dafc3e684593937023b58b1d';
// Not in the shared file; computed with Python hashlib and hmac.
const _sha256Of64Ones =
    '8667e718294e9e0df1d30600ba3eeb201f764aad2dad72748643e4a285e1d1f7';
const _hmacOnesKeyOnesData =
    '8a5183c87dc4e694cd5d35870edc9b2fbe05c71dbf9c5b17648a25f816fe292d';
const _hmacEmptyKeyEmptyData =
    'b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad';

void main() {
  final rows = parseRows(vectorsFile().readAsStringSync());
  VectorRow row(String primitive, String id) => rows.firstWhere(
    (row) => row.primitive == primitive && row.id == id,
    orElse: () => throw StateError('no row $primitive $id'),
  );

  group('SHA-256 in parts', () {
    test('two parts split at every offset give the one-shot digest', () {
      // Arrange
      final vector = row('sha256', 'fips180-4:b.2');
      final message = vector.bytes('msg');
      final digests = <String>{};

      // Act
      for (var split = 0; split <= message.length; split++) {
        final hasher = Sha256()
          ..update(Uint8List.sublistView(message, 0, split))
          ..update(message, split);
        digests.add(toHex(hasher.digest()));
      }

      // Assert
      expect(digests, {vector.text('digest')});
    });

    test('a million bytes in uneven parts give the row digest', () {
      // Arrange
      final vector = row('sha256', 'fips180-4:b.3');
      final total = vector.number('repeat');
      final chunk = filled(977, vector.bytes('byte').single);
      final hasher = Sha256();

      // Act
      for (var done = 0; done < total;) {
        final take = total - done < chunk.length ? total - done : chunk.length;
        hasher.update(chunk, 0, take);
        done += take;
      }

      // Assert
      expect(toHex(hasher.digest()), vector.text('digest'));
    });

    test('a reset hasher gives the next digest', () {
      // Arrange
      final first = row('sha256', 'fips180-4:b.1');
      final second = row('sha256', 'derived:a64');
      final hasher = Sha256()..update(first.bytes('msg'));

      // Act
      final one = toHex(hasher.digest());
      hasher
        ..reset()
        ..update(filled(64, 0x61));
      final two = toHex(hasher.digest());

      // Assert
      expect(one, first.text('digest'));
      expect(two, second.text('digest'));
    });
  });

  group('HMAC-SHA256 in parts', () {
    test('two parts split at every offset give the one-shot MAC', () {
      // Arrange
      final vector = row('hmac256', 'rfc4231:4.8');
      final key = vector.bytes('key');
      final data = vector.bytes('data');
      final macs = <String>{};

      // Act
      for (var split = 0; split <= data.length; split++) {
        final mac = HmacSha256(key)
          ..update(data, 0, split)
          ..update(data, split);
        macs.add(toHex(mac.digest()));
        macs.add(
          toHex(
            hmacSha256Parts(key, [
              Uint8List.sublistView(data, 0, split),
              Uint8List.sublistView(data, split),
            ]),
          ),
        );
      }

      // Assert
      expect(macs, {vector.text('mac')});
    });

    test('digestInto writes the MAC at the offset only', () {
      // Arrange
      final vector = row('hmac256', 'rfc4231:4.2');
      final out = filled(40, 0xee);

      // Act
      (HmacSha256(
        vector.bytes('key'),
      )..update(vector.bytes('data'))).digestInto(out, 4);

      // Assert
      expect(toHex(out), 'eeeeeeee${vector.text('mac')}eeeeeeee');
    });
  });

  group('ChaCha20 on a caller buffer', () {
    test('a sub-range is encrypted in place and its neighbours kept', () {
      // Arrange
      final vector = row('chacha-xor', 'rfc8439:a.2.2');
      final plain = vector.bytes('plain');
      final buffer = filled(plain.length + 12, 0xee)
        ..setRange(7, 7 + plain.length, plain);

      // Act
      chacha20XorInPlace(
        vector.bytes('key'),
        vector.bytes('nonce'),
        vector.number('counter'),
        buffer,
        7,
        7 + plain.length,
      );

      // Assert
      expect(toHex(buffer), '${'ee' * 7}${vector.text('cipher')}${'ee' * 5}');
    });

    test('the stream continues at the next counter after 64 bytes', () {
      // Arrange
      final vector = row('chacha-xor', 'rfc8439:a.2.2');
      final key = vector.bytes('key');
      final nonce = vector.bytes('nonce');
      final counter = vector.number('counter');
      final buffer = vector.bytes('plain');
      expect(buffer.length, greaterThan(128));

      // Act
      chacha20XorInPlace(key, nonce, counter + 1, buffer, 64);
      chacha20XorInPlace(key, nonce, counter, buffer, 0, 64);

      // Assert
      expect(toHex(buffer), vector.text('cipher'));
    });

    test('the cipher row decrypts to the plain row', () {
      // Arrange
      final vector = row('chacha-xor', 'rfc8439:2.4.2');
      final buffer = vector.bytes('cipher');

      // Act
      chacha20XorInPlace(
        vector.bytes('key'),
        vector.bytes('nonce'),
        vector.number('counter'),
        buffer,
      );

      // Assert
      expect(toHex(buffer), vector.text('plain'));
    });

    test('the key stream of a zero text is the block row', () {
      // Arrange
      final vector = row('chacha-block', 'rfc8439:2.3.2');

      // Act
      final stream = chacha20Xor(
        vector.bytes('key'),
        vector.bytes('nonce'),
        vector.number('counter'),
        Uint8List(64),
      );

      // Assert
      expect(toHex(stream), vector.text('block'));
    });
  });

  group('32-bit words (AC-2)', () {
    test('the all-ones key and nonce at counter 2^32 - 1', () {
      // Arrange
      final key = filled(32, 0xff);
      final nonce = filled(12, 0xff);

      // Act
      final block = chacha20Block(key, nonce, 0xffffffff);
      final stream = chacha20Xor(key, nonce, 0xffffffff, Uint8List(64));

      // Assert
      expect(toHex(block), _onesBlock);
      expect(toHex(stream), _onesBlock);
    });

    test('the zero key at counter 2^32 - 1, alone and as a second block', () {
      // Arrange
      final key = Uint8List(32);
      final nonce = Uint8List(12);

      // Act
      final block = chacha20Block(key, nonce, 0xffffffff);
      final two = chacha20Xor(key, nonce, 0xfffffffe, Uint8List(128));

      // Assert
      expect(toHex(block), _lastCounterBlock);
      expect(toHex(Uint8List.sublistView(two, 64)), _lastCounterBlock);
    });

    test('SHA-256 and HMAC of all-ones words', () {
      // Arrange
      final ones = filled(64, 0xff);
      final key = filled(32, 0xff);

      // Act
      final digest = sha256(ones);
      final mac = hmacSha256(key, Uint8List.sublistView(ones, 0, 32));

      // Assert
      expect(toHex(digest), _sha256Of64Ones);
      expect(toHex(mac), _hmacOnesKeyOnesData);
    });

    test('the 0xaa key rows of the shared file', () {
      // Arrange
      final vector = row('hmac256', 'rfc4231:4.4');

      // Act
      final mac = hmacSha256(vector.bytes('key'), vector.bytes('data'));

      // Assert
      expect(toHex(mac), vector.text('mac'));
    });
  });

  group('empty inputs (AC-3)', () {
    test('SHA-256 of nothing, with and without an empty update', () {
      // Arrange
      final vector = row('sha256', 'nist:empty');
      final empty = Uint8List(0);

      // Act
      final oneShot = sha256(empty);
      final untouched = Sha256().digest();
      final emptyParts =
          (Sha256()
                ..update(empty)
                ..update(empty))
              .digest();

      // Assert
      expect(toHex(oneShot), vector.text('digest'));
      expect(toHex(untouched), vector.text('digest'));
      expect(toHex(emptyParts), vector.text('digest'));
    });

    test('HMAC of an empty message', () {
      // Arrange
      final empty = Uint8List(0);

      // Act
      final oneShot = hmacSha256(empty, empty);
      final noUpdate = HmacSha256(empty).digest();
      final noParts = hmacSha256Parts(empty, const []);

      // Assert
      expect(toHex(oneShot), _hmacEmptyKeyEmptyData);
      expect(toHex(noUpdate), _hmacEmptyKeyEmptyData);
      expect(toHex(noParts), _hmacEmptyKeyEmptyData);
    });

    test('empty parts between the parts of an HMAC row change nothing', () {
      // Arrange
      final vector = row('hmac256', 'rfc4231:4.3');
      final data = vector.bytes('data');
      final empty = Uint8List(0);

      // Act
      final mac = hmacSha256Parts(vector.bytes('key'), [
        empty,
        Uint8List.sublistView(data, 0, 5),
        empty,
        Uint8List.sublistView(data, 5),
        empty,
      ]);

      // Assert
      expect(toHex(mac), vector.text('mac'));
    });

    test('HKDF with an empty salt and info, and a zero length', () {
      // Arrange
      final vector = row('hkdf256', 'rfc5869:a.3');
      final ikm = vector.bytes('ikm');
      final empty = Uint8List(0);

      // Act
      final prk = hkdfExtract(empty, ikm);
      final okm = hkdfSha256(ikm, empty, empty, vector.number('len'));
      final none = hkdfSha256(ikm, empty, empty, 0);

      // Assert
      expect(vector.text('salt'), '-');
      expect(vector.text('info'), '-');
      expect(toHex(prk), vector.text('prk'));
      expect(toHex(okm), vector.text('okm'));
      expect(none, isEmpty);
    });

    test('ChaCha20 of an empty text is empty and writes nothing', () {
      // Arrange
      final key = filled(32, 1);
      final nonce = filled(12, 2);
      final buffer = filled(8, 0xee);

      // Act
      final out = chacha20Xor(key, nonce, 0, Uint8List(0));
      chacha20XorInPlace(key, nonce, 0xffffffff, buffer, 3, 3);

      // Assert
      expect(out, isEmpty);
      expect(toHex(buffer), 'ee' * 8);
    });
  });
}
