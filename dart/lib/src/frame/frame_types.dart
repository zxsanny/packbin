import 'dart:typed_data';

/// The direction of a frame: the nonce and the keys depend on it.
///
/// The wire number is 1 (up), 2 (down) or 3 (group). A value built from any
/// other number is refused by seal and open as a bad value.
extension type const FrameDirection(int number) {
  /// Wire number 1.
  static const FrameDirection up = FrameDirection(1);

  /// Wire number 2.
  static const FrameDirection down = FrameDirection(2);

  /// Wire number 3.
  static const FrameDirection group = FrameDirection(3);
}

/// The directions a frame session loads keys for, joined with `|`, for
/// example `FrameDirections.up | FrameDirections.down`.
///
/// A value with a bit outside [all] makes load fail.
extension type const FrameDirections(int bits) {
  /// No direction.
  static const FrameDirections none = FrameDirections(0);

  /// The up direction.
  static const FrameDirections up = FrameDirections(1);

  /// The down direction.
  static const FrameDirections down = FrameDirections(2);

  /// The group direction.
  static const FrameDirections group = FrameDirections(4);

  /// Up, down and group.
  static const FrameDirections all = FrameDirections(7);

  /// The directions of both sets.
  FrameDirections operator |(FrameDirections other) =>
      FrameDirections(bits | other.bits);

  /// True when the set is valid and holds [direction].
  bool contains(FrameDirection direction) {
    final number = direction.number;
    if (bits < 0 || bits > 7 || number < 1 || number > 3) return false;
    return bits & (1 << (number - 1)) != 0;
  }
}

/// Which loaded key opened a frame.
enum FrameSlot {
  /// The current key opened the frame.
  current,

  /// The previous key opened the frame.
  previous,
}

/// What a replay window says about a counter.
enum Freshness {
  /// The counter is newer than every one seen, or unseen inside the window.
  fresh,

  /// The counter was already committed.
  duplicate,

  /// The counter is older than the window.
  tooOld,
}

/// What a frame session is loaded with besides the key. A [tagLength] other
/// than 4, 8 or 16 makes load fail.
final class FrameConfig {
  /// A configuration with a [tagLength] and the [directions] to load.
  const FrameConfig(this.tagLength, this.directions);

  /// The bytes of the tag at the end of every frame body: 4, 8 or 16.
  final int tagLength;

  /// The directions the session loads keys for.
  final FrameDirections directions;
}

/// What the caller supplies per message: the 8-byte `msg_id` and the 4-bit
/// [kind] (0 to 15).
///
/// **For one (key, epoch, direction), a `msg_id` is never sealed twice with
/// different contents.** Reuse breaks the confidentiality of both messages,
/// and packbin cannot check it. A new epoch derives new keys and nonces.
///
/// The id is copied at construction. A value built from bytes that are not 8
/// long, or with a [kind] outside 0 to 15, is refused by seal and open as a
/// bad value.
final class MsgContext {
  /// A context with the 8-byte [msgId] (copied) and the [kind] (0 to 15).
  MsgContext(Uint8List msgId, this.kind)
    : _id = msgId.length == idSize ? Uint8List.fromList(msgId) : null;

  /// The length of a `msg_id` in bytes.
  static const int idSize = 8;

  final Uint8List? _id;

  /// The 4-bit kind, 0 to 15.
  final int kind;
}

/// The id bytes of a context, or null when it was built from an id that is
/// not 8 bytes. Internal: not exported from the package.
Uint8List? msgIdOf(MsgContext message) => message._id;
