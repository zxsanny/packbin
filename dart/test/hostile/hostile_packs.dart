import 'dart:typed_data';

import 'package:packbin/packbin.dart';

import '../support/depth_schemes.dart' show groupChain, groupRow, whenChain;
import '../support/hex.dart';
import '../support/repeat_last.dart' show rounds;
import 'hostile_cases.dart';

part 'hostile_packs_depth.dart';
part 'hostile_packs_repeat_last.dart';

/// One pack case: the scheme and the map row its section names
/// (fixtures/hostile/README.md). The case file says whether bytes or a
/// refusal comes out.
class HostilePack {
  const HostilePack(this.scheme, this.row);

  final Scheme<Row> Function() scheme;
  final Row Function() row;
}

Scheme<Row> _s(List<Field> fields) => scheme(1, fields);

Field _u8(int id, String name) => u8(id, name);

/// `u8 a; times(a) { u8 x }`
Scheme<Row> _timesX() => _s([
  _u8(0, 'a'),
  times(1, 0, [_u8(1, 'x')]),
]);

/// A split-form flag byte first, `u8 n` after it, bit 0 `times(n) { u8 pt }`,
/// then the bits of [tail].
Scheme<Row> _splitCount([Field Function(FlagByte)? tail]) {
  final fb = flagByte('fb');
  return _s([
    fb,
    _u8(0, 'n'),
    fb.bit(times(1, 0, [_u8(1, 'pt')])),
    if (tail != null) tail(fb),
  ]);
}

/// `u8 mode` and a split-form flag byte (the mode before the byte when
/// [modeFirst]); bit 0 holds [body], then the bits of [tail].
Scheme<Row> _splitWhen(
  bool modeFirst,
  Field Function() body, [
  Field Function(FlagByte)? tail,
]) {
  final fb = flagByte('fb');
  return _s([
    if (modeFirst) ...[_u8(0, 'mode'), fb] else ...[fb, _u8(0, 'mode')],
    fb.bit(body()),
    if (tail != null) tail(fb),
  ]);
}

Field _speedWhen() => when(1, eq(0, 1), [_u8(1, 'speed')]);

/// `u8 n; times(n) { u8 a }; repeat { u8 b }`, maxSlots 3: each round of
/// either container charges one slot.
Scheme<Row> _mixedRounds() => _s([
  _u8(0, 'n'),
  times(1, 0, [_u8(1, 'a')]),
  repeat(2, [_u8(2, 'b')]),
]).withLimits(maxSlots: 3);

/// `repeat { flags { bool on; u8 v } }`, maxSlots 4: a round holds the two
/// names on and v.
Scheme<Row> _flagsRound() => _s([
  repeat(0, [
    flags(0, [flagBool(0, 'on'), _u8(1, 'v')]),
  ]),
]).withLimits(maxSlots: 4);

/// `repeat { u8 w; flags { u8 v } }`
Scheme<Row> _optionalRepeat() => _s([
  repeat(0, [
    _u8(0, 'w'),
    flags(1, [_u8(1, 'v')]),
  ]),
]);

/// `u8 mode; when mode == 1 { u8 c }`, then [member], counted by c.
Scheme<Row> _clearWhenCount(Field member) => _s([
  _u8(0, 'mode'),
  when(1, eq(0, 1), [_u8(1, 'c')]),
  member,
]);

/// `u8 mode; when mode == 1 { u8 c }`; a split-form flag byte; bit 0
/// [member], counted by c.
Scheme<Row> _novalueCount(Field member) {
  final fb = flagByte('fb');
  return _s([
    _u8(0, 'mode'),
    when(1, eq(0, 1), [_u8(1, 'c')]),
    fb,
    fb.bit(member),
  ]);
}

/// `u8 mode; when mode == 1 { u16 a; u8 k }; when k == value { u8 b }`: the
/// source k sits inside a clear when.
Scheme<Row> _skippedSource(int value) => _s([
  _u8(0, 'mode'),
  when(1, eq(0, 1), [u16(1, 'a'), _u8(2, 'k')]),
  when(3, eq(2, value), [_u8(3, 'b')]),
]);

