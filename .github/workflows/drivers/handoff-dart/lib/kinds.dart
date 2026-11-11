import 'package:packbin/packbin.dart';

typedef Row = Map<String, Object?>;

/// One payload kind of the ring: the scheme, the row Dart packs, the row unpack must give, and whether the unpacked
/// row must repack to the same bytes.
final class Kind {
  const Kind(this.scheme, this.pack, this.want, {this.repack = false});

  final Scheme<Row> scheme;
  final Row pack;
  final Row want;
  final bool repack;
}

/// The kinds that also take unpack-<kind>-short: a packet cut short must be refused.
const shortKinds = {'listgroup', 'dictgroup', 'listflags'};

Row _point(int a, int b) => {'a': a, 'b': b};

/// The kind [name], its scheme built by hand as the README shows (ADR-001), or null when there is none. A scheme the
/// package refuses throws a PackbinException.
Kind? kindOf(String name) {
  switch (name) {
    case 'user':
      final row = <String, Object?>{
        'username': 'zxsanny',
        'roles': ['user', 'dispatcher'],
        'access': {
          'channel': ['read'],
          'map': ['read', 'gps_fix', 'set', 'edit'],
          'store': ['read', 'write'],
        },
      };
      return Kind(
        scheme(1, [
          utf8Field(0, 'username'),
          list('roles', utf8Field(0, 'role')),
          dict('access', list('actions', utf8Field(0, 'action'))),
        ]),
        row,
        row,
      );
    case 'nested':
      final row = <String, Object?>{
        'access': {
          'map': [
            {'op': 'gps_fix'},
          ],
          'store': [
            {'op': 'read'},
            {'op': 'write'},
          ],
        },
      };
      return Kind(
        scheme(1, [
          dict('access', list('rows', dict('row', utf8Field(0, 'op')))),
        ]),
        row,
        row,
      );
    // flags { bool on }: the bit is set only for true.
    case 'boolflag':
      return Kind(
        scheme(1, [
          flags(0, [flagBool(0, 'on')]),
        ]),
        {'on': false},
        {},
      );
    case 'booltrue':
      return Kind(
        scheme(1, [
          flags(0, [flagBool(0, 'on')]),
        ]),
        {'on': true},
        {'on': true},
      );
    // u8 k; split flag byte m; when(k == 1) { m.bit(u8 v) }: {k:0, v:5} sets the bit although the when is not taken,
    // and unpack never reads it.
    case 'bitwhen':
      final m = flagByte('m');
      return Kind(
        scheme(1, [
          u8(0, 'k'),
          m,
          when(1, eq(0, 1), [m.bit(u8(1, 'v'))]),
        ]),
        {'k': 0, 'v': 5},
        {'k': 0},
      );
    // Aligned rounds: one entry per round; a clear bit and a when not taken leave the entry null.
    case 'roundflags':
      return Kind(
        scheme(1, [
          repeat(0, [
            flags(0, [flagBool(0, 'on'), u8(1, 'n')]),
          ]),
        ]),
        {
          'on': [true, false, true],
          'n': [1, 2, 3],
        },
        {
          'on': [true, null, true],
          'n': [1, 2, 3],
        },
        repack: true,
      );
    case 'roundwhen':
      return Kind(
        scheme(1, [
          repeat(0, [
            u8(0, 'k'),
            when(1, eq(0, 1), [u8(1, 'v')]),
          ]),
        ]),
        {
          'k': [1, 2],
          'v': [9],
        },
        {
          'k': [1, 2],
          'v': [9, null],
        },
        repack: true,
      );
    case 'listgroup':
      final row = <String, Object?>{
        'pts': [_point(1, 2), _point(3, 4)],
      };
      return Kind(
        scheme(1, [
          list('pts', nested('p', [u8(0, 'a'), u8(1, 'b')])),
        ]),
        row,
        row,
      );
    case 'dictgroup':
      final row = <String, Object?>{
        'm': {'y': _point(3, 4), 'x': _point(1, 2)},
      };
      return Kind(
        scheme(1, [
          dict('m', nested('p', [u8(0, 'a'), u8(1, 'b')])),
        ]),
        row,
        row,
      );
    // A missing value is a clear flag bit.
    case 'listflags':
      final row = <String, Object?>{
        'pts': [
          {'a': 1},
          <String, Object?>{},
          {'b': 2},
        ],
      };
      return Kind(
        scheme(1, [
          list(
            'pts',
            nested('p', [
              flags(0, [u8(0, 'a'), u16(1, 'b')]),
            ]),
          ),
        ]),
        row,
        row,
      );
    default:
      return null;
  }
}
