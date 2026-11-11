import 'dart:typed_data';

import 'package:packbin/src/frame/frame_results.dart';
import 'package:packbin/src/frame/frame_session.dart';
import 'package:packbin/src/frame/frame_types.dart';
import 'package:packbin/src/frame/mac_key.dart';
import 'package:packbin/src/frame/replay_window.dart';
import 'package:test/test.dart';

import 'frame_vectors.dart';

// AZ-4142 AC-2: refusals are result values. A test fails on any exception,
// so every call below also shows that nothing is thrown. Frame bytes come
// from the worked examples of fixtures/frame/vectors.txt.

FrameRefusalKind? kindOf(Object result) =>
    result is FrameRefusal ? result.kind : null;

void main() {
  final rows = loadFixture();
  final e1 = example(rows, 'E1');
  final e3 = example(rows, 'E3');
  final none = Uint8List(0);
  final all = FrameConfig(4, FrameDirections.all);

  group('refusal kinds', () {
    test('every kind has its shared snake_case term', () {
      // Act
      final terms = {for (final k in FrameRefusalKind.values) k.name: k.term};

      // Assert
      expect(terms, {
        'badValue': 'bad_value',
        'tooLong': 'too_long',
        'bufferFull': 'buffer_full',
        'shortPacket': 'short_packet',
        'tagMismatch': 'tag_mismatch',
        'duplicate': 'duplicate',
        'tooOld': 'too_old',
      });
    });
  });

  group('load (AC-2)', () {
    test('a key that is not 32 bytes gives no session and no key', () {
      for (final length in [0, 31, 33, 64]) {
        // Arrange
        final key = Uint8List(length);

        // Act
        final session = FrameSession.load(key, 1, all);
        final mac = MacKey.derive(key, 1, Uint8List(3));

        // Assert
        expect(session, isNull, reason: 'key of $length bytes');
        expect(mac, isNull, reason: 'key of $length bytes');
      }
    });

    test('a tag length other than 4, 8 or 16 gives no session', () {
      for (final tagLength in [0, 5, 32, -4, 1 << 40]) {
        // Act
        final session = FrameSession.load(
          e1.key,
          1,
          FrameConfig(tagLength, FrameDirections.all),
        );

        // Assert
        expect(session, isNull, reason: 'tag length $tagLength');
      }
    });

    test(
      'an epoch outside 0 to 0xFFFFFF and a bad direction set give none',
      () {
        // Act and assert
        for (final epoch in [-1, 0x1000000, 1 << 32, 1 << 62, -(1 << 63)]) {
          expect(FrameSession.load(e1.key, epoch, all), isNull);
          expect(MacKey.derive(e1.key, epoch, Uint8List(3)), isNull);
        }
        for (final bits in [8, -1, (1 << 32) + 1, 1 << 62]) {
          final config = FrameConfig(4, FrameDirections(bits));
          expect(FrameSession.load(e1.key, 1, config), isNull, reason: '$bits');
        }
        for (final bits in [0, 1, 2, 3, 4, 7]) {
          final config = FrameConfig(4, FrameDirections(bits));
          expect(FrameSession.load(e1.key, 1, config), isNotNull);
        }
      },
    );

    test('setPrevious refuses a bad key and a bad epoch', () {
      // Arrange
      final session = e1.session();

      // Act
      final shortKey = session.setPrevious(Uint8List(31), 1);
      final bigEpoch = session.setPrevious(e1.key, 0x1000000);
      final negative = session.setPrevious(e1.key, -1);

      // Assert
      expect([shortKey, bigEpoch, negative], [false, false, false]);
      expect(frameKeyBuffers(session), hasLength(6));
    });
  });

  group('seal (AC-2)', () {
    FrameSealResult seal(
      FrameSession session,
      Uint8List output, {
      FrameDirection? direction,
      MsgContext? message,
      Uint8List? ad,
      Uint8List? clear,
      Uint8List? plain,
    }) => session.seal(
      direction ?? e1.direction,
      message ?? e1.context,
      ad ?? e1.ad,
      clear ?? none,
      plain ?? e1.plain,
      output,
    );

    test('a direction, kind or msg_id out of range is a bad value', () {
      // Arrange
      final session = e1.session();
      final output = filled(300);

      // Act
      final results = [
        for (final number in [0, 4, 255, -1, (1 << 32) + 1, 1 << 62])
          seal(session, output, direction: FrameDirection(number)),
        for (final kind in [16, -1, 1 << 40])
          seal(session, output, message: MsgContext(e1.msgId, kind)),
        for (final length in [0, 7, 9])
          seal(session, output, message: MsgContext(Uint8List(length), 1)),
      ];

      // Assert
      expect(results.map(kindOf).toSet(), {FrameRefusalKind.badValue});
      expect(untouched(output), isTrue);
    });

    test('a direction that is not loaded is a bad value', () {
      // Arrange
      final up = FrameSession.load(
        e1.key,
        1,
        FrameConfig(4, FrameDirections.up),
      )!;
      final empty = FrameSession.load(
        e1.key,
        1,
        FrameConfig(4, FrameDirections.none),
      )!;
      final output = filled(300);

      // Act
      final unloaded = seal(up, output, direction: FrameDirection.down);
      final nothing = seal(empty, output, direction: FrameDirection.up);

      // Assert
      expect(kindOf(unloaded), FrameRefusalKind.badValue);
      expect(kindOf(nothing), FrameRefusalKind.badValue);
      expect(untouched(output), isTrue);
    });

    test('a text over the bound and associated data over 255 are too long', () {
      // Arrange
      final session = e1.session();
      final output = filled(600);

      // Act
      final body256 = seal(session, output, plain: Uint8List(252));
      final body255 = seal(session, Uint8List(300), plain: Uint8List(251));
      final ad256 = seal(session, output, ad: Uint8List(256));
      final withClear = seal(
        session,
        output,
        clear: Uint8List(200),
        plain: Uint8List(52),
      );

      // Assert
      expect(kindOf(body256), FrameRefusalKind.tooLong);
      expect((body256 as FrameRefusal).length, 256);
      expect(body255, isA<FrameSealed>());
      expect(kindOf(ad256), FrameRefusalKind.tooLong);
      expect(kindOf(withClear), FrameRefusalKind.tooLong);
      expect(untouched(output), isTrue);
    });

    test('an output one byte short is buffer full and nothing is written', () {
      // Arrange
      final session = e1.session();
      final output = filled(e1.body.length - 1);

      // Act
      final result = seal(session, output);

      // Assert
      expect(kindOf(result), FrameRefusalKind.bufferFull);
      expect((result as FrameRefusal).needed, e1.body.length);
      expect(untouched(output), isTrue);
    });

    test('an output that cannot be written is a bad value, not an error', () {
      // Arrange
      final session = e1.session();
      final output = filled(64).asUnmodifiableView();

      // Act
      final result = seal(session, output);

      // Assert
      expect(kindOf(result), FrameRefusalKind.badValue);
      expect(untouched(output), isTrue);
    });
  });

  group('open (AC-2)', () {
    test('a forged tag is a tag mismatch and the output holds no text', () {
      for (final at in [0, e1.body.length - e1.tagLength, e1.body.length - 1]) {
        // Arrange
        final session = e1.session();
        final forged = Uint8List.fromList(e1.body);
        forged[at] ^= 1;
        final output = filled(300);

        // Act
        final result = e1.open(session, forged, output);

        // Assert
        expect(
          kindOf(result),
          FrameRefusalKind.tagMismatch,
          reason: 'byte $at',
        );
        expect(untouched(output), isTrue, reason: 'byte $at');
      }
    });

    test('the unforged frame opens to the text of the vector', () {
      // Arrange
      final session = e1.session();
      final output = filled(300);

      // Act
      final result = e1.open(session, e1.body, output);

      // Assert
      expect(result, isA<FrameOpened>());
      final opened = result as FrameOpened;
      expect(opened.slot, FrameSlot.current);
      expect(opened.clearLength, e1.clearLength);
      expect(
        hex(Uint8List.sublistView(output, 0, opened.plainLength)),
        hex(e1.plain),
      );
    });

    test('lengths over 255 are too long before any hashing', () {
      // Arrange
      final session = e1.session();
      final output = filled(600);

      // Act
      final ad256 = session.open(
        e1.direction,
        e1.context,
        Uint8List(256),
        e1.body,
        0,
        output,
      );
      final body256 = e1.open(session, Uint8List(256), output);
      final clear256 = session.open(
        e1.direction,
        e1.context,
        e1.ad,
        e1.body,
        256,
        output,
      );
      final clearHuge = session.open(
        e1.direction,
        e1.context,
        e1.ad,
        e1.body,
        (1 << 63) - 1,
        output,
      );

      // Assert
      expect([ad256, body256, clear256, clearHuge].map(kindOf).toSet(), {
        FrameRefusalKind.tooLong,
      });
      expect(frameMacComputations(session), 0);
      expect(untouched(output), isTrue);
    });

    test('a negative clear length and a bad counter are bad values', () {
      // Arrange
      final session = e1.session();
      final output = filled(300);
      final window = ReplayWindow();

      // Act
      final results = [
        for (final clearLength in [-1, -(1 << 63)])
          session.open(
            e1.direction,
            e1.context,
            e1.ad,
            e1.body,
            clearLength,
            output,
          ),
        for (final counter in [-BigInt.one, BigInt.one << 64])
          e1.open(session, e1.body, output, window: window, counter: counter),
        e1.open(
          FrameSession.load(
            e1.key,
            e1.epoch,
            FrameConfig(4, FrameDirections.group),
          )!,
          e1.body,
          output,
        ),
      ];

      // Assert
      expect(results.map(kindOf).toSet(), {FrameRefusalKind.badValue});
      expect(untouched(output), isTrue);
      expect(windowText(window), '0:0');
    });

    test('a body shorter than its clear part and tag is a short packet', () {
      // Arrange
      final session = e3.session();
      final output = filled(300);
      final body = Uint8List.sublistView(e3.body, 0, e3.clearLength + 3);

      // Act
      final result = e3.open(session, body, output);

      // Assert
      expect(kindOf(result), FrameRefusalKind.shortPacket);
      expect((result as FrameRefusal).needed, e3.clearLength + e3.tagLength);
      expect(result.length, body.length);
      expect(untouched(output), isTrue);
    });

    test('an output one byte short is buffer full and nothing is written', () {
      // Arrange
      final session = e1.session();
      final output = filled(e1.plain.length - 1);

      // Act
      final result = e1.open(session, e1.body, output);

      // Assert
      expect(kindOf(result), FrameRefusalKind.bufferFull);
      expect((result as FrameRefusal).needed, e1.plain.length);
      expect(untouched(output), isTrue);
    });

    test(
      'an output that cannot be written is a bad value, window unchanged',
      () {
        // Arrange
        final session = e1.session();
        final output = filled(64).asUnmodifiableView();
        final window = ReplayWindow();

        // Act
        final result = e1.open(
          session,
          e1.body,
          output,
          window: window,
          counter: BigInt.from(5),
        );

        // Assert
        expect(kindOf(result), FrameRefusalKind.badValue);
        expect(untouched(output), isTrue);
        expect(windowText(window), '0:0');
      },
    );

    test('every prefix and every one-byte change of a frame is a value', () {
      // Arrange
      final session = e3.session();
      final kinds = <FrameRefusalKind?>{};

      // Act
      for (var length = 0; length < e3.body.length; length++) {
        final cut = Uint8List.sublistView(e3.body, 0, length);
        kinds.add(kindOf(e3.open(session, cut, Uint8List(300))));
      }
      for (var at = 0; at < e3.body.length; at++) {
        final changed = Uint8List.fromList(e3.body);
        changed[at] ^= 0x80;
        kinds.add(kindOf(e3.open(session, changed, Uint8List(300))));
      }

      // Assert
      expect(kinds, {
        FrameRefusalKind.shortPacket,
        FrameRefusalKind.tagMismatch,
      });
    });
  });

  group('MAC-only call (AC-2)', () {
    test('a tag length that is not allowed is a bad value', () {
      // Arrange
      final mac = MacKey.derive(e1.key, 1, Uint8List.fromList([1]))!;

      // Act
      final results = [
        for (final n in [0, 2, 5, 33, -8, 1 << 40]) mac.tag([e1.plain], n),
      ];

      // Assert
      expect(results.map(kindOf).toSet(), {FrameRefusalKind.badValue});
    });

    test('a label of 0 or 33 bytes gives no key', () {
      // Act
      final empty = MacKey.derive(e1.key, 1, none);
      final long = MacKey.derive(e1.key, 1, Uint8List(33));
      final longest = MacKey.derive(e1.key, 1, Uint8List(32));

      // Assert
      expect(empty, isNull);
      expect(long, isNull);
      expect(longest, isNotNull);
    });

    test('verify is false for a tag of a length that is not allowed', () {
      // Arrange
      final mac = MacKey.derive(e1.key, 1, Uint8List.fromList([1]))!;
      final full = (mac.tag([e1.plain], 32) as MacTag).tag;

      // Act
      final results = {
        for (final n in [0, 3, 5, 31])
          n: mac.verify([e1.plain], Uint8List.sublistView(full, 0, n)),
      };
      final longer = mac.verify([e1.plain], Uint8List(33));

      // Assert
      expect(results.values.toSet(), {false});
      expect(longer, isFalse);
      expect(mac.verify([e1.plain], full), isTrue);
    });
  });
}
