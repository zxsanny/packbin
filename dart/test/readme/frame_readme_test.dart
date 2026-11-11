import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

// AZ-4148: the frame-mode example of the README. The lines between the
// markers are copied into the README (scripts/frame/readme-examples.sh
// compares them); this test runs them and checks what they print. The imports
// above are the README block's `import` lines.
void main() {
  void example() {
    // README-BEGIN
    String hex(List<int> b) =>
        b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

    // Load once: the keys of each direction are derived here. One tag length (4, 8 or 16) per key.
    final key = Uint8List.fromList(List.filled(32, 0x11)); // use a random key
    final node = FrameSession.load(
      key,
      1,
      FrameConfig(4, FrameDirections.up | FrameDirections.down),
    )!;

    // A message id that is never sealed twice with other contents under one (key, epoch, direction).
    final id = Uint8List.fromList([0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0]);
    final message = MsgContext(id, 4);
    final ad = Uint8List.fromList([0, 1, ...id, 4]); // authenticated, not sent

    // Seal into your own buffer: clear part, then ciphertext, then the 4-byte tag.
    final body = Uint8List(255);
    final text = Uint8List.fromList(utf8.encode('hello, relay'));
    final sealed = node.seal(
      FrameDirection.up,
      message,
      ad,
      Uint8List(0),
      text,
      body,
    );
    if (sealed is! FrameSealed) throw StateError('seal refused: $sealed');
    final frame = Uint8List.sublistView(body, 0, sealed.length); // 12 + 4 bytes
    print(hex(frame));

    // Open with the sender's replay window. The counter must come from bytes the tag covers.
    final window = ReplayWindow();
    final plain = Uint8List(255);
    final opened = node.open(
      FrameDirection.up,
      message,
      ad,
      frame,
      0,
      plain,
      window: window,
      counter: BigInt.from(7),
    );
    if (opened is! FrameOpened) throw StateError('open refused: $opened');
    print(
      '${opened.slot} ${utf8.decode(plain.sublist(0, opened.plainLength))}',
    );

    // The same frame again is refused before any MAC is computed.
    final again = node.open(
      FrameDirection.up,
      message,
      ad,
      frame,
      0,
      plain,
      window: window,
      counter: BigInt.from(7),
    );
    print(again is FrameRefusal ? again.kind : 'opened');

    // The MAC-only call: a 4-byte network check over a message given in parts.
    final netKey = Uint8List.fromList(List.filled(32, 0x22));
    final network = MacKey.derive(
      netKey,
      7,
      Uint8List.fromList(utf8.encode('net')),
    )!;
    final wave = Uint8List.fromList([0xe8, 3, 0, 0]);
    final data = Uint8List.fromList([for (var i = 0xc0; i <= 0xd3; i++) i]);
    final made = network.tag([wave, data], 4);
    if (made is! MacTag) throw StateError('tag refused: $made');
    print('${hex(made.tag)} ${network.verify([wave, data], made.tag)}');

    // Close both when done: the derived keys are overwritten (best effort).
    node.close();
    network.close();
    // README-END
  }

  test('the README frame example seals, opens, refuses the replay, tags', () {
    // Arrange
    final printed = <String>[];
    final capture = ZoneSpecification(
      print: (self, parent, zone, line) => printed.add(line),
    );

    // Act
    runZoned(example, zoneSpecification: capture);

    // Assert
    expect(printed, [
      '3a8eb31d916fba0d32046f13b8d29e40',
      'FrameSlot.current hello, relay',
      'FrameRefusalKind.duplicate',
      '56db9bec true',
    ]);
  });
}
