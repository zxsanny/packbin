import 'dart:typed_data';

import 'package:packbin/src/frame/frame_crypto.dart';
import 'package:packbin/src/frame/frame_results.dart';
import 'package:packbin/src/frame/frame_session.dart';
import 'package:packbin/src/frame/mac_key.dart';
import 'package:test/test.dart';

import 'frame_vectors.dart';

// AZ-4142 AC-4 (the tag compare reads every byte) and the risk "buffers that
// alias" (the TypeScript rule: seal builds the body apart and copies it last;
// open copies the frame before hashing). Bytes come from the shared vectors.

void main() {
  final rows = loadFixture();

  group('tag compare (AC-4)', () {
    late List<int> reads;

    setUp(() {
      reads = [];
      tagCompareProbe = reads.add;
    });

    tearDown(() {
      tagCompareProbe = null;
    });

    test(
      'equal, first-byte, last-byte and length differences are told apart',
      () {
        // Arrange
        final tag = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final first = Uint8List.fromList(tag)..[0] ^= 0x80;
        final last = Uint8List.fromList(tag)..[7] ^= 1;

        // Act
        final results = [
          tagsEqual(tag, Uint8List.fromList(tag)),
          tagsEqual(tag, first),
          tagsEqual(tag, last),
          tagsEqual(tag, Uint8List.sublistView(tag, 0, 7)),
          tagsEqual(Uint8List(0), Uint8List(0)),
        ];

        // Assert
        expect(results, [true, false, false, false, true]);
        expect(reads, [
          for (var n = 0; n < 3; n++) ...List.generate(8, (i) => i),
        ]);
      },
    );

    for (final n in [4, 8, 16, 32]) {
      test(
        'MacKey.verify reads all $n bytes of a tag wrong in byte 0 or last',
        () {
          // Arrange
          final row = rowOf(rows, 'mac.verify_ok');
          final mac = MacKey.derive(
            bytes(row, 'key'),
            number(row, 'epoch'),
            bytes(row, 'label'),
          )!;
          final message = [bytes(row, 'message')];
          final good = (mac.tag(message, n) as MacTag).tag;
          final wrongFirst = Uint8List.fromList(good)..[0] ^= 1;
          final wrongLast = Uint8List.fromList(good)..[n - 1] ^= 1;
          final every = List.generate(n, (i) => i);

          // Act
          final first = mac.verify(message, wrongFirst);
          final readsFirst = List.of(reads);
          reads.clear();
          final last = mac.verify(message, wrongLast);
          final readsLast = List.of(reads);
          reads.clear();
          final valid = mac.verify(message, good);

          // Assert
          expect(hex(Uint8List.sublistView(good, 0, 4)), row['verify']);
          expect(first, isFalse);
          expect(last, isFalse);
          expect(readsFirst, every);
          expect(readsLast, every);
          expect(valid, isTrue);
          expect(reads, every);
        },
      );
    }

    for (final name in ['E1', 'E3.open16']) {
      test(
        'open of $name reads every tag byte of a tag wrong in byte 0 or last',
        () {
          // Arrange
          final e = name == 'E1'
              ? example(rows, 'E1')
              : Example(rowOf(rows, name));
          final session = e.session();
          final tagAt = e.body.length - e.tagLength;
          final wrongFirst = Uint8List.fromList(e.body)..[tagAt] ^= 1;
          final wrongLast = Uint8List.fromList(e.body)
            ..[e.body.length - 1] ^= 1;
          final every = List.generate(e.tagLength, (i) => i);
          final output = filled(300);

          // Act
          final first = e.open(session, wrongFirst, output);
          final readsFirst = List.of(reads);
          reads.clear();
          final last = e.open(session, wrongLast, output);
          final readsLast = List.of(reads);

          // Assert
          expect((first as FrameRefusal).kind, FrameRefusalKind.tagMismatch);
          expect((last as FrameRefusal).kind, FrameRefusalKind.tagMismatch);
          expect(readsFirst, every);
          expect(readsLast, every);
          expect(untouched(output), isTrue);
        },
      );
    }

    test('with a previous key a forged tag is compared in full twice', () {
      // Arrange
      final e = example(rows, 'E1');
      final session = e.session();
      session.setPrevious(Uint8List(32), 3);
      final forged = Uint8List.fromList(e.body)
        ..[e.body.length - e.tagLength] ^= 1;

      // Act
      final result = e.open(session, forged, Uint8List(300));

      // Assert
      expect((result as FrameRefusal).kind, FrameRefusalKind.tagMismatch);
      expect(reads, [0, 1, 2, 3, 0, 1, 2, 3]);
      expect(frameMacComputations(session), 2);
    });
  });

  group('buffers that alias', () {
    const layouts = [
      'plain in place',
      'plain at start',
      'clear and plain in place',
      'ad inside',
    ];

    for (final name in ['E1.seal', 'E3.seal']) {
      for (final layout in layouts) {
        test('$name seals to the vector body with "$layout" in the output', () {
          // Arrange
          final row = rowOf(rows, name);
          final session = loadSession(row)!;
          final ad = bytes(row, 'ad');
          final clear = bytes(row, 'clear');
          final plain = bytes(row, 'plain');
          final body = bytes(row, 'body');
          final output = filled(300);
          Uint8List inside(Uint8List value, int at) {
            output.setRange(at, at + value.length, value);
            return Uint8List.sublistView(output, at, at + value.length);
          }

          final adInput = layout == 'ad inside' ? inside(ad, 3) : ad;
          final clearInput = layout == 'clear and plain in place'
              ? inside(clear, 0)
              : clear;
          final plainInput = switch (layout) {
            'plain in place' ||
            'clear and plain in place' => inside(plain, clear.length),
            'plain at start' => inside(plain, 0),
            _ => plain,
          };
          final before = hex(output);
          final short = Uint8List.sublistView(output, 0, body.length - 1);

          // Act
          final refused = session.seal(
            directionOf(row),
            contextOf(row),
            adInput,
            clearInput,
            plainInput,
            short,
          );
          final unchanged = hex(output) == before;
          final sealed = session.seal(
            directionOf(row),
            contextOf(row),
            adInput,
            clearInput,
            plainInput,
            output,
          );

          // Assert
          expect((refused as FrameRefusal).kind, FrameRefusalKind.bufferFull);
          expect(unchanged, isTrue);
          expect(sealed, isA<FrameSealed>());
          final length = (sealed as FrameSealed).length;
          expect(length, body.length);
          expect(hex(Uint8List.sublistView(output, 0, length)), hex(body));
          expect(untouched(Uint8List.sublistView(output, length)), isTrue);
        });
      }
    }

    for (final name in ['E1', 'E3']) {
      for (final atClear in [false, true]) {
        final where = atClear ? 'after the clear part' : 'at the start';
        test(
          '$name opens to the vector text with the output $where of the body',
          () {
            // Arrange
            final e = example(rows, name);
            final session = e.session();
            final at = atClear ? e.clearLength : 0;
            final buffer = Uint8List(300);
            buffer.setRange(0, e.body.length, e.body);
            final body = Uint8List.sublistView(buffer, 0, e.body.length);
            final output = Uint8List.sublistView(buffer, at);

            // Act
            final opened = e.open(session, body, output);

            // Assert
            expect(opened, isA<FrameOpened>());
            final length = (opened as FrameOpened).plainLength;
            expect(
              hex(Uint8List.sublistView(buffer, at, at + length)),
              hex(e.plain),
            );
          },
        );
      }
    }

    test('a forged frame opened in place leaves the buffer as it was', () {
      // Arrange
      final e = example(rows, 'E3');
      final session = e.session();
      final buffer = Uint8List(300);
      buffer.setRange(0, e.body.length, e.body);
      buffer[e.body.length - 1] ^= 1;
      final before = hex(buffer);

      // Act
      final result = e.open(
        session,
        Uint8List.sublistView(buffer, 0, e.body.length),
        Uint8List.sublistView(buffer, e.clearLength),
      );

      // Assert
      expect((result as FrameRefusal).kind, FrameRefusalKind.tagMismatch);
      expect(hex(buffer), before);
    });
  });
}
