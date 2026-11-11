import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

// AZ-4199: a list or dict whose element is a nested row of required members
// writes the members one after another, with no flag byte per element. The
// bytes are the ones TypeScript writes for the same scheme (a list of groups),
// and the C# package pins the same hex for its element row.

typedef Row = Map<String, Object?>;

const empty = '010000';
const one =
    '010100'
    '03106331'
    '022aaa'
    '07000000'
    '03c91980';
const three =
    '010300'
    '03106331'
    '022aaa'
    '07000000'
    '03c91980'
    '03106332'
    '03106f6b'
    '02010000'
    '0310626f'
    '03106333'
    '03cb2200'
    '01000000'
    '03106379';
const mapped =
    '010200'
    '021061'
    '03106331'
    '022aaa'
    '07000000'
    '03c91980'
    '021062'
    '03106332'
    '03106f6b'
    '02010000'
    '0310626f';

List<Field> members() => [
  utf8Field(0, 'id'),
  utf8Field(1, 'text'),
  u32(2, 'authorId'),
  utf8Field(3, 'author'),
];

Row c1() => {'id': 'c1', 'text': 'hi', 'authorId': 7, 'author': 'ann'};
Row c2() => {'id': 'c2', 'text': 'ok', 'authorId': 258, 'author': 'bo'};
Row c3() => {'id': 'c3', 'text': 'yes', 'authorId': 1, 'author': 'cy'};

void main() {
  final listed = scheme(1, [list('items', nested('item', members()))]);
  final keyed = scheme(1, [dict('map', nested('item', members()))]);

  group('a list of nested rows writes no flag byte per element', () {
    for (final (items, wire) in [
      (<Row>[], empty),
      ([c1()], one),
      ([c1(), c2(), c3()], three),
    ]) {
      test(
        '${items.length} rows pack to the pinned bytes and unpack equal',
        () {
          final bytes = pack(listed, {'items': items});

          expect(hex(bytes), wire);
          expect(unpackRow(bytes, listed).row, {'items': items});
        },
      );
    }

    test('a dict of nested rows packs the keys in order, then the members', () {
      final bytes = pack(keyed, {
        'map': {'b': c2(), 'a': c1()},
      });

      expect(hex(bytes), mapped);
      expect(unpackRow(bytes, keyed).row, {
        'map': {'a': c1(), 'b': c2()},
      });
    });
  });
}