/// `u8 mode; when mode == 1 { flags { bool on }; u8 a }; when on == true
/// { u8 b }`: the bool source sits inside a clear when.
Scheme<Row> _skippedBoolSource() => _s([
  _u8(0, 'mode'),
  when(1, eq(0, 1), [
    flags(1, [flagBool(1, 'on')]),
    _u8(2, 'a'),
  ]),
  when(3, eq(1, true), [_u8(3, 'b')]),
]);

Row _boolRow(int mode, bool on) => {'mode': mode, 'on': on, 'a': 7, 'b': 5};

/// `count` items, each [item].
Row _items(int count, Row item) => {'items': List<Row>.filled(count, item)};

/// `list items of { u32 n; times(n) { body } }`
Scheme<Row> _itemsWithTimes(Field body) => _s([
  list(
    'items',
    nested('item', [
      u32(0, 'n'),
      times(1, 0, [body]),
    ]),
  ),
]);

/// 65 `u8` members m0 to m64 under a `times` of `u32 n`.
Scheme<Row> _wideRound() => _s([
  u32(0, 'n'),
  times(1, 0, [for (var i = 0; i < 65; i++) _u8(1 + i, 'm$i')]),
]);

const Row _clearWhenRow = {
  'mode': 0,
  'c': 3,
  'v': [1, 0, 1],
};

Uint8List _bytes(List<int> values) => Uint8List.fromList(values);

