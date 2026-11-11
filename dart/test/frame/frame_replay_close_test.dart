import 'dart:typed_data';

import 'package:packbin/src/frame/frame_results.dart';
import 'package:packbin/src/frame/frame_session.dart';
import 'package:packbin/src/frame/frame_types.dart';
import 'package:packbin/src/frame/mac_key.dart';
import 'package:packbin/src/frame/replay_window.dart';
import 'package:test/test.dart';

import 'frame_vectors.dart';

// AZ-4142 AC-3 (replay and close) and AC-5 (previous key). Frame bytes come
// from fixtures/frame/vectors.txt: E1 and the `prev.` rows.

FrameRefusalKind? kindOf(Object result) =>
    result is FrameRefusal ? result.kind : null;

bool allZero(Iterable<Uint8List> buffers) =>
    buffers.every((buffer) => buffer.every((b) => b == 0));

bool someNonZero(Iterable<Uint8List> buffers) =>
    buffers.every((buffer) => buffer.any((b) => b != 0));

void main() {
  final rows = loadFixture();
  final e1 = example(rows, 'E1');
  final none = Uint8List(0);

  group('replay (AC-3)', () {
    test('an opened frame presented again is a duplicate, no MAC computed', () {
      // Arrange
      final session = e1.session();
      final window = ReplayWindow();
      final counter = BigInt.from(100);
      final first = e1.open(
        session,
        e1.body,
        Uint8List(300),
        window: window,
        counter: counter,
      );
      final macsBefore = frameMacComputations(session);
      final stateBefore = windowText(window);
      final output = filled(300);

      // Act
      final second = e1.open(
        session,
        e1.body,
        output,
        window: window,
        counter: counter,
      );

      // Assert
      expect(first, isA<FrameOpened>());
      expect(kindOf(second), FrameRefusalKind.duplicate);
      expect(frameMacComputations(session), macsBefore);
      expect(untouched(output), isTrue);
      expect(windowText(window), stateBefore);
      expect(stateBefore, '64:1');
    });

    test(
      'a frame 64 or more behind the window is too old, no MAC computed',
      () {
        // Arrange
        final session = e1.session();
        final window = ReplayWindow(BigInt.from(100), BigInt.one);
        final output = filled(300);

        // Act
        final atTheEdge = e1.open(
          session,
          e1.body,
          output,
          window: window,
          counter: BigInt.from(36),
        );
        final wayOld = e1.open(
          session,
          e1.body,
          output,
          window: window,
          counter: BigInt.zero,
        );
        final inside = e1.open(
          session,
          e1.body,
          Uint8List(300),
          window: window,
          counter: BigInt.from(37),
        );

        // Assert
        expect(kindOf(atTheEdge), FrameRefusalKind.tooOld);
        expect(kindOf(wayOld), FrameRefusalKind.tooOld);
        expect(untouched(output), isTrue);
        expect(inside, isA<FrameOpened>());
        expect(frameMacComputations(session), 1);
        expect(windowText(window), '64:8000000000000001');
      },
    );

    test('a forged frame computes one MAC and leaves the window as it was', () {
      // Arrange
      final session = e1.session();
      final window = ReplayWindow(BigInt.from(100), BigInt.one);
      final forged = Uint8List.fromList(e1.body);
      forged[forged.length - 1] ^= 1;
      final output = filled(300);

      // Act
      final result = e1.open(
        session,
        forged,
        output,
        window: window,
        counter: BigInt.from(101),
      );

      // Assert
      expect(kindOf(result), FrameRefusalKind.tagMismatch);
      expect(frameMacComputations(session), 1);
      expect(untouched(output), isTrue);
      expect(windowText(window), '64:1');
    });

    test('a window with no counter uses counter 0', () {
      // Arrange
      final session = e1.session();
      final window = ReplayWindow();

      // Act
      final first = e1.open(session, e1.body, Uint8List(300), window: window);
      final second = e1.open(session, e1.body, Uint8List(300), window: window);

      // Assert
      expect(first, isA<FrameOpened>());
      expect(kindOf(second), FrameRefusalKind.duplicate);
      expect(windowText(window), '0:1');
    });
  });

  group('close (AC-3)', () {
    test('a closed session has zeroed key buffers and refuses every call', () {
      // Arrange
      final session = FrameSession.load(
        e1.key,
        e1.epoch,
        FrameConfig(4, FrameDirections.all),
      )!;
      final previousSet = session.setPrevious(
        Uint8List(32)..fillRange(0, 32, 0x42),
        9,
      );
      final buffers = frameKeyBuffers(session);
      final nonZeroBefore = someNonZero(buffers);
      final output = filled(300);

      // Act
      session.close();
      final sealed = session.seal(
        e1.direction,
        e1.context,
        e1.ad,
        none,
        e1.plain,
        output,
      );
      final opened = e1.open(session, e1.body, output);
      final previous = session.setPrevious(e1.key, 1);
      session.close();
      session.clearPrevious();

      // Assert
      expect(previousSet, isTrue);
      expect(buffers, hasLength(12));
      expect(buffers.map((b) => b.length).toSet(), {32});
      expect(nonZeroBefore, isTrue);
      expect(allZero(buffers), isTrue);
      expect(kindOf(sealed), FrameRefusalKind.badValue);
      expect(kindOf(opened), FrameRefusalKind.badValue);
      expect(untouched(output), isTrue);
      expect(previous, isFalse);
      expect(session.isClosed, isTrue);
    });

    test('a closed MAC key has a zeroed key buffer and refuses every call', () {
      // Arrange
      final row = rowOf(rows, 'mac.verify_ok');
      final mac = MacKey.derive(
        bytes(row, 'key'),
        number(row, 'epoch'),
        bytes(row, 'label'),
      )!;
      final message = [bytes(row, 'message')];
      final good = bytes(row, 'verify');
      final key = macKeyBytes(mac);
      final validBefore = mac.verify(message, good);
      final nonZeroBefore = key.any((b) => b != 0);

      // Act
      mac.close();
      final tag = mac.tag(message, 4);
      final valid = mac.verify(message, good);
      mac.close();

      // Assert
      expect(validBefore, isTrue);
      expect(nonZeroBefore, isTrue);
      expect(key, hasLength(32));
      expect(key.every((b) => b == 0), isTrue);
      expect(kindOf(tag), FrameRefusalKind.badValue);
      expect(valid, isFalse);
      expect(mac.isClosed, isTrue);
    });

    test('the caller\'s key is read and not kept or changed', () {
      // Arrange
      final key = Uint8List.fromList(e1.key);

      // Act
      final session = FrameSession.load(
        key,
        1,
        FrameConfig(4, FrameDirections.all),
      )!;
      final shared = frameKeyBuffers(session)
          .any((b) => identical(b.buffer, key.buffer));
      session.close();

      // Assert
      expect(shared, isFalse);
      expect(hex(key), hex(e1.key));
    });
  });

  group('previous key (AC-5)', () {
    final row = rowOf(rows, 'prev.ok_previous');
    final currentRow = rowOf(rows, 'prev.ok_current');
    FrameSession load() => loadSession(row)!;
    FrameOpenResult open(
      FrameSession session,
      Map<String, String> from,
      Uint8List output,
    ) => session.open(
      directionOf(from),
      contextOf(from),
      bytes(from, 'ad'),
      bytes(from, 'body'),
      number(from, 'clear_len'),
      output,
    );

    test('a frame sealed with the previous key opens with slot previous', () {
      // Arrange
      final session = load();
      final set = session.setPrevious(
        bytes(row, 'prev_key'),
        number(row, 'prev_epoch'),
      );
      final output = filled(300);

      // Act
      final result = open(session, row, output);

      // Assert
      expect(set, isTrue);
      expect(result, isA<FrameOpened>());
      final opened = result as FrameOpened;
      expect(opened.slot, FrameSlot.previous);
      expect(
        hex(Uint8List.sublistView(output, 0, opened.plainLength)),
        row['plain'],
      );
      expect(frameMacComputations(session), 2);
    });

    test('the same frame is refused after the previous key is cleared', () {
      // Arrange
      final session = load();
      session.setPrevious(bytes(row, 'prev_key'), number(row, 'prev_epoch'));
      final old = frameKeyBuffers(session).sublist(6);
      final nonZeroBefore = someNonZero(old);
      final output = filled(300);

      // Act
      session.clearPrevious();
      final result = open(session, row, output);

      // Assert
      expect(old, hasLength(6));
      expect(nonZeroBefore, isTrue);
      expect(allZero(old), isTrue);
      expect(kindOf(result), FrameRefusalKind.tagMismatch);
      expect(untouched(output), isTrue);
      expect(frameKeyBuffers(session), hasLength(6));
    });

    test('with no previous key the frame is refused', () {
      // Arrange
      final session = load();
      final output = filled(300);

      // Act
      final result = open(session, row, output);

      // Assert
      expect(kindOf(result), FrameRefusalKind.tagMismatch);
      expect(untouched(output), isTrue);
    });

    test('a frame of the current key still opens with slot current', () {
      // Arrange
      final session = load();
      session.setPrevious(bytes(row, 'prev_key'), number(row, 'prev_epoch'));
      final output = filled(300);

      // Act
      final result = open(session, currentRow, output);

      // Assert
      expect(result, isA<FrameOpened>());
      expect((result as FrameOpened).slot, FrameSlot.current);
      expect(
        hex(Uint8List.sublistView(output, 0, result.plainLength)),
        currentRow['plain'],
      );
      expect(frameMacComputations(session), 1);
    });

    test('replacing the previous key zeroes the old one', () {
      // Arrange
      final session = load();
      session.setPrevious(bytes(row, 'prev_key'), number(row, 'prev_epoch'));
      final old = frameKeyBuffers(session).sublist(6);

      // Act
      final replaced = session.setPrevious(e1.key, 2);
      final output = filled(300);
      final result = open(session, row, output);

      // Assert
      expect(replaced, isTrue);
      expect(allZero(old), isTrue);
      expect(someNonZero(frameKeyBuffers(session).sublist(6)), isTrue);
      expect(kindOf(result), FrameRefusalKind.tagMismatch);
    });

    test('seal never uses the previous key', () {
      // Arrange
      final sealRow = rowOf(rows, 'E1.seal');
      final session = loadSession(sealRow)!;
      session.setPrevious(bytes(row, 'prev_key'), number(row, 'prev_epoch'));
      final output = filled(300);

      // Act
      final result = session.seal(
        directionOf(sealRow),
        contextOf(sealRow),
        bytes(sealRow, 'ad'),
        bytes(sealRow, 'clear'),
        bytes(sealRow, 'plain'),
        output,
      );

      // Assert
      expect(result, isA<FrameSealed>());
      expect(
        hex(Uint8List.sublistView(output, 0, (result as FrameSealed).length)),
        sealRow['body'],
      );
    });
  });
}
