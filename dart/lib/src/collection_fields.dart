part of 'fields.dart';

/// A field that can be the element of [list] or [dict], and that holds one
/// value of the Dart type [E]: a value field, a [list] or [dict] (whose value
/// is a `List<E>` or a `Map<String, E>`), or a nested row.
sealed class ElementField<E extends Object> extends Field {
  ElementField._(super.node) : super._();
}

/// A text of the compact text format (`utf8` in the other packages): a `String`
/// of at most 65,535 UTF-8 bytes. Named `utf8Field` because `utf8` is taken by
/// `dart:convert`. Under a flags bit it is set when the value is not null; an
/// empty string is a value (the single byte `00`).
ValueField<String> utf8Field(int id, String name) =>
    ValueField<String>._(Node(NodeKind.utf8, id: id, name: name));

/// A [list], made by [list].
final class ListField<E extends Object> extends ElementField<List<E>> {
  ListField._(super.node) : super._();

  /// This list bound to the member of the typed row [R] that holds it: a
  /// `List<E>`, null being no value. Unpack stores a `List<E>` it made.
  Field bind<R extends Object>({
    required List<E>? Function(R row) get,
    required void Function(R row, List<E> value) set,
  }) => _Plain(
    _node.copy(
      binding: Binding(
        (Object row) => get(row as R),
        (Object row, Object value) => set(row as R, value as List<E>),
        R,
        <S>() => <S>[] is List<R>,
      ),
    ),
  );
}

/// A [dict], made by [dict].
final class DictField<E extends Object> extends ElementField<Map<String, E>> {
  DictField._(super.node) : super._();

  /// This dictionary bound to the member of the typed row [R] that holds it:
  /// a `Map<String, E>`, null being no value. Unpack stores a `Map<String, E>`
  /// it made.
  Field bind<R extends Object>({
    required Map<String, E>? Function(R row) get,
    required void Function(R row, Map<String, E> value) set,
  }) => _Plain(
    _node.copy(
      binding: Binding(
        (Object row) => get(row as R),
        (Object row, Object value) => set(row as R, value as Map<String, E>),
        R,
        <S>() => <S>[] is List<R>,
      ),
    ),
  );
}

/// A nested row, made by [nested] or [nestedRow].
final class NestedField<C extends Object> extends ElementField<C> {
  NestedField._(super.node) : super._();

  /// This nested row bound to the member of the typed row [R] that holds it:
  /// a [C] made by [nestedRow], null being no value. Not for an element of a
  /// [list] or [dict]: bind the list or dictionary instead.
  Field bind<R extends Object>({
    required C? Function(R row) get,
    required void Function(R row, C value) set,
  }) => _Plain(
    _node.copy(
      binding: Binding(
        (Object row) => get(row as R),
        (Object row, Object value) => set(row as R, value as C),
        R,
        <S>() => <S>[] is List<R>,
      ),
    ),
  );
}

/// A list: a u16 count (at most 65,535), then the items. The [element] is one
/// field and a scope of its own, numbered from id 0: an integer, a float,
/// fixed bytes, [utf8Field], another [list] or [dict], or a nested row. A list
/// has no id. In a map row the value is a `List` of items (a `Uint8List` is a
/// byte run, never a list) and unpack gives a `List<Object?>`; in a typed row
/// it is bound with `bind` to a `List<E>`. An empty list is a value (count 0).
ListField<E> list<E extends Object>(String name, ElementField<E> element) =>
    ListField<E>._(
      Node(
        NodeKind.list,
        name: name,
        fields: [element._node],
        make: () => <E>[],
      ),
    );

/// A dictionary: a u16 pair count (at most 65,535), then the pairs, each a
/// text key (as [utf8Field]) and an item as for [list]. Keys are written in
/// ascending order of their UTF-8 bytes, whatever the map's order, and unpack
/// refuses a repeated or out-of-order key as `bad_value`. In a map row the
/// value is a `Map` with `String` keys and unpack gives a
/// `Map<String, Object?>`; in a typed row it is bound with `bind` to a
/// `Map<String, E>`.
DictField<E> dict<E extends Object>(String name, ElementField<E> element) =>
    DictField<E>._(
      Node(
        NodeKind.dict,
        name: name,
        fields: [element._node],
        make: () => <String, E>{},
      ),
    );

/// A nested row under [name], with [members] numbered from id 0: its ids,
/// references and names are its own, so it may repeat a name of the row around
/// it, and it takes no id of that row (the unanchored `group` of the other
/// packages). In a map row it is a `Map<String, Object?>` under [name], on
/// pack and on unpack. Under [flags] or a flag bit its bit is set when it is
/// given. It is also the element of a [list] or [dict]. It needs at least one
/// member. A typed scheme uses [nestedRow].
NestedField<Map<String, Object?>> nested(String name, List<Field> members) =>
    NestedField<Map<String, Object?>>._(
      Node(
        NodeKind.nested,
        name: name,
        fields: [for (final m in members) m._node],
        error: members.isEmpty
            ? 'nested row $name: needs at least one member'
            : null,
      ),
    );

/// A nested row of a typed scheme: unpack makes a [C] with [create], and every
/// member is bound to [C] with `bind`. In a scheme of map rows [create] is not
/// used and the row is a map, as [nested] makes it.
NestedField<C> nestedRow<C extends Object>(
  String name,
  C Function() create,
  List<Field> members,
) => NestedField<C>._(
  Node(
    NodeKind.nested,
    name: name,
    fields: [for (final m in members) m._node],
    error: members.isEmpty
        ? 'nested row $name: needs at least one member'
        : null,
    row: RowSpec(
      create,
      (Object value) => value is C,
      (check, body) => check<C>(body),
    ),
  ),
);
