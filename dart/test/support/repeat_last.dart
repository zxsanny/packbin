/// What the tests of a repeat that is not the last thing a packet reads share
/// (AZ-4217, contract repeat-last 1.0.1): the whole texts of the refusals, as
/// a scheme error prints them, and the runner of a refused scheme of map rows.
/// The error names the repeat: its anchor and its first member, which is `v`
/// in every scheme of these tests.
library;

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'refusal.dart';

typedef Row = Map<String, Object?>;

const _end = 'a repeat reads to the end of the packet';

String _at(int anchor) => 'packbin: invalid scheme at field $anchor (v)';

/// A field that can write a byte follows the repeat [anchor]; [field] is the
/// first such field, in the words the refusal names it by.
String followedText(int anchor, String field) =>
    '${_at(anchor)}: repeat $anchor: $field follows it; $_end, so nothing can '
    'follow it; use times';

/// The repeat [anchor] sits inside a list or dict element.
String inElementText(int anchor) =>
    '${_at(anchor)}: repeat $anchor is inside a list or dict element; $_end, '
    'so another element cannot follow it; use times';

/// The repeat [anchor] sits inside a nested row of a round, where the nesting
/// rule does not look.
String inRoundText(int anchor) =>
    '${_at(anchor)}: repeat $anchor is inside a repeat or times round; $_end, '
    'so another round cannot follow it; use times';

/// The nesting rule's text for the repeat [anchor] that a round holds
/// directly or under a `when`, `flags`, flag bit or group. It ran before
/// AZ-4217 and keeps its words.
String nestingText(int anchor) =>
    '${_at(anchor)}: repeat $anchor is inside a repeat or times round; a round '
    'cannot hold another repeat or times';

/// `repeat { u8 v }`, with the id the place gives it.
Field rounds(int id) => repeat(id, [u8(id, 'v')]);

/// A scheme that must be refused, and the whole text of its refusal. Each
/// builder makes fresh fields: a flag byte numbers its bits per scheme.
typedef Refused = ({String name, List<Field> Function() fields, String text});

/// One test per case of [cases]: `scheme()` refuses its fields with its text.
void itRefuses(List<Refused> cases) {
  for (final c in cases) {
    test('${c.name} is refused by scheme()', () {
      // Arrange
      final build = c.fields;

      // Act
      final error = refusal(() => scheme(1, build()));

      // Assert
      expect(error.toString(), c.text);
    });
  }
}
