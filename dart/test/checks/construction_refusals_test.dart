import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/refusal.dart';

/// One scheme the TypeScript tests refuse: what it builds, the field id and
/// name the error names, and the start of its reason.
final class Refused {
  Refused(this.name, this.build, this.field, this.member, this.reason);
  final String name;
  final Object Function() build;
  final int? field;
  final String member;
  final String reason;
}

Scheme<Map<String, Object?>> s(List<Field> fields) => scheme(1, fields);

Field n(int id, String name) => u8(id, name);

String ninth(String text) =>
    'flags: ninth bit ($text); a flag byte holds 8 bits';

const orphan = 'its flag byte is not read earlier in the same scope';
const twice =
    'declared twice in one scope; a row holds one value per name, so one would be lost';

List<Field> nine() => [for (var i = 0; i < 9; i++) n(i, 'f$i')];

final refusedRows = <Refused>[
  // scheme-constructor, bool-flag
  Refused(
    'bool outside flags',
    () => s([flagBool(0, 'on')]),
    0,
    'on',
    'bool on: allowed only directly inside flags or a flag bit',
  ),
  Refused(
    'bool in a group that is not under flags',
    () => s([
      groupOf(0, 'g', [n(0, 'n'), flagBool(1, 'inGroup')]),
    ]),
    1,
    'inGroup',
    'bool inGroup: allowed only directly inside flags or a flag bit',
  ),
  Refused(
    'bool in a group under flags',
    () => s([
      flags(0, [
        groupOf(0, 'g', [n(0, 'n'), flagBool(1, 'underFlags')]),
      ]),
    ]),
    1,
    'underFlags',
    'bool underFlags: allowed only directly inside flags or a flag bit',
  ),
  Refused(
    'bool in a when',
    () => s([
      n(0, 'k'),
      when(1, eq(0, 1), [flagBool(1, 'inWhen')]),
    ]),
    1,
    'inWhen',
    'bool inWhen: allowed only directly inside flags or a flag bit',
  ),
  Refused(
    'empty group outside flags',
    () => s([n(0, 'n'), groupOf(1, 'mark', [])]),
    1,
    'mark',
    'empty group mark: allowed only directly inside flags or a flag bit',
  ),
  Refused(
    'empty group inside a group under a flag bit',
    () {
      final m = flagByte('m');
      return s([
        m,
        m.bit(groupOf(0, 'g', [n(0, 'n'), groupOf(1, 'inner', [])])),
      ]);
    },
    1,
    'inner',
    'empty group inner: allowed only directly inside flags or a flag bit',
  ),
  // ids
  Refused(
    'wrong first field id',
    () => s([n(1, 'a')]),
    1,
    'a',
    'field id: expected 0, got 1',
  ),
  Refused(
    'a gap in the ids',
    () => s([n(0, 'a'), n(2, 'b')]),
    2,
    'b',
    'field id: expected 1, got 2',
  ),
  Refused(
    'a repeated id',
    () => s([n(0, 'a'), n(0, 'b')]),
    0,
    'b',
    'field id: expected 1, got 0',
  ),
  Refused(
    'an anchored group whose anchor is not the next id',
    () => s([
      n(0, 'a'),
      groupOf(2, 'g', [n(2, 'b')]),
    ]),
    2,
    'g',
    'field id: expected 1, got 2',
  ),
  Refused(
    'a member of a group that skips an id',
    () => s([
      groupOf(0, 'g', [n(0, 'a'), n(2, 'b')]),
    ]),
    2,
    'b',
    'field id: expected 1, got 2',
  ),
  Refused(
    'a field after a group that restarts at 0',
    () => s([
      groupOf(0, 'g', [n(0, 'a')]),
      n(0, 'b'),
    ]),
    0,
    'b',
    'field id: expected 1, got 0',
  ),
  Refused(
    'a flags anchor that is not the next id',
    () => s([
      n(0, 'a'),
      flags(2, [n(1, 'b')]),
    ]),
    2,
    'b',
    'field id: expected 1, got 2',
  ),
  // nine members
  Refused(
    'nine members of one flags',
    () => s([flags(0, nine())]),
    0,
    'f0',
    ninth('f8'),
  ),
  Refused(
    'nine bits of one flag byte read',
    () {
      final m = flagByte('m');
      return s([m, for (final f in nine()) m.bit(f)]);
    },
    8,
    'f8',
    'flag byte "m": ninth bit (f8); a flag byte holds 8 bits',
  ),
  Refused(
    'nine members of a flags inside a group',
    () => s([
      groupOf(0, 'g', [flags(0, nine())]),
    ]),
    0,
    'f0',
    ninth('f8'),
  ),
  // split bits
  Refused(
    'a bit whose byte sits in a when',
    () {
      final fb = flagByte('fb');
      return s([
        n(0, 'k'),
        when(1, eq(0, 1), [fb]),
        fb.bit(n(1, 'alpha')),
      ]);
    },
    1,
    'alpha',
    'flag bit 0 (alpha): $orphan',
  ),
  Refused(
    'a bit before its byte',
    () {
      final top = flagByte('fb');
      return s([top.bit(n(0, 'early')), top]);
    },
    0,
    'early',
    'flag bit 0 (early): $orphan',
  ),
  Refused(
    'a bit in a when before the byte',
    () {
      final fb = flagByte('fb');
      return s([
        when(0, eq(0, 1), [fb.bit(n(0, 'early'))]),
        fb,
      ]);
    },
    0,
    'early',
    'flag bit 0 (early): $orphan',
  ),
  Refused(
    'a bit and its byte in a when, the bit first',
    () {
      final fb = flagByte('fb');
      return s([
        n(0, 'k'),
        when(1, eq(0, 1), [fb.bit(n(1, 'early')), fb]),
      ]);
    },
    1,
    'early',
    'flag bit 0 (early): $orphan',
  ),
  Refused(
    'a bit whose byte is never read',
    () => s([flagByte('fb').bit(n(0, 'early'))]),
    0,
    'early',
    'flag bit 0 (early): $orphan',
  ),
  Refused(
    'a byte read inside a bit does not leak to later siblings',
    () {
      final outer = flagByte('outer');
      final inner = flagByte('inner');
      return s([
        outer,
        outer.bit(groupOf(0, 'g', [inner])),
        inner.bit(n(0, 'leaked')),
      ]);
    },
    0,
    'leaked',
    'flag bit 0 (leaked): $orphan',
  ),
  Refused(
    'a split bit inside a combined flags member whose byte is missing',
    () {
      final outer = flagByte('outer');
      final missing = flagByte('missing');
      return s([
        outer,
        outer.bit(flags(0, [missing.bit(n(0, 'nested'))])),
      ]);
    },
    0,
    'nested',
    'flag bit 0 (nested): $orphan',
  ),
  // references
  Refused(
    'a when naming a later field',
    () => s([
      when(0, eq(1, 5), [n(0, 'a')]),
      n(1, 'k'),
    ]),
    0,
    'a',
    'when 0: eq names field id 1, which is not declared earlier in the same scope',
  ),
  Refused(
    'a when naming an id nobody declared',
    () => s([
      n(0, 'k'),
      when(1, eq(9, 5), [n(1, 'a')]),
    ]),
    1,
    'a',
    'when 1: eq names field id 9, which is not declared earlier in the same scope',
  ),
  Refused(
    'a when naming its own body',
    () => s([
      when(0, eq(0, 1), [n(0, 'a')]),
    ]),
    0,
    'a',
    'when 0: eq names field id 0, which is not declared earlier in the same scope',
  ),
  Refused(
    'a when naming a field inside a later group',
    () => s([
      when(0, eq(1, 1), [n(0, 'v')]),
      groupOf(1, 'g', [n(1, 'n')]),
    ]),
    0,
    'v',
    'when 0: eq names field id 1, which is not declared earlier in the same scope',
  ),
  Refused(
    'a when naming a float',
    () => s([
      f32(0, 'x'),
      when(1, eq(0, 1), [n(1, 'a')]),
    ]),
    1,
    'a',
    'when 1: eq names field id 0 (x), which is not an integer or a bool',
  ),
  Refused(
    'a when naming fixed bytes',
    () => s([
      bytes(0, 'x', 2),
      when(1, eq(0, 1), [n(1, 'a')]),
    ]),
    1,
    'a',
    'when 1: eq names field id 0 (x), which is not an integer or a bool',
  ),
  // names
  Refused(
    'one name at one level',
    () => s([n(0, 'a'), n(1, 'a')]),
    1,
    'a',
    'member a: $twice',
  ),
  Refused(
    'a flags member named like a top-level field',
    () => s([
      n(0, 'a'),
      flags(1, [n(1, 'a')]),
    ]),
    1,
    'a',
    'member a: $twice',
  ),
  Refused(
    'an anchored group member named like an outer member',
    () => s([
      n(0, 'a'),
      groupOf(1, 'g', [n(1, 'a')]),
    ]),
    1,
    'a',
    'member a: $twice',
  ),
  Refused(
    'an outer member declared after the group',
    () => s([
      groupOf(0, 'g', [n(0, 'a')]),
      n(1, 'a'),
    ]),
    1,
    'a',
    'member a: $twice',
  ),
  Refused(
    'a group named like one of its own members',
    () => s([
      groupOf(0, 'g', [n(0, 'g')]),
    ]),
    0,
    'g',
    'member g: $twice',
  ),
  Refused(
    'a group named like a field outside it',
    () => s([
      n(0, 'g'),
      groupOf(1, 'g', [n(1, 'b')]),
    ]),
    1,
    'g',
    'member g: $twice',
  ),
  Refused(
    'two groups sharing a member name',
    () => s([
      groupOf(0, 'g', [n(0, 'x')]),
      groupOf(1, 'h', [n(1, 'x')]),
    ]),
    1,
    'x',
    'member x: $twice',
  ),
  Refused(
    'a member under flags named like a group member',
    () => s([
      groupOf(0, 'g', [n(0, 'x')]),
      flags(1, [n(1, 'x')]),
    ]),
    1,
    'x',
    'member x: $twice',
  ),
  Refused(
    'a name twice outside every when after a when that shares it',
    () => s([
      n(0, 'kind'),
      when(1, eq(0, 0), [n(1, 'shape')]),
      n(2, 'shape'),
      n(3, 'shape'),
    ]),
    3,
    'shape',
    'member shape: $twice',
  ),
  Refused(
    'a bool named like another field',
    () => s([
      n(0, 'on'),
      flags(1, [flagBool(1, 'on')]),
    ]),
    1,
    'on',
    'member on: $twice',
  ),
  Refused(
    'a split bit member named like another field',
    () {
      final m = flagByte('m');
      return s([n(0, 'a'), m, m.bit(n(1, 'a'))]);
    },
    1,
    'a',
    'member a: $twice',
  ),
];

void main() {
  group('the schemes the TypeScript tests refuse', () {
    for (final r in refusedRows) {
      test('${r.name} is refused naming the field', () {
        // Act
        final error = refusal(r.build);

        // Assert
        expect(error.field, r.field);
        expect(error.name, r.member);
        expect(error.reason, startsWith(r.reason));
        expect(
          error.toString(),
          startsWith('packbin: invalid scheme at field'),
        );
      });
    }
  });
}
