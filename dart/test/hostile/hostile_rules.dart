/// The whole text of each refusal a hostile `unpack`, `limit` or `pack` case
/// must give (the rule, the field id and name, and for an unpack error the
/// bytes needed and left), so a refusal by some other rule does not pass. The
/// `construct` texts are in hostile_constructs.dart.
final Map<String, String> hostileRules = {
  ...hostileUnpackRules,
  ...hostilePackRules,
};

/// A case no Dart test can run, with the reason; each `pack` or `limit` case
/// must also be named in the `Not run by` line of its README section.
const Map<String, String> notRun = {};

/// The `unpack` and `limit` stages. Dart refuses the scheme of the two
/// `zero_progress_repeat_*` cases (a bool outside flags; a when naming a field
/// outside its repeat), as Go and Swift do; a count that has no value or is
/// negative is a bad value.
const Map<String, String> hostileUnpackRules = {
  'zero_progress_repeat_bool':
      'packbin: invalid scheme at field 0 (on): bool on: allowed only '
      'directly inside flags or a flag bit; move it into flags',
  'zero_progress_repeat_when':
      'packbin: invalid scheme at field 1 (v): when 1: eq names field id 0, '
      'which is not declared earlier in the same scope',
  'negative_count':
      'packbin: bad value at field 1 (payload): the count has no value or is '
      'negative',
  'oversize_count':
      'packbin: short packet at field 1 (payload): needed 4294967295, left 1',
  'oversize_count_times':
      'packbin: short packet at field 1 (v): needed 1, left 0',
  'oversize_list_count': 'packbin: short packet at xs: needed 65535, left 0',
  'invalid_utf8': 'packbin: short packet at field 0 (name): needed 0, left 4',
  'invalid_utf8_dict_key': 'packbin: short packet at m: needed 0, left 4',
  'dict_keys_out_of_order': 'packbin: short packet at m: needed 0, left 0',
  'dict_keys_repeated': 'packbin: short packet at m: needed 0, left 0',
  'dict_keys_repeated_forms': 'packbin: short packet at m: needed 0, left 0',
  'dict_keys_prefix_descends': 'packbin: short packet at m: needed 0, left 0',
  'dict_keys_utf16_order': 'packbin: short packet at m: needed 0, left 0',
  'count_behind_clear_flag':
      'packbin: bad value at field 1 (payload): the count has no value or is '
      'negative',
  'count_behind_clear_flag_bits':
      'packbin: bad value at field 1 (segs): the count has no value or is '
      'negative',
  'repeat_rounds_over_limit':
      'packbin: too many at field 0 (v): v: round 4 is above the limit of 3 '
      'rounds',
  'times_rounds_over_limit':
      'packbin: too many at field 1 (v): v: round 4 is above the limit of 3 '
      'rounds',
};

/// The `pack` stage: every case that expects `pack_error`.
const Map<String, String> hostilePackRules = {
  'pack_out_of_range_integer':
      'packbin: pack refused at field 0 (a): 300 does not fit in u8',
  'pack_missing_required_value':
      'packbin: pack refused at field 1 (b): missing b',
  'pack_times_list_too_long':
      'packbin: pack refused at field 1 (x): x: 3 items, times count 2',
  'pack_times_list_too_short':
      'packbin: pack refused at field 1 (x): missing x',
  'pack_times_count_over_limit':
      'packbin: pack refused at field 1 (x): x: the times count is 65536, '
      'above the limit of 65535 rounds',
  'pack_times_zero_with_values':
      'packbin: pack refused at field 1 (x): x: 1 items, times count 0',
  'pack_split_when_source_after_byte':
      'packbin: pack refused at field 1 (speed): speed: a value is given, but '
      'the condition or count of its when or times is not written before the '
      'flag byte, so its bit is clear; write that field before the flag byte',
  'pack_split_times_count_after_byte':
      'packbin: pack refused at field 1 (pt): pt: a value is given, but the '
      'condition or count of its when or times is not written before the flag '
      'byte, so its bit is clear; write that field before the flag byte',
  'pack_split_times_count_skipped':
      'packbin: pack refused at field 2 (pt): pt: a value is given, but the '
      'condition or count of its when or times is not written before the flag '
      'byte, so its bit is clear; write that field before the flag byte',
  'pack_lone_bytes_in_round':
      'packbin: pack refused at field 1 (d): d: a byte buffer in a repeat or '
      'times round needs a list with one buffer per round',
  'pack_lone_utf8_under_times_over_budget':
      'packbin: pack refused at field 1 (s): s: the packet would be 16777989 '
      'bytes, above the limit of 16777216 bytes',
  'pack_element_times_over_budget':
      'packbin: pack refused at field 1 (k): k: the rounds would hold 1048577 '
      'slots, above the limit of 1048576 slots',
  'pack_slots_over_limit':
      'packbin: pack refused at field 1 (m0): m0: the rounds would hold '
      '1048580 slots, above the limit of 1048576 slots',
  'pack_repeat_over_limit':
      'packbin: pack refused at field 0 (k): k: the repeat count is 65536, '
      'above the limit of 65535 rounds',
  'pack_split_count_zero_after_byte_list':
      'packbin: pack refused at field 1 (pt): pt: 2 items, times count 0',
  'pack_flags_skipped_count_with_values':
      'packbin: pack refused at field 1 (pt): pt: a value is given, but the '
      'count of its times is not written, so its bit is clear; write the '
      'count before the times',
  'pack_round_slots_over_limit':
      'packbin: pack refused at field 2 (b): b: the rounds would hold 4 '
      'slots, above the limit of 3 slots',
  'pack_round_slots_flags_over_limit':
      'packbin: pack refused at field 0 (on): on: the rounds would hold 6 '
      'slots, above the limit of 4 slots',
  'pack_flags_short_list':
      'packbin: pack refused at field 1 (v): v: 1 items, repeat count 2; give '
      'one entry per round, null where the member is absent',
  'pack_count_one_clear_when':
      'packbin: pack refused at field 2 (pt): pt: the count c is 1 in the '
      'row, but no field wrote it (the when that holds it is clear), so its '
      'times reads no round; give the count 0, leave it out, or make the when '
      'hold',
  'pack_bits_count_clear_when':
      'packbin: pack refused at field 2 (v): v: count c was not written',
  'pack_packed_count_clear_when':
      'packbin: pack refused at field 2 (v): v: count c was not written',
  'pack_sized_count_clear_when':
      'packbin: pack refused at field 2 (v): v: count c was not written',
  'pack_novalue_count_clear_when_bits':
      'packbin: pack refused at field 2 (v): v: the count c is 3 in the row, '
      'but no field wrote it (the when that holds it is clear), so the member '
      'reads nothing; give the count 0, leave it out, or make the when hold',
  'pack_novalue_count_clear_when_packed':
      'packbin: pack refused at field 2 (v): v: the count c is 3 in the row, '
      'but no field wrote it (the when that holds it is clear), so the member '
      'reads nothing; give the count 0, leave it out, or make the when hold',
  'pack_novalue_count_clear_when_sized':
      'packbin: pack refused at field 2 (v): v: the count c is 3 in the row, '
      'but no field wrote it (the when that holds it is clear), so the member '
      'reads nothing; give the count 0, leave it out, or make the when hold',
  'pack_element_times_over_bytes_budget':
      'packbin: pack refused at field 1 (s): s: the packet would be 16777233 '
      'bytes, above the limit of 16777216 bytes',
};
