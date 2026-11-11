import 'package:packbin/packbin.dart';

import '../support/position.dart';
import '../support/user_rows.dart';

typedef Row = Map<String, Object?>;

/// The schemes the seeded run reads every input with, each under its own type
/// number so one call can dispatch among all of them: the ring kinds of
/// .github/workflows/language-pair.sh, the golden position, and one scheme
/// for each kind of field a hostile packet can aim at (rounds with and
/// without low limits, counted fields, groups, flags, nested rows, list and
/// dict elements). The same shapes as Swift's `fuzzSchemes`.
List<Scheme<Object>> fuzzSchemes() {
  final fb = flagByte('m');
  final fb2 = flagByte('m');
  final wide = [for (var i = 0; i < 40; i++) u8(i + 1, 'w$i')];
  return [
    scheme(1, [
      utf8Field(0, 'username'),
      list('roles', utf8Field(0, 'role')),
      dict('access', list('ops', utf8Field(0, 'op'))),
    ]),
    scheme(2, [dict('access', list('rows', dict('row', utf8Field(0, 'v'))))]),
    scheme(3, [
      flags(0, [flagBool(0, 'on')]),
    ]),
    scheme(4, [
      u8(0, 'k'),
      fb,
      when(1, eq(0, 1), [fb.bit(u8(1, 'v'))]),
    ]),
    scheme(5, [
      repeat(0, [
        flags(0, [flagBool(0, 'on'), u8(1, 'n')]),
      ]),
    ]),
    scheme(6, [
      repeat(0, [
        u8(0, 'k'),
        when(1, eq(0, 1), [u8(1, 'v')]),
      ]),
    ]),
    scheme(7, [
      list('pts', nested('p', [u8(0, 'a'), u8(1, 'b')])),
    ]),
    scheme(8, [
      dict('m', nested('p', [u8(0, 'a'), u8(1, 'b')])),
    ]),
    scheme(9, [
      list(
        'pts',
        nested('p', [
          flags(0, [u8(0, 'a'), u16(1, 'b')]),
        ]),
      ),
    ]),
    scheme(10, [
      u8(0, 'n'),
      times(1, 0, [u8(1, 'v'), utf8Field(2, 's')]),
    ]),
    scheme(11, [
      u8(0, 'n'),
      times(1, 0, [u8(1, 'v'), utf8Field(2, 's')]),
    ]).withLimits(maxRounds: 3, maxSlots: 8),
    scheme(12, [
      u8(0, 'n'),
      sized(1, 'raw', 0),
      u8(2, 'c'),
      bits(3, 'b', 2),
      u8(4, 'd'),
      packed(2, 5, 'p', 4, bias: -1),
      u2([slot(6, 's0'), slot(7, 's1')]),
    ]),
    scheme(13, [
      repeat(0, [u8(0, 'k'), list('xs', u8(0, 'e'))]),
    ]),
    scheme(14, [
      repeat(0, [u8(0, 'k')]),
    ]).withLimits(maxRounds: 3, maxSlots: 8),
    scheme(15, [
      repeat(0, [u8(0, 'k'), when(1, eq(0, 1), wide)]),
    ]),
    scheme(16, [
      u8(0, 'a'),
      flags(1, [
        groupOf(1, 'g', [u8(1, 'x'), u8(2, 'y')]),
        u8(3, 'z'),
      ]),
    ]),
    scheme(17, [
      u32(0, 'n'),
      times(1, 0, [u8(1, 'v')]),
    ]),
    scheme(18, [
      list(
        'items',
        nested('item', [
          u8(0, 'n'),
          times(1, 0, [u16(1, 'k')]),
        ]),
      ),
    ]),
    scheme(19, [
      repeat(0, [
        u8(0, 'a'),
        nested('g', [
          u8(0, 'a'),
          when(1, eq(0, 1), [u8(1, 'y')]),
        ]),
      ]),
    ]),
    scheme(20, [
      i64(0, 'n'),
      bits(1, 'b', 0),
      times(2, 0, [
        flags(2, [flagBool(2, 'on'), u16(3, 'v')]),
      ]),
    ]),
    scheme(21, [
      dict('d', nested('row', [fb2, u8(0, 'k'), fb2.bit(sized(1, 's', 0))])),
    ]),
    positionMapScheme(),
  ];
}

/// The typed schemes, read one at a time (each fills its row type).
List<Scheme<Object>> fuzzTypedSchemes() => [positionScheme(), userScheme()];

