part of 'hostile_packs.dart';

/// `repeat { u8 v }` with the anchor and id [id].
Field _vRounds(int id) => repeat(id, [_u8(id, 'v')]);

const Row _twoRounds = {
  'v': [5, 6],
};

/// AZ-4217, contract repeat-last: the pack cases K1 to K4. A repeat that is
/// the last thing the packet reads, and a `times` with a field after it, build
/// and pack the bytes they packed before the rule.
final Map<String, HostilePack> _repeatLastPacks = {
  'pack_repeat_last': HostilePack(
    () => _s([_u8(0, 'x'), _vRounds(1)]),
    () => {'x': 9, ..._twoRounds},
  ),
  'pack_repeat_last_in_when': HostilePack(
    () => _s([
      _u8(0, 'k'),
      when(1, eq(0, 1), [_vRounds(1)]),
    ]),
    () => {'k': 1, ..._twoRounds},
  ),
  'pack_repeat_last_in_flags': HostilePack(
    () => _s([
      flags(0, [_u8(0, 'x'), _vRounds(1)]),
    ]),
    () => {'x': 9, ..._twoRounds},
  ),
  'pack_times_then_field': HostilePack(
    () => _s([
      _u8(0, 'k'),
      times(1, 0, [_u8(1, 'v')]),
      _u8(2, 'x'),
    ]),
    () => {'k': 2, ..._twoRounds, 'x': 9},
  ),
};
