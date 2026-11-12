import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';
import '../support/repeat_last.dart';

// AZ-4217, contract repeat-last 1.0.1, for schemes of typed rows
// (`rowScheme`): the refused cases R1 to R9 and the cases K1 to K5 that keep
// building. A repeat is bound to a list of round rows, one row a round. The
// schemes of map rows are in repeat_last_test.dart.

/// One round of `repeat { u8 v }`.
final class Round {
  Round([this.v]);
  int? v;
}

/// One round of `repeat { u8 w }`.
final class WRound {
  int? w;
}

/// A row that holds the rounds: the nested row `m`, and one round of the
/// `times` of R9.
final class Inner {
  List<Round>? v;
}

/// The element row of the list and dict cases.
final class Item {
  int? mode;
  List<Round>? v;
}

/// One round of a `times` that holds the nested row `m`.
final class Outer {
  Inner? m;
}

final class Top {
  int? k;
  int? x;
  bool? on;
  List<Round>? v;
  List<WRound>? w;
  Inner? m;
  List<Item>? items;
  Map<String, Item>? d;
  List<Inner>? outer;
  List<Outer>? rows;
}

Field kOf(int id) =>
    u8(id, 'k').bind<Top>(get: (r) => r.k, set: (r, v) => r.k = v);

Field xOf(int id) =>
    u8(id, 'x').bind<Top>(get: (r) => r.x, set: (r, v) => r.x = v);

Field vOf(int id) =>
    u8(id, 'v').bind<Round>(get: (r) => r.v, set: (r, v) => r.v = v);

/// `repeat { u8 v }` bound to the rounds of a [Top].
Field topRounds(int id) => repeat(id, [
  vOf(id),
]).bind<Top, Round>(create: Round.new, get: (r) => r.v, set: (r, v) => r.v = v);

/// `repeat { u8 v }` bound to the rounds of an [Inner].
Field innerRounds(int id) => repeat(id, [vOf(id)]).bind<Inner, Round>(
  create: Round.new,
  get: (r) => r.v,
  set: (r, v) => r.v = v,
);

/// The element row `u8 mode; repeat { u8 v }`.
NestedField<Item> itemRow() => nestedRow<Item>('item', Item.new, [
  u8(0, 'mode').bind<Item>(get: (r) => r.mode, set: (r, v) => r.mode = v),
  repeat(1, [vOf(1)]).bind<Item, Round>(
    create: Round.new,
    get: (r) => r.v,
    set: (r, v) => r.v = v,
  ),
]);