/// The scheme builders of the hostile `unpack` cases of
/// fixtures/hostile/cases.txt, by case id. A case a package refuses at
/// construction has none of its own (its input is read with the fuzz schemes).
final Map<String, Scheme<Row> Function()> hostileUnpackSchemes = {
  'zero_progress_repeat_bool': () => scheme(1, [
    repeat(0, [flagBool(0, 'on')]),
  ]),
  'zero_progress_repeat_when': () => scheme(1, [
    u8(0, 'mode'),
    repeat(1, [
      when(1, eq(0, 1), [u8(1, 'v')]),
    ]),
  ]),
  'negative_count': () => scheme(1, [i8(0, 'n'), sized(1, 'payload', 0)]),
  'oversize_count': () => scheme(1, [u32(0, 'n'), sized(1, 'payload', 0)]),
  'oversize_count_times': () => scheme(1, [
    u32(0, 'n'),
    times(1, 0, [u8(1, 'v')]),
  ]),
  'oversize_list_count': () => scheme(1, [list('xs', u8(0, 'x'))]),
  'invalid_utf8': () => scheme(1, [utf8Field(0, 'name')]),
  for (final id in [
    'invalid_utf8_dict_key',
    'dict_keys_out_of_order',
    'dict_keys_repeated',
    'dict_keys_repeated_forms',
    'dict_keys_prefix_descends',
    'dict_keys_utf16_order',
  ])
    id: () => scheme(1, [dict('m', u8(0, 'v'))]),
  'count_behind_clear_flag': () => scheme(1, [
    flags(0, [u8(0, 'n')]),
    sized(1, 'payload', 0),
  ]),
  'count_behind_clear_flag_bits': () => scheme(1, [
    flags(0, [u8(0, 'n')]),
    bits(1, 'segs', 0),
  ]),
};

/// The scheme builders of the hostile `limit` cases, at the default limits;
/// a case reads its packet with `maxRounds: 3` of it and with the defaults.
final Map<String, Scheme<Row> Function()> hostileLimitSchemes = {
  'repeat_rounds_over_limit': () => scheme(1, [
    repeat(0, [u8(0, 'v')]),
  ]),
  'times_rounds_over_limit': () => scheme(1, [
    u8(0, 'n'),
    times(1, 0, [u8(1, 'v')]),
  ]),
};

/// The scheme(s) of each corpus kind (fixtures/hostile/fuzz/README.md): the
/// ring kinds of language-pair.sh, the golden position, `any` (no scheme) and
/// the hostile case ids above. A case id with no scheme here is read with
/// the fuzz schemes only.
Map<String, List<Scheme<Object>>> kindSchemes() {
  final fb = flagByte('m');
  Scheme<Object> one(List<Field> fields) => scheme(1, fields);
  final on = one([
    flags(0, [flagBool(0, 'on')]),
  ]);
  final kinds = <String, List<Scheme<Object>>>{
    'user': [
      one([
        utf8Field(0, 'username'),
        list('roles', utf8Field(0, 'role')),
        dict('access', list('actions', utf8Field(0, 'action'))),
      ]),
      userScheme(),
    ],
    'nested': [
      one([dict('access', list('rows', dict('row', utf8Field(0, 'op'))))]),
    ],
    'boolflag': [on],
    'booltrue': [on],
    'bitwhen': [
      one([
        u8(0, 'k'),
        fb,
        when(1, eq(0, 1), [fb.bit(u8(1, 'v'))]),
      ]),
    ],
    'roundflags': [
      one([
        repeat(0, [
          flags(0, [flagBool(0, 'on'), u8(1, 'n')]),
        ]),
      ]),
    ],
    'roundwhen': [
      one([
        repeat(0, [
          u8(0, 'k'),
          when(1, eq(0, 1), [u8(1, 'v')]),
        ]),
      ]),
    ],
    'listgroup': [
      one([
        list('pts', nested('p', [u8(0, 'a'), u8(1, 'b')])),
      ]),
    ],
    'dictgroup': [
      one([
        dict('m', nested('p', [u8(0, 'a'), u8(1, 'b')])),
      ]),
    ],
    'listflags': [
      one([
        list(
          'pts',
          nested('p', [
            flags(0, [u8(0, 'a'), u16(1, 'b')]),
          ]),
        ),
      ]),
    ],
    'position': [positionMapScheme(), positionScheme()],
    'any': [],
  };
  hostileLimitSchemes.forEach((id, build) {
    final s = build();
    kinds[id] = [s, s.withLimits(maxRounds: 3)];
  });
  hostileUnpackSchemes.forEach((id, build) {
    try {
      kinds[id] = [build()];
    } on PackbinException catch (e) {
      if (e.kind != ErrorKind.schemeError) rethrow;
      kinds[id] = [];
    }
  });
  return kinds;
}
