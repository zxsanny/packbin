import 'dart:typed_data';

/// The refusal names of the contract `compact-text` (the `kind` column of
/// `fixtures/text/vectors.txt`).
enum TextRefusal { short, varint, mode, pad, code, cap, esc, utf8, raw, length }

/// What a decode gives: [TextValue] or [TextFailure]. A decode never throws.
sealed class TextRead {
  const TextRead();
}

final class TextValue extends TextRead {
  const TextValue(this.value, this.next);

  final String value;

  /// The offset of the first byte after the field.
  final int next;
}

final class TextFailure extends TextRead {
  const TextFailure(this.kind, this.needed, this.left);

  final TextRefusal kind;

  /// For [TextRefusal.short]: the bytes the field needed where only [left]
  /// were there. 0 for every other kind.
  final int needed;
  final int left;

  @override
  String toString() => 'TextFailure(${kind.name}, needed $needed, left $left)';
}

enum TextEncodeProblem { loneSurrogate, tooLong }

/// Thrown by an encode for a text that has no field bytes.
final class TextEncodeException implements Exception {
  const TextEncodeException(this.problem, this.detail);

  final TextEncodeProblem problem;

  /// [TextEncodeProblem.loneSurrogate]: the index of the UTF-16 unit.
  /// [TextEncodeProblem.tooLong]: the UTF-8 length of the text.
  final int detail;

  @override
  String toString() => switch (problem) {
    TextEncodeProblem.loneSurrogate => 'unpaired surrogate at unit $detail',
    TextEncodeProblem.tooLong => 'utf-8 length $detail',
  };
}

/// The last text one pack call encoded and its field: a lone string under a
/// `times` or a `repeat` comes again every round. One cache belongs to one
/// pack call. [field] is shared with the caller and must not be written.
final class TextCache {
  String text = '';
  Uint8List field = Uint8List(1);
}
