import 'dart:collection';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/timing.dart';

/// The VM's string hash (one-at-a-time, unseeded): two blocks that reach the
/// same state from a given state keep every key that holds either of them in
/// one bucket. The tests check the premise on the keys they make.
int _step(int h, int unit) {
  h = (h + unit) & 0xffffffff;
  h = (h + (h << 10)) & 0xffffffff;
  return h ^ (h >>> 6);
}

int _after(int state, String block) {
  for (final unit in block.codeUnits) {
    state = _step(state, unit);
  }
  return state;
}

/// The two 4-letter blocks that take [state] to one state.
(String, String) _collidingBlocks(int state) {
  const letters = 'abcdefghijklmnopqrstuvwxyz';
  final seen = <int, String>{};
  for (var i = 0; i < 26 * 26 * 26 * 26; i++) {
    final block =
        letters[i % 26] +
        letters[(i ~/ 26) % 26] +
        letters[(i ~/ 676) % 26] +
        letters[i ~/ 17576];
    final reached = _after(state, block);
    final earlier = seen[reached];
    if (earlier != null) return (earlier, block);
    seen[reached] = block;
  }
  throw StateError('no two blocks reach one state');
}

/// 2^[stages] keys of 4 * [stages] letters with one [String.hashCode],
/// ascending.
List<String> collidingKeys(int stages) {
  var keys = <String>[''];
  var state = 0;
  for (var i = 0; i < stages; i++) {
    final (a, b) = _collidingBlocks(state);
    state = _after(state, a);
    keys = [
      for (final prefix in keys) ...[prefix + a, prefix + b],
    ];
  }
  keys.sort();
  return keys;
}

/// A dictionary of [keys] for pack. A hash map of colliding keys is slow to
/// fill and to read, so the row holds a tree map ordered by `compareTo`.
Map<String, Object?> dictRow(List<String> keys) => {
  'd': SplayTreeMap<String, Object?>.fromIterable(keys, value: (_) => 1),
};

/// A map that counts the keyed reads made on it: pack reads the values from
/// the entries, so a map whose keys share one hash is never looked up by key.
final class _CountingMap extends MapBase<String, Object?> {
  _CountingMap(List<String> keys)
    : _inner = SplayTreeMap<String, Object?>.fromIterable(
        keys,
        value: (_) => 1,
      );

  final SplayTreeMap<String, Object?> _inner;

  /// The keyed reads made so far.
  int lookups = 0;

  @override
  Object? operator [](Object? key) {
    lookups++;
    return _inner[key];
  }

  @override
  void operator []=(String key, Object? value) => _inner[key] = value;

  @override
  void clear() => _inner.clear();

  @override
  Iterable<String> get keys => _inner.keys;

  @override
  Iterable<MapEntry<String, Object?>> get entries => _inner.entries;

  @override
  Object? remove(Object? key) => _inner.remove(key);
}

Scheme<Map<String, Object?>> dictScheme() => scheme(1, [dict('d', u8(0, 'v'))]);

final class Holder {
  Map<String, int> d = {};
}

Scheme<Holder> typedScheme() => rowScheme<Holder>(1, Holder.new, [
  dict('d', u8(0, 'v')).bind<Holder>(get: (h) => h.d, set: (h, v) => h.d = v),
]);

/// Unpacks [wire] in this isolate and gives back the row's keys and length.
(List<String>, int) readKeys(Uint8List wire) {
  final row = unpackRow(wire, dictScheme()).row!;
  final d = row['d'] as Map<String, Object?>;
  return (d.keys.toList(), d.length);
}

void main() {
  group('R2 a dictionary of keys with one string hash', () {
    for (final stages in [13, 16]) {
      final count = stages == 16 ? 65535 : 1 << stages;

      test('$count colliding keys unpack in under a second, in order', () {
        // Arrange
        final all = collidingKeys(stages);
        final keys = all.sublist(0, count);
        expect(
          {for (final k in all) k.hashCode}.length,
          1,
          reason: 'the keys must share one String.hashCode',
        );
        final wire = pack(dictScheme(), dictRow(keys));

        // Act
        final bound = LoadBound(const Duration(seconds: 1));
        final watch = Stopwatch()..start();
        final got = unpackRow(wire, dictScheme());
        watch.stop();

        // Assert
        expect(got.error, isNull);
        final d = got.row!['d'] as Map<String, Object?>;
        expect(d.length, count);
        expect(d.keys.toList(), keys);
        expect(d[keys.first], 1);
        expect(d[keys.last], 1);
        expect(d.containsKey('${keys.last}x'), isFalse);
        expectWithin(
          watch.elapsed,
          bound,
          what: 'unpack of $count colliding keys',
        );
      });
    }

    test('a hash map of colliding keys packs without a lookup per key', () {
      // Arrange
      final keys = collidingKeys(8);
      final row = <String, Object?>{'d': _CountingMap(keys)};

      // Act
      final wire = pack(dictScheme(), row);

      // Assert
      final map = row['d']! as _CountingMap;
      final got = unpackRow(wire, dictScheme()).row!['d'] as Map;
      expect(map.lookups, 0);
      expect(got.keys.toList(), keys);
    });

    test('a typed dictionary of colliding keys keeps its element type', () {
      // Arrange
      final keys = collidingKeys(13);
      final wire = pack(dictScheme(), dictRow(keys));

      // Act
      final bound = LoadBound(const Duration(seconds: 1));
      final watch = Stopwatch()..start();
      final got = unpackRow(wire, typedScheme());
      watch.stop();

      // Assert
      expect(got.error, isNull);
      expect(got.row!.d, isA<Map<String, int>>());
      expect(got.row!.d.keys.toList(), keys);
      expect(got.row!.d.values.every((v) => v == 1), isTrue);
      expectWithin(
        watch.elapsed,
        bound,
        what: 'typed unpack of colliding keys',
      );
    });

    test('the unpacked map equals an ordinary map and packs again', () {
      // Arrange
      final layout = dictScheme();
      final wire = pack(layout, {
        'd': {'b': 2, 'a': 1, 'é': 3},
      });

      // Act
      final got = unpackRow(wire, layout).row!;

      // Assert
      expect(got, {
        'd': {'a': 1, 'b': 2, 'é': 3},
      });
      expect(pack(layout, got), wire);
    });

    test('keys come in the order of their UTF-8 bytes, not of UTF-16', () {
      // Arrange: U+FFFF sorts before U+10000 in UTF-8, after it in UTF-16
      final layout = dictScheme();
      final wire = pack(layout, {
        'd': {'\u{10000}': 1, '￿': 2, 'a': 3},
      });

      // Act
      final d = unpackRow(wire, layout).row!['d'] as Map<String, Object?>;

      // Assert
      expect(d.keys.toList(), ['a', '￿', '\u{10000}']);
      expect(d['\u{10000}'], 1);
      expect(d['￿'], 2);
      expect(d.entries.map((e) => e.value).toList(), [3, 2, 1]);
    });

    test('an unpacked dictionary crosses an isolate boundary', () async {
      // Arrange
      final keys = collidingKeys(8);
      final wire = pack(dictScheme(), dictRow(keys));

      // Act
      final (got, length) = await Isolate.run(() => readKeys(wire));
      final back = await Isolate.run(
        () => unpackRow(wire, dictScheme()).row!['d'] as Map<String, Object?>,
      );

      // Assert
      expect(got, keys);
      expect(length, keys.length);
      expect(back.keys.toList(), keys);
      expect(back[keys[7]], 1);
    });
  });
}
