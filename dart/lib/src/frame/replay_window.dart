import 'frame_types.dart';

final BigInt _mask = (BigInt.one << 64) - BigInt.one;
final BigInt _size = BigInt.from(64);

BigInt _checked(String name, BigInt value) {
  if (!ReplayWindow.isCounter(value)) {
    throw RangeError('$name: expected a value from 0 to 2^64 - 1, got $value');
  }
  return value;
}

/// The replay window of frame mode: the highest counter a sender's frames
/// reached ([top]) and which of the 64 counters up to it were committed
/// ([bits]: bit i set means counter `top - i` was committed; 0 is an empty
/// window). The caller owns one per sender and passes it, with the message's
/// counter, to `FrameSession.open`.
///
/// Both numbers are unsigned 64-bit on the wire. A Dart `int` is signed and
/// wraps, so they are [BigInt] here and counters up to 2^64 - 1 are exact.
/// The constructor, [check] and [commit] throw a [RangeError] for a value
/// outside 0 to 2^64 - 1; `FrameSession.open` checks the counter first and
/// refuses it as a bad value, so it never throws.
///
/// The counter must come from bytes the tag covers (for example the `msg_id`
/// or the associated data), never from an unauthenticated field of the wire:
/// it is an argument of open and not part of the tag.
final class ReplayWindow {
  /// A window restored from stored state, or an empty one. `bits` 0 is empty
  /// whatever `top` is: a caller validates stored state (bit 0 set when the
  /// bits are not 0).
  ReplayWindow([BigInt? top, BigInt? bits])
    : _top = _checked('top', top ?? BigInt.zero),
      _bits = _checked('bits', bits ?? BigInt.zero);

  /// The number of counters a window remembers.
  static const int size = 64;

  BigInt _top;
  BigInt _bits;

  /// The highest committed counter.
  BigInt get top => _top;

  /// The committed counters as bits: bit i is counter `top - i`.
  BigInt get bits => _bits;

  /// True for a counter a window accepts: 0 to 2^64 - 1.
  static bool isCounter(BigInt value) => !value.isNegative && value <= _mask;

  /// What the window says about [counter]. Never changes the state.
  Freshness check(BigInt counter) {
    final n = _checked('counter', counter);
    if (_bits == BigInt.zero || n > _top) return Freshness.fresh;
    final behind = _top - n;
    if (behind >= _size) return Freshness.tooOld;
    return (_bits >> behind.toInt()).isOdd
        ? Freshness.duplicate
        : Freshness.fresh;
  }

  /// Records [counter]. Open calls this only after a frame opened; a counter
  /// 64 or more behind the highest is ignored.
  void commit(BigInt counter) {
    final n = _checked('counter', counter);
    if (_bits == BigInt.zero) {
      _top = n;
      _bits = BigInt.one;
    } else if (n > _top) {
      final shift = n - _top;
      final moved = shift >= _size ? BigInt.zero : _bits << shift.toInt();
      _bits = (moved & _mask) | BigInt.one;
      _top = n;
    } else {
      final behind = _top - n;
      if (behind < _size) _bits |= BigInt.one << behind.toInt();
    }
  }
}