// The refused cases R1 to R9 of the contract, every field bound, and the
// repeat in a nested row of a round.
final List<Refused> refusedCases = [
  (
    name: 'R1 a field after the repeat',
    fields: () => [topRounds(0), xOf(1)],
    text: followedText(0, 'x'),
  ),
  (
    name: 'R2 a field after the when that holds the repeat',
    fields: () => [
      kOf(0),
      when(1, eq(0, 1), [topRounds(1)]),
      xOf(2),
    ],
    text: followedText(1, 'x'),
  ),
  (
    name: 'R3 a field after the flags that holds the repeat',
    fields: () => [
      flags(0, [topRounds(0)]),
      xOf(1),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'R4 a field after the nested row that holds the repeat',
    fields: () => [
      nestedRow<Inner>('m', Inner.new, [
        innerRounds(0),
      ]).bind<Top>(get: (r) => r.m, set: (r, v) => r.m = v),
      xOf(0),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'R4 a field after the anchored group that holds the repeat',
    fields: () => [
      groupOf(0, 'm', [topRounds(0)]),
      xOf(1),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'R5 a second repeat',
    fields: () => [
      topRounds(0),
      repeat(1, [
        u8(1, 'w').bind<WRound>(get: (r) => r.w, set: (r, v) => r.w = v),
      ]).bind<Top, WRound>(
        create: WRound.new,
        get: (r) => r.w,
        set: (r, v) => r.w = v,
      ),
    ],
    text: followedText(0, 'repeat 1'),
  ),
  (
    name: 'R6 a field under a when that cannot hold with the repeat\'s when',
    fields: () => [
      kOf(0),
      when(1, eq(0, 1), [topRounds(1)]),
      when(2, eq(0, 2), [xOf(2)]),
    ],
    text: followedText(1, 'x'),
  ),
  (
    name: 'R7 a repeat in a list element',
    fields: () => [
      list(
        'items',
        itemRow(),
      ).bind<Top>(get: (r) => r.items, set: (r, v) => r.items = v),
    ],
    text: inElementText(1),
  ),
  (
    name: 'R8 a repeat in a dict element',
    fields: () => [
      dict('d', itemRow()).bind<Top>(get: (r) => r.d, set: (r, v) => r.d = v),
    ],
    text: inElementText(1),
  ),
  (
    name: 'R9 a repeat in a times round keeps the text of the nesting rule',
    fields: () => [
      kOf(0),
      times(1, 0, [innerRounds(1)]).bind<Top, Inner>(
        create: Inner.new,
        get: (r) => r.outer,
        set: (r, v) => r.outer = v,
      ),
    ],
    text: nestingText(1),
  ),
  // Contract rule 3 where the nesting rule does not reach: a nested row is a
  // row of its own, and the next round of the times follows its repeat.
  (
    name: 'a repeat in a nested row of a times round',
    fields: () => [
      kOf(0),
      times(1, 0, [
        nestedRow<Inner>('m', Inner.new, [
          innerRounds(0),
        ]).bind<Outer>(get: (r) => r.m, set: (r, v) => r.m = v),
      ]).bind<Top, Outer>(
        create: Outer.new,
        get: (r) => r.rows,
        set: (r, v) => r.rows = v,
      ),
    ],
    text: inRoundText(0),
  ),
];

/// A typed scheme that builds, the row it packs, and the packet.
typedef Kept = ({
  String name,
  Scheme<Top> Function() build,
  Top Function() row,
  String packet,
});

List<Round> twoRounds() => [Round(5), Round(6)];

// AC-2: the cases K1 to K5 of the contract, with typed rows.
final List<Kept> kept = [
  (
    name: 'K1 a repeat after a field',
    build: () => rowScheme<Top>(1, Top.new, [xOf(0), topRounds(1)]),
    row: () => Top()
      ..x = 9
      ..v = twoRounds(),
    packet: '01090506',
  ),
  (
    name: 'K2 a repeat that is the last thing in a when that nothing follows',
    build: () => rowScheme<Top>(1, Top.new, [
      kOf(0),
      when(1, eq(0, 1), [topRounds(1)]),
    ]),
    row: () => Top()
      ..k = 1
      ..v = twoRounds(),
    packet: '01010506',
  ),
  (
    name: 'K3 a repeat that is the last member of a flags that nothing follows',
    build: () => rowScheme<Top>(1, Top.new, [
      flags(0, [xOf(0), topRounds(1)]),
    ]),
    row: () => Top()
      ..x = 9
      ..v = twoRounds(),
    packet: '0103090506',
  ),
  (
    name: 'K4 a times with a field after it',
    build: () => rowScheme<Top>(1, Top.new, [
      kOf(0),
      times(1, 0, [vOf(1)]).bind<Top, Round>(
        create: Round.new,
        get: (r) => r.v,
        set: (r, v) => r.v = v,
      ),
      xOf(2),
    ]),
    row: () => Top()
      ..k = 2
      ..v = twoRounds()
      ..x = 9,
    packet: '0102050609',
  ),
  (
    name: 'K5 a bool bit of an earlier flag byte after the repeat (split form)',
    build: () {
      final fb = flagByte('fb');
      return rowScheme<Top>(1, Top.new, [
        fb,
        fb.bit(xOf(0)),
        topRounds(1),
        fb.bit(
          flagBool(
            2,
            'on',
          ).bind<Top>(get: (r) => r.on, set: (r, v) => r.on = v),
        ),
      ]);
    },
    row: () => Top()
      ..x = 9
      ..v = twoRounds()
      ..on = true,
    packet: '0103090506',
  ),
];

/// The members of [row] the cases set, the rounds as their `v` values.
List<Object?> values(Top row) => [
  row.k,
  row.x,
  row.on,
  row.v?.map((r) => r.v).toList(),
];

void main() {
  // AC-1: the refused cases R1 to R9 of the contract, with typed rows.
  group('AZ-4217 AC-1 a repeat that is not the last thing read is refused '
      'when a scheme of typed rows is built', () {
    for (final c in refusedCases) {
      test('${c.name} is refused by rowScheme()', () {
        // Arrange
        final build = c.fields;

        // Act
        final error = refusal(() => rowScheme<Top>(1, Top.new, build()));

        // Assert
        expect(error.toString(), c.text);
      });
    }
  });

  // AC-2: K1 to K5 of the contract, with typed rows.
  group('AZ-4217 AC-2 a repeat that is the last thing read, typed rows', () {
    for (final c in kept) {
      test('${c.name} builds, packs ${c.packet} and reads the values back', () {
        // Arrange
        final layout = c.build();
        final row = c.row();

        // Act
        final wire = pack(layout, row);
        final back = readRow(layout, hex(wire));

        // Assert
        expect(hex(wire), c.packet);
        expect(values(back), values(row));
      });
    }
  });
}