/// fixtures/hostile/cases.txt, pack stage, by case id: every row in the map
/// form, a list as a `List` (with `null` where an entry is absent), a group's
/// members in a nested map under its name.
final Map<String, HostilePack> hostilePacks = {
  'pack_out_of_range_integer': HostilePack(
    () => _s([_u8(0, 'a')]),
    () => {'a': 300},
  ),
  'pack_missing_required_value': HostilePack(
    () => _s([_u8(0, 'a'), _u8(1, 'b')]),
    () => {'a': 1},
  ),
  'pack_times_list_too_long': HostilePack(
    _timesX,
    () => {
      'a': 2,
      'x': [1, 2, 3],
    },
  ),
  'pack_times_list_too_short': HostilePack(
    _timesX,
    () => {
      'a': 2,
      'x': [1],
    },
  ),
  'pack_aligned_round_row': HostilePack(
    () => _s([
      repeat(0, [
        flags(0, [flagBool(0, 'on'), _u8(1, 'n')]),
      ]),
    ]),
    () => {
      'on': [true, false, true],
      'n': [1, 2, 3],
    },
  ),
  'pack_times_count_over_limit': HostilePack(
    () => _s([
      u32(0, 'n'),
      times(1, 0, [_u8(1, 'x')]),
    ]),
    () => {'n': 65536, 'x': 7},
  ),
  'pack_times_zero_with_values': HostilePack(
    _timesX,
    () => {
      'a': 0,
      'x': [5],
    },
  ),
  'pack_split_when_source_after_byte': HostilePack(
    () => _splitWhen(false, _speedWhen),
    () => {'mode': 1, 'speed': 7},
  ),
  'pack_split_times_count_after_byte': HostilePack(
    _splitCount,
    () => {
      'n': 2,
      'pt': [5, 6],
    },
  ),
  'pack_split_times_count_skipped': HostilePack(
    () {
      final fb = flagByte('fb');
      return _s([
        _u8(0, 'sel'),
        fb,
        when(1, eq(0, 1), [_u8(1, 'n')]),
        fb.bit(times(2, 1, [_u8(2, 'pt')])),
      ]);
    },
    () => {
      'sel': 0,
      'pt': [5],
    },
  ),
  'pack_lone_bytes_in_round': HostilePack(
    () => _s([
      _u8(0, 'n'),
      times(1, 0, [bytes(1, 'd', 2)]),
    ]),
    () => {
      'n': 2,
      'd': _bytes([1, 2]),
    },
  ),
  'pack_split_false_condition_silent': HostilePack(
    () => _splitWhen(true, _speedWhen, (fb) => fb.bit(u16(2, 'heading'))),
    () => {'mode': 0, 'speed': 7, 'heading': 90},
  ),
  'pack_lone_utf8_under_times_over_budget': HostilePack(
    () => _s([
      u32(0, 'n'),
      times(1, 0, [utf8Field(1, 's')]),
    ]),
    () => {'n': 65535, 's': 'q' * 65535},
  ),
  'pack_element_times_over_budget': HostilePack(
    () => _itemsWithTimes(u64(1, 'k')),
    () => _items(40, {'n': 65535, 'k': 5}),
  ),
  'pack_slots_over_limit': HostilePack(
    _wideRound,
    () => {'n': 65535, for (var i = 0; i < 65; i++) 'm$i': 1},
  ),
  'pack_repeat_over_limit': HostilePack(
    () => _s([
      repeat(0, [_u8(0, 'k')]),
    ]),
    () => {'k': List<int>.filled(65536, 7)},
  ),
  'pack_split_count_zero_after_byte_list': HostilePack(
    _splitCount,
    () => {
      'n': 0,
      'pt': [5, 6],
    },
  ),
  'pack_split_count_zero_after_byte_scalar': HostilePack(
    _splitCount,
    () => {'n': 0, 'pt': 5},
  ),
  'pack_flags_skipped_count_with_values': HostilePack(
    () => _s([
      flags(0, [
        _u8(0, 'n'),
        times(1, 0, [_u8(1, 'pt')]),
      ]),
    ]),
    () => {
      'pt': [5, 6],
    },
  ),
  'pack_round_slots_at_limit': HostilePack(
    _mixedRounds,
    () => {
      'n': 1,
      'a': [1],
      'b': [2, 3],
    },
  ),
  'pack_round_slots_over_limit': HostilePack(
    _mixedRounds,
    () => {
      'n': 1,
      'a': [1],
      'b': [2, 3, 4],
    },
  ),
  'pack_round_slots_flags_at_limit': HostilePack(
    _flagsRound,
    () => {
      'on': [true, true],
      'v': [5, 6],
    },
  ),
  'pack_round_slots_flags_over_limit': HostilePack(
    _flagsRound,
    () => {
      'on': [true, true, true],
      'v': [5, 6, 7],
    },
  ),
  'pack_flags_short_list': HostilePack(
    _optionalRepeat,
    () => {
      'w': [1, 2],
      'v': [5],
    },
  ),
  'pack_flags_short_list_filled': HostilePack(
    _optionalRepeat,
    () => {
      'w': [1, 2],
      'v': [5, null],
    },
  ),
  'pack_split_times_absent_body': HostilePack(
    () => _splitCount((fb) => fb.bit(u16(2, 'heading'))),
    () => {'n': 2, 'heading': 90},
  ),
  'pack_late_when_in_bit_body': HostilePack(
    () => _splitWhen(
      false,
      () => groupOf(1, 'g', [
        _u8(1, 'd'),
        when(2, eq(0, 1), [_u8(2, 'a')]),
        when(3, eq(0, 2), [_u8(3, 'b')]),
      ]),
    ),
    () => {
      'mode': 1,
      'g': {'d': 5, 'a': 9},
    },
  ),
  'pack_count_one_clear_when': HostilePack(() {
    final fb = flagByte('fb');
    return _s([
      _u8(0, 'mode'),
      when(1, eq(0, 1), [_u8(1, 'c')]),
      fb,
      fb.bit(times(2, 1, [_u8(2, 'pt')])),
      fb.bit(u16(3, 'heading')),
    ]);
  }, () => {'mode': 0, 'c': 1, 'heading': 90}),
  'pack_bits_count_clear_when': HostilePack(
    () => _clearWhenCount(bits(2, 'v', 1)),
    () => _clearWhenRow,
  ),
  'pack_packed_count_clear_when': HostilePack(
    () => _clearWhenCount(packed(1, 2, 'v', 1)),
    () => _clearWhenRow,
  ),
  'pack_sized_count_clear_when': HostilePack(
    () => _clearWhenCount(sized(2, 'v', 1)),
    () => {
      'mode': 0,
      'c': 3,
      'v': _bytes([1, 2, 3]),
    },
  ),
  'pack_novalue_count_clear_when_bits': HostilePack(
    () => _novalueCount(bits(2, 'v', 1)),
    () => {'mode': 0, 'c': 3},
  ),
  'pack_novalue_count_clear_when_packed': HostilePack(
    () => _novalueCount(packed(1, 2, 'v', 1)),
    () => {'mode': 0, 'c': 3},
  ),
  'pack_novalue_count_clear_when_sized': HostilePack(
    () => _novalueCount(sized(2, 'v', 1)),
    () => {'mode': 0, 'c': 3},
  ),
  'pack_repeat_unequal_lists_lone': HostilePack(
    () => _s([
      repeat(0, [_u8(0, 'a'), _u8(1, 'b')]),
    ]),
    () => {
      'a': [1, 2],
      'b': 7,
    },
  ),
  'pack_repeat_unequal_lists_when': HostilePack(
    () => _s([
      repeat(0, [
        _u8(0, 'k'),
        when(1, eq(0, 1), [_u8(1, 'v')]),
      ]),
    ]),
    () => {
      'k': [1, 2],
      'v': [9],
    },
  ),
  'pack_times_short_list_flags': HostilePack(
    () => _s([
      _u8(0, 'c'),
      times(1, 0, [
        flags(1, [_u8(1, 'v')]),
      ]),
    ]),
    () => {
      'c': 2,
      'v': [5],
    },
  ),
  'pack_element_times_over_bytes_budget': HostilePack(
    () => _itemsWithTimes(utf8Field(1, 's')),
    () => _items(16, {'n': 65535, 's': 'q' * 16}),
  ),
  'pack_when_of_skipped_source': HostilePack(
    () => _skippedSource(2),
    () => {'mode': 0, 'a': 7, 'k': 2, 'b': 5},
  ),
  'pack_when_of_skipped_source_zero': HostilePack(
    () => _skippedSource(0),
    () => {'mode': 0, 'a': 7, 'k': 0, 'b': 5},
  ),
  'pack_when_of_skipped_bool_source': HostilePack(
    _skippedBoolSource,
    () => _boolRow(0, true),
  ),
  'pack_when_of_held_bool_source': HostilePack(
    _skippedBoolSource,
    () => _boolRow(1, true),
  ),
  'pack_when_of_held_bool_source_clear': HostilePack(
    _skippedBoolSource,
    () => _boolRow(1, false),
  ),
  ..._repeatLastPacks,
  ..._depthPacks,
};

