import 'dart:typed_data';

import 'frame_types.dart';

/// Why a frame call was refused. [term] is the name shared by every packbin
/// package.
enum FrameRefusalKind {
  /// A configuration or argument is out of range: a direction that is not
  /// loaded, a kind above 15, a `msg_id` that is not 8 bytes, a tag length
  /// that is not allowed, an output that cannot be written, a closed session.
  badValue('bad_value'),

  /// The associated data, the body or the clear part is above 255 bytes.
  tooLong('too_long'),

  /// The caller's output buffer is shorter than the bytes the call writes.
  bufferFull('buffer_full'),

  /// The body is shorter than its clear part and its tag.
  shortPacket('short_packet'),

  /// The tag matches neither the current nor the previous key. Nothing was
  /// decrypted.
  tagMismatch('tag_mismatch'),

  /// The replay window has already committed this counter. No tag was
  /// computed.
  duplicate('duplicate'),

  /// The counter is 64 or more behind the highest committed counter of the
  /// replay window. No tag was computed.
  tooOld('too_old');

  const FrameRefusalKind(this.term);

  /// The snake_case name of the kind.
  final String term;
}

/// What `FrameSession.seal` gives: [FrameSealed] or [FrameRefusal].
sealed class FrameSealResult {
  /// True for [FrameSealed].
  bool get ok;
}

/// What `FrameSession.open` gives: [FrameOpened] or [FrameRefusal].
sealed class FrameOpenResult {
  /// True for [FrameOpened].
  bool get ok;
}

/// What `MacKey.tag` gives: [MacTag] or [FrameRefusal].
sealed class MacTagResult {
  /// True for [MacTag].
  bool get ok;
}

/// A sealed frame: [length] body bytes were written to the caller's buffer.
final class FrameSealed implements FrameSealResult {
  const FrameSealed(this.length);

  final int length;

  @override
  bool get ok => true;
}

/// An opened frame: which key opened it, the length of its clear part, and
/// the number of plaintext bytes written to the caller's buffer.
final class FrameOpened implements FrameOpenResult {
  const FrameOpened(this.slot, this.clearLength, this.plainLength);

  final FrameSlot slot;
  final int clearLength;
  final int plainLength;

  @override
  bool get ok => true;
}

/// The tag of a MAC-only call.
final class MacTag implements MacTagResult {
  const MacTag(this.tag);

  final Uint8List tag;

  @override
  bool get ok => true;
}

/// A refused frame call. Refusals are values: seal, open and the MAC-only
/// calls never throw for an argument or for wire bytes.
final class FrameRefusal
    implements FrameSealResult, FrameOpenResult, MacTagResult {
  const FrameRefusal._(this.kind, this.reason, {this.needed, this.length});

  final FrameRefusalKind kind;

  /// What was refused, for a log. Test for [kind], not for this text.
  final String reason;

  /// [FrameRefusalKind.bufferFull]: the bytes the output buffer must hold.
  /// [FrameRefusalKind.shortPacket]: the bytes the body must hold.
  final int? needed;

  /// [FrameRefusalKind.tooLong]: the length that is above 255.
  /// [FrameRefusalKind.shortPacket]: the length of the body.
  final int? length;

  @override
  bool get ok => false;

  @override
  String toString() => 'FrameRefusal(${kind.term}: $reason)';
}

/// The longest frame body and the longest associated data, in bytes.
const int frameMaxBody = 255;

FrameRefusal badValue(String reason) =>
    FrameRefusal._(FrameRefusalKind.badValue, reason);

FrameRefusal tooLong(int length) => FrameRefusal._(
  FrameRefusalKind.tooLong,
  '$length bytes, the limit is $frameMaxBody',
  length: length,
);

FrameRefusal bufferFull(int needed) => FrameRefusal._(
  FrameRefusalKind.bufferFull,
  'the output buffer must hold $needed bytes',
  needed: needed,
);

FrameRefusal shortPacket(int needed, int length) => FrameRefusal._(
  FrameRefusalKind.shortPacket,
  'the body is $length bytes, its clear part and tag need $needed',
  needed: needed,
  length: length,
);

const FrameRefusal tagMismatch = FrameRefusal._(
  FrameRefusalKind.tagMismatch,
  'the tag does not match',
);

const FrameRefusal duplicate = FrameRefusal._(
  FrameRefusalKind.duplicate,
  'the replay window has this counter',
);

const FrameRefusal tooOld = FrameRefusal._(
  FrameRefusalKind.tooOld,
  'the counter is 64 or more behind the replay window',
);
