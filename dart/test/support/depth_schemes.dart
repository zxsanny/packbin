import 'package:packbin/packbin.dart';

typedef Row = Map<String, Object?>;

/// The text every depth refusal carries (contract `scheme-depth.md`), as the
/// package's scheme error prints it (no field and no name).
const String depthRefusal =
    'packbin: invalid scheme: scheme nested too deep: more than 256 levels; '
    'the limit is 256';

/// `u8 a`, then [depth] nested `when(a == 1)`, the innermost holding `u8 b`.
/// Written by a loop, innermost first, so no test recurses.
List<Field> whenChain(int depth) {
  var inner = <Field>[u8(1, 'b')];
  for (var i = 0; i < depth; i++) {
    inner = [when(1, eq(0, 1), inner)];
  }
  return [u8(0, 'a'), ...inner];
}

/// [depth] nested rows named `g` (a nested row's names are its own), the
/// innermost holding `u8 b`.
List<Field> groupChain(int depth) {
  var inner = <Field>[u8(0, 'b')];
  for (var i = 0; i < depth; i++) {
    inner = [nested('g', inner)];
  }
  return inner;
}

/// The row of [groupChain]: `{g: {g: ... {b: 7}}}`, [depth] deep.
Row groupRow(int depth) {
  Row row = {'b': 7};
  for (var i = 0; i < depth; i++) {
    row = {'g': row};
  }
  return row;
}

/// A scheme [depth] levels deep that alternates a nested row and the list (or
/// dictionary) that holds it as its element, innermost first: the row `item`
/// holding `u8 b` is level 1, the collection `g` around it level 2, the row
/// around that level 3, and so on. Returns the fields and the row they pack.
(List<Field>, Row) elementChain(int depth, {required bool dictForm}) {
  Field field = nested('item', [u8(0, 'b')]);
  Object value = <String, Object?>{'b': 7};
  for (var level = 2; level <= depth; level++) {
    if (level.isEven) {
      final element = field as ElementField<Row>;
      field = dictForm ? dict('g', element) : list('g', element);
      value = dictForm ? <String, Object?>{'k': value} : <Object?>[value];
    } else {
      field = nested('item', [field]);
      value = <String, Object?>{'g': value};
    }
  }
  return ([field], {depth.isEven ? 'g' : 'item': value});
}