/// A pack case: packs the row of its handler; the bytes of the case, or a
/// refusal with the text [rules] pins and no bytes.
String? checkPack(
  HostileCase c,
  HostilePack? entry,
  Map<String, String> rules,
) {
  if (entry == null) return 'no Dart scheme for pack case ${c.id}';
  final built = guarded(entry.scheme);
  if (built.error != null) {
    return '${c.id}: the scheme of a pack case did not build: ${built.error}';
  }
  final layout = built.value!;
  final row = entry.row();
  final run = guarded(() => pack(layout, row));
  switch (c.terms) {
    case 'bytes':
      final error = run.error;
      if (error != null) return '${c.id}: expected bytes, got $error';
      final got = hex(run.value!);
      return got == c.hex ? null : '${c.id}: packed $got, want ${c.hex}';
    case 'pack_error':
      final error = run.error;
      if (error == null) {
        return '${c.id}: expected a refusal, got bytes ${hex(run.value!.take(32).toList())}';
      }
      if (error is! PackbinException) {
        return '${c.id}: not a PackbinException: $error';
      }
      final rule = rules[c.id];
      if (rule == null) {
        return '${c.id}: no rule is pinned for this refusal: $error';
      }
      return error.kind == ErrorKind.packError && error.toString() == rule
          ? null
          : '${c.id}: refused by another rule: "$error", want "$rule"';
    default:
      return '${c.id}: a pack case expects bytes or pack_error, got ${c.terms}';
  }
}
