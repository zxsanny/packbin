import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/repeat_last.dart';

// AZ-4217, contract repeat-last 1.0.1, map rows: where the repeat and the
// field after it may stand. The refusal names the first field after the
// repeat that can write a byte; a repeat inside an element or inside a nested
// row of a round is refused whatever follows it. The cases R1 to R9 and K1 to
// K5 of the contract are in repeat_last_test.dart.

// What the refusal names: the first field after the repeat that can write a
// byte, the nearest place first.
final List<Refused> followers = [
  (
    name:
        'a later field of the when that holds the repeat, not the field '
        'after the when',
    fields: () => [
      u8(0, 'k'),
      when(1, eq(0, 1), [rounds(1), u8(2, 'y')]),
      u8(3, 'x'),
    ],
    text: followedText(1, 'y'),
  ),
  (
    name:
        'a field two places out: after the when that holds the flags that '
        'holds the repeat',
    fields: () => [
      u8(0, 'k'),
      when(1, eq(0, 1), [
        flags(1, [rounds(1)]),
      ]),
      u8(2, 'x'),
    ],
    text: followedText(1, 'x'),
  ),
  (
    name: 'a later member of the flags that holds the repeat',
    fields: () => [
      flags(0, [rounds(0), u8(1, 'x')]),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'a later member of the flags around the flags that holds the repeat',
    fields: () => [
      flags(0, [
        flags(0, [rounds(0)]),
        u8(1, 'x'),
      ]),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'a later split flag bit',
    fields: () {
      final fb = flagByte('fb');
      return [fb, fb.bit(rounds(0)), fb.bit(u8(1, 'x'))];
    },
    text: followedText(0, 'x'),
  ),
  (
    name: 'a field under a group is named, not the group',
    fields: () => [
      rounds(0),
      groupOf(1, 'g', [u8(1, 'x')]),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'a field of a nested row is named, not the row',
    fields: () => [
      rounds(0),
      nested('m', [u8(0, 'x')]),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'a times is named by its anchor',
    fields: () => [
      u8(0, 'n'),
      rounds(1),
      times(2, 0, [u8(2, 'w')]),
    ],
    text: followedText(1, 'times 2'),
  ),
  (
    name: 'a list is named by its member',
    fields: () => [rounds(0), list('items', u8(0, 'e'))],
    text: followedText(0, 'items'),
  ),
  (
    name: 'a dict is named by its member',
    fields: () => [rounds(0), dict('d', u8(0, 'e'))],
    text: followedText(0, 'd'),
  ),
  (
    name: 'a flags is named flags',
    fields: () => [
      rounds(0),
      flags(1, [u8(1, 'x')]),
    ],
    text: followedText(0, 'flags'),
  ),
  (
    name: 'a split flag byte is named by its name',
    fields: () {
      final fb = flagByte('fb');
      return [rounds(0), fb, fb.bit(u8(1, 'x'))];
    },
    text: followedText(0, 'flag byte "fb"'),
  ),
  (
    name: 'a u2 is named by its first slot',
    fields: () => [
      rounds(0),
      u2([slot(1, 'a'), slot(2, 'b')]),
    ],
    text: followedText(0, 'a'),
  ),
  (
    name: 'a sized is named by its member',
    fields: () => [u8(0, 'n'), rounds(1), sized(2, 'p', 0)],
    text: followedText(1, 'p'),
  ),
  (
    name: 'a zero-width bytes is passed over for the field after it',
    fields: () => [rounds(0), bytes(1, 'z', 0), bytes(2, 'x', 1)],
    text: followedText(0, 'x'),
  ),
];

// A repeat inside an element is refused wherever it sits there, and whatever
// stands after it.
final List<Refused> inElement = [
  (
    name: 'under a when of the element',
    fields: () => [
      list(
        'items',
        nested('item', [
          u8(0, 'mode'),
          when(1, eq(0, 1), [rounds(1)]),
        ]),
      ),
    ],
    text: inElementText(1),
  ),
  (
    name: 'under a flags of the element',
    fields: () => [
      dict(
        'd',
        nested('item', [
          flags(0, [rounds(0)]),
        ]),
      ),
    ],
    text: inElementText(0),
  ),
  (
    name: 'under a group of the element',
    fields: () => [
      list(
        'items',
        nested('item', [
          groupOf(0, 'g', [rounds(0)]),
        ]),
      ),
    ],
    text: inElementText(0),
  ),
  (
    name: 'under a nested row of the element',
    fields: () => [
      list(
        'items',
        nested('item', [
          nested('g', [rounds(0)]),
        ]),
      ),
    ],
    text: inElementText(0),
  ),
  (
    name: 'in the element of a list inside a list element',
    fields: () => [
      list('outer', list('inner', nested('item', [rounds(0)]))),
    ],
    text: inElementText(0),
  ),
  (
    name: 'in the element of a list inside a repeat round',
    fields: () => [
      repeat(0, [
        u8(0, 'k'),
        list('rows', nested('row', [rounds(0)])),
      ]),
    ],
    text: inElementText(0),
  ),
  (
    name:
        'with a field after it in the element: the element text, not the '
        'follower text',
    fields: () => [
      list('items', nested('item', [rounds(0), u8(1, 'x')])),
    ],
    text: inElementText(0),
  ),
];

// A nested row is a row of its own, so the nesting rule does not look into
// it: a `times` there is a round of that row and builds. A repeat there is
// followed by the next round of the round around it, and is refused.
final List<Refused> inNestedRowOfRound = [
  (
    name: 'in a nested row of a repeat round',
    fields: () => [
      repeat(0, [
        nested('m', [rounds(0)]),
      ]),
    ],
    text: inRoundText(0),
  ),
  (
    name: 'in a nested row of a times round',
    fields: () => [
      u8(0, 'k'),
      times(1, 0, [
        nested('m', [rounds(0)]),
      ]),
    ],
    text: inRoundText(0),
  ),
  (
    name: 'under a when of a nested row of a round',
    fields: () => [
      u8(0, 'n'),
      times(1, 0, [
        nested('m', [
          u8(0, 'k'),
          when(1, eq(0, 1), [rounds(1)]),
        ]),
      ]),
    ],
    text: inRoundText(1),
  ),
  (
    name:
        'with a field after it in the nested row: the round text, not the '
        'follower text',
    fields: () => [
      repeat(0, [
        nested('m', [rounds(0), u8(1, 'x')]),
      ]),
    ],
    text: inRoundText(0),
  ),
  (
    name:
        'in a nested row of a round of a list element: the round is nearer '
        'than the element',
    fields: () => [
      list(
        'items',
        nested('item', [
          u8(0, 'n'),
          times(1, 0, [
            nested('m', [rounds(0)]),
          ]),
        ]),
      ),
    ],
    text: inRoundText(0),
  ),
];

void main() {
  // AC-1: "after" is the repeat's own place and every place around it; the
  // first field that can write a byte is named.
  group('AZ-4217 AC-1 the refusal names the first field after the repeat '
      'that can write a byte', () {
    itRefuses(followers);
  });

  // AC-1: contract rule 2, a repeat directly or under a when, flags, group
  // or nested row of an element.
  group('AZ-4217 AC-1 a repeat inside a list or dict element', () {
    itRefuses(inElement);
  });

  // AC-1: contract rule 3 where the nesting rule does not reach.
  group('AZ-4217 AC-1 a repeat inside a nested row of a round', () {
    itRefuses(inNestedRowOfRound);
  });
}
