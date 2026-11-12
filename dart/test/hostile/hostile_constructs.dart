import 'package:packbin/packbin.dart';

import '../support/repeat_last.dart'
    show followedText, inElementText, nestingText, rounds;
import 'hostile_cases.dart';

typedef Build = Object Function();

Field _n(int id, String name) => u8(id, name);

/// One `construct` case: the scheme that must be refused, the field the
/// refusal names, and the whole text of the refusal (the rule and the field),
/// so an error from a typo in the builder does not pass the case.
class HostileConstruct {
  const HostileConstruct(this.build, this.field, this.rule);

  final Build build;
  final int? field;
  final String rule;
}

const _emptyBody =
    'the body holds no member; a round of it would charge no slot and write nothing';

/// The element row of the list and dict cases: `u8 mode; repeat { u8 v }`.
NestedField<Row> _modeThenRepeat() =>
    nested('item', [_n(0, 'mode'), rounds(1)]);

/// The schemes of the `construct` cases of `fixtures/hostile/cases.txt`, by
/// case id, written by hand from fixtures/hostile/README.md.
final hostileConstructs = <String, HostileConstruct>{
  'nine_flag_bits': HostileConstruct(
    () => scheme(1, [
      flags(0, [for (var i = 0; i < 9; i++) _n(i, 'f$i')]),
    ]),
    0,
    'packbin: invalid scheme at field 0 (f0): flags: ninth bit (f8); a flag '
    'byte holds 8 bits',
  ),
  'nine_flag_bits_split': HostileConstruct(
    () {
      final fb = flagByte('fb');
      return scheme(1, [fb, for (var i = 0; i < 9; i++) fb.bit(_n(i, 'f$i'))]);
    },
    8,
    'packbin: invalid scheme at field 8 (f8): flag byte "fb": ninth bit (f8); '
    'a flag byte holds 8 bits',
  ),
  'when_names_later_field': HostileConstruct(
    () => scheme(1, [
      _n(0, 'a'),
      when(1, eq(2, 1), [_n(1, 'b')]),
      _n(2, 'c'),
    ]),
    1,
    'packbin: invalid scheme at field 1 (b): when 1: eq names field id 2, '
    'which is not declared earlier in the same scope',
  ),
  'bool_outside_flags': HostileConstruct(
    () => scheme(1, [_n(0, 'a'), flagBool(1, 'on')]),
    1,
    'packbin: invalid scheme at field 1 (on): bool on: allowed only directly '
    'inside flags or a flag bit; move it into flags',
  ),
  'empty_group_outside_flags': HostileConstruct(
    () => scheme(1, [_n(0, 'a'), groupOf(1, 'mark', [])]),
    1,
    'packbin: invalid scheme at field 1 (mark): empty group mark: allowed '
    'only directly inside flags or a flag bit; move it into flags',
  ),
  'eq_bool_false': HostileConstruct(
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
      when(1, eq(0, false), [_n(1, 'v')]),
    ]),
    1,
    'packbin: invalid scheme at field 1 (v): when 1: eq names bool field id 0 '
    '(on) and accepts only true, not false',
  ),
  'eq_out_of_range': HostileConstruct(
    () => scheme(1, [
      _n(0, 'a'),
      when(1, eq(0, 300), [_n(1, 'v')]),
    ]),
    1,
    'packbin: invalid scheme at field 1 (v): when 1 tests u8 field 0 (\'a\') '
    'against 300; the value must be a whole number from 0 to 255',
  ),
  'count_names_later_field': HostileConstruct(
    () => scheme(1, [sized(0, 'payload', 1), u16(1, 'n')]),
    0,
    'packbin: invalid scheme at field 0 (payload): sized 0: count names field '
    'id 1, which is not declared earlier in the same scope',
  ),
  'when_names_outer_field_in_repeat': HostileConstruct(
    () => scheme(1, [
      u8(0, 'mode'),
      repeat(1, [
        when(1, eq(0, 1), [u8(1, 'v')]),
      ]),
    ]),
    1,
    'packbin: invalid scheme at field 1 (v): when 1: eq names field id 0, '
    'which is not declared earlier in the same scope',
  ),
  'construct_empty_times_body': HostileConstruct(
    () => scheme(1, [u8(0, 'n'), times(1, 0, [])]),
    1,
    'packbin: invalid scheme at field 1 (times 1): times 1: $_emptyBody',
  ),
  'construct_empty_repeat_body': HostileConstruct(
    () => scheme(1, [repeat(0, [])]),
    0,
    'packbin: invalid scheme at field 0 (repeat 0): repeat 0: $_emptyBody',
  ),
  'construct_empty_when_times_body': HostileConstruct(
    () => scheme(1, [
      u8(0, 'mode'),
      u8(1, 'c'),
      times(2, 1, [when(2, eq(0, 1), [])]),
    ]),
    2,
    'packbin: invalid scheme at field 2 (times 2): times 2: $_emptyBody',
  ),
  'construct_empty_when_repeat_body': HostileConstruct(
    () => scheme(1, [
      u8(0, 'mode'),
      repeat(1, [when(1, eq(0, 1), [])]),
    ]),
    1,
    'packbin: invalid scheme at field 1 (repeat 1): repeat 1: $_emptyBody',
  ),
  'construct_empty_round_body_list_element': HostileConstruct(
    () => scheme(1, [
      list('items', nested('item', [u8(0, 'n'), times(1, 0, [])])),
    ]),
    1,
    'packbin: invalid scheme at field 1 (times 1): times 1: $_emptyBody',
  ),
  'construct_empty_nested_when_body': HostileConstruct(
    () => scheme(1, [
      u8(0, 'mode'),
      u8(1, 'c'),
      times(2, 1, [
        when(2, eq(0, 1), [when(2, eq(0, 1), [])]),
      ]),
    ]),
    2,
    'packbin: invalid scheme at field 2 (times 2): times 2: $_emptyBody',
  ),
  // AZ-4217, contract repeat-last: R1 to R9.
  'construct_repeat_then_field': HostileConstruct(
    () => scheme(1, [rounds(0), _n(1, 'x')]),
    0,
    followedText(0, 'x'),
  ),
  'construct_repeat_in_when_then_field': HostileConstruct(
    () => scheme(1, [
      _n(0, 'k'),
      when(1, eq(0, 1), [rounds(1)]),
      _n(2, 'x'),
    ]),
    1,
    followedText(1, 'x'),
  ),
  'construct_repeat_in_flags_then_field': HostileConstruct(
    () => scheme(1, [
      flags(0, [rounds(0)]),
      _n(1, 'x'),
    ]),
    0,
    followedText(0, 'x'),
  ),
  // A nested row takes no id of the row around it, so `x` is id 0.
  'construct_repeat_in_group_then_field': HostileConstruct(
    () => scheme(1, [
      nested('m', [rounds(0)]),
      _n(0, 'x'),
    ]),
    0,
    followedText(0, 'x'),
  ),
  'construct_repeat_then_repeat': HostileConstruct(
    () => scheme(1, [
      rounds(0),
      repeat(1, [_n(1, 'w')]),
    ]),
    0,
    followedText(0, 'repeat 1'),
  ),
  'construct_repeat_then_exclusive_when': HostileConstruct(
    () => scheme(1, [
      _n(0, 'k'),
      when(1, eq(0, 1), [rounds(1)]),
      when(2, eq(0, 2), [_n(2, 'x')]),
    ]),
    1,
    followedText(1, 'x'),
  ),
  'construct_repeat_in_list_element': HostileConstruct(
    () => scheme(1, [list('items', _modeThenRepeat())]),
    1,
    inElementText(1),
  ),
  'construct_repeat_in_dict_element': HostileConstruct(
    () => scheme(1, [dict('d', _modeThenRepeat())]),
    1,
    inElementText(1),
  ),
  // Refused by the nesting rule, which keeps its text.
  'construct_repeat_in_times_round': HostileConstruct(
    () => scheme(1, [
      _n(0, 'k'),
      times(1, 0, [rounds(1)]),
    ]),
    1,
    nestingText(1),
  ),
};

/// A construct case: the scheme must be refused with the entry's rule, naming
/// the field the entry gives.
String? checkConstruct(HostileCase c, HostileConstruct? entry) {
  if (entry == null) return 'no Dart scheme for construct case ${c.id}';
  if (c.terms != 'scheme_error') return '${c.id}: vector expects ${c.terms}';
  final run = guarded(entry.build);
  final wrong = checkRefusal(c, run, entry.rule);
  if (wrong != null) return wrong;
  final field = (run.error! as PackbinException).field;
  return field == entry.field
      ? null
      : '${c.id}: the refusal names field $field, want ${entry.field}';
}
