import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';
import '../support/repo.dart';

typedef Row = Map<String, Object?>;

/// The `ref` rows of fixtures/text/vectors.txt: id and packet hex.
Map<String, String> refRows() => {
  for (final line in repoText('fixtures/text/vectors.txt').split('\n'))
    if (line.startsWith('ref ')) line.split(' ')[1]: line.split(' ')[2].trim(),
};

/// `utf8 username; list roles of utf8; dict access of list of utf8`: the
/// ring's user packet (scripts/text/gen_vectors.py `packet_user`).
Scheme<Row> userRing() => scheme(1, [
  utf8Field(0, 'username'),
  list('roles', utf8Field(0, 'role')),
  dict('access', list('actions', utf8Field(0, 'action'))),
]);

/// `dict access of list of dict of utf8`: the ring's nested packet
/// (`packet_nested`).
Scheme<Row> nestedRing() => scheme(1, [
  dict('access', list('rows', dict('row', utf8Field(0, 'value')))),
]);

final rows = <String, (Scheme<Row>, Row)>{
  'ref.user': (
    userRing(),
    {
      'username': 'zxsanny',
      'roles': ['user', 'dispatcher'],
      'access': {
        'store': ['read', 'write'],
        'channel': ['read'],
        'map': ['read', 'gps_fix', 'set', 'edit'],
      },
    },
  ),
  'ref.user_ua': (
    userRing(),
    {
      'username': 'Олександр',
      'roles': ['диспетчер', 'Оператор'],
      'access': {
        'карта': ['читати', 'правити'],
        'канал': ['читати'],
      },
    },
  ),
  'ref.nested': (
    nestedRing(),
    {
      'access': {
        'map': [
          {'op': 'gps_fix'},
        ],
        'store': [
          {'op': 'read'},
          {'op': 'write'},
        ],
      },
    },
  ),
  'ref.nested_mixed': (
    nestedRing(),
    {
      'access': {
        'Карта': [
          {'op': 'gps_fix', 'note': 'увага 48.46, 35.04'},
        ],
        'store': [
          {'op': 'ЧИТАТИ'},
        ],
      },
    },
  ),
};

void main() {
  final packets = refRows();

  test('the ref rows of the text vectors are the 4 rows the test knows', () {
    // Arrange and Act
    final ids = packets.keys.toSet();

    // Assert
    expect(ids, rows.keys.toSet());
  });

  for (final entry in rows.entries) {
    final id = entry.key;
    final (layout, row) = entry.value;

    test('$id: the real scheme packs the row to the vector bytes', () {
      // Arrange
      final expected = packets[id]!;

      // Act
      final wire = pack(layout, row);

      // Assert
      expect(hex(wire), expected);
    });

    test('$id: the real scheme unpacks the vector to the row, and back', () {
      // Arrange
      final packet = packets[id]!;

      // Act
      final got = readRow(layout, packet);
      final again = pack(layout, got);

      // Assert
      expect(got, row);
      expect(hex(again), packet);
    });
  }
}
