import 'dart:typed_data';

import 'package:packbin/src/crypto/chacha20.dart';
import 'package:packbin/src/crypto/hkdf_sha256.dart';
import 'package:packbin/src/crypto/hmac_sha256.dart';
import 'package:packbin/src/crypto/sha256.dart';
import 'package:test/test.dart';

import 'vectors.dart';

// AZ-4141 AC-1 (DT-19): every row of fixtures/crypto/vectors.txt, read as a
// file, through the package's internal crypto.

typedef Outcome = ({String expected, String got});

Outcome _sha256(VectorRow row) {
  final message = row.has('msg')
      ? row.bytes('msg')
      : filled(row.number('repeat'), row.bytes('byte').single);
  return (expected: row.text('digest'), got: toHex(sha256(message)));
}

Outcome _hmac256(VectorRow row) {
  final mac = hmacSha256(row.bytes('key'), row.bytes('data'));
  final keep = row.has('truncate') ? row.number('truncate') : mac.length;
  return (
    expected: row.text('mac'),
    got: toHex(Uint8List.sublistView(mac, 0, keep)),
  );
}

Outcome _hkdf256(VectorRow row) {
  final ikm = row.bytes('ikm');
  final salt = row.bytes('salt');
  final info = row.bytes('info');
  final length = row.number('len');
  final prk = hkdfExtract(salt, ikm);
  final expanded = hkdfExpand(prk, info, length);
  final okm = hkdfSha256(ikm, salt, info, length);
  return (
    expected: 'prk=${row.text('prk')} okm=${row.text('okm')} same',
    got:
        'prk=${toHex(prk)} okm=${toHex(okm)} '
        '${toHex(expanded) == toHex(okm) ? 'same' : 'expand differs'}',
  );
}

Outcome _chachaBlock(VectorRow row) {
  final block = chacha20Block(
    row.bytes('key'),
    row.bytes('nonce'),
    row.number('counter'),
  );
  return (expected: row.text('block'), got: toHex(block));
}

Outcome _chachaXor(VectorRow row) {
  final plain = row.bytes('plain');
  final cipher = chacha20Xor(
    row.bytes('key'),
    row.bytes('nonce'),
    row.number('counter'),
    plain,
  );
  final written = toHex(plain) == row.text('plain') ? '' : ' (plain written)';
  return (expected: row.text('cipher'), got: toHex(cipher) + written);
}

const Map<String, Outcome Function(VectorRow)> _run = {
  'sha256': _sha256,
  'hmac256': _hmac256,
  'hkdf256': _hkdf256,
  'chacha-block': _chachaBlock,
  'chacha-xor': _chachaXor,
};

void main() {
  final text = vectorsFile().readAsStringSync();
  final rows = parseRows(text);

  for (final primitive in primitives) {
    group('$primitive vectors', () {
      final own = rows.where((row) => row.primitive == primitive).toList();

      test('the file has rows of $primitive', () {
        // Assert
        expect(own, isNotEmpty);
      });

      for (final row in own) {
        test('${row.name} matches', () {
          // Act
          final outcome = _run[primitive]!(row);

          // Assert
          expect(outcome.got, outcome.expected);
        });
      }
    });
  }

  group('vector coverage', () {
    test('every data row of the file runs, none is skipped', () {
      // Arrange
      final ran = {for (final primitive in primitives) primitive: 0};
      final unknown = <String>[];
      final failed = <String>[];

      // Act
      for (final row in rows) {
        final run = _run[row.primitive];
        if (run == null) {
          unknown.add(row.name);
          continue;
        }
        final outcome = run(row);
        if (outcome.got != outcome.expected) failed.add(row.name);
        ran[row.primitive] = ran[row.primitive]! + 1;
      }
      final total = ran.values.fold(0, (sum, count) => sum + count);

      // Assert
      expect(unknown, isEmpty, reason: 'rows of a primitive with no runner');
      expect(failed, isEmpty);
      for (final primitive in primitives) {
        expect(ran[primitive], greaterThan(0), reason: '$primitive ran 0 rows');
      }
      expect(total, dataLines(text).length);
      printOnFailure('rows run per primitive: $ran');
    });

    test('row ids are unique per primitive', () {
      // Act
      final names = rows.map((row) => row.name).toSet();

      // Assert
      expect(names.length, rows.length);
    });

    test('a row with one changed digit fails in each primitive', () {
      // Arrange
      const field = {
        'sha256': 'digest',
        'hmac256': 'mac',
        'hkdf256': 'okm',
        'chacha-block': 'block',
        'chacha-xor': 'cipher',
      };

      for (final primitive in primitives) {
        final row = rows.firstWhere((row) => row.primitive == primitive);
        final value = row.text(field[primitive]!);
        final last = value.endsWith('0') ? '1' : '0';
        final changed = VectorRow(row.primitive, row.id, {
          ...row.fields,
          field[primitive]!: value.substring(0, value.length - 1) + last,
        });

        // Act
        final outcome = _run[primitive]!(changed);

        // Assert
        expect(outcome.got, isNot(outcome.expected), reason: row.name);
      }
    });
  });
}
