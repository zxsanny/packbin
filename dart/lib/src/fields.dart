import 'dart:typed_data';

import 'dict_map.dart';
import 'node.dart';

part 'collection_fields.dart';

/// One field of a scheme, made by the helpers ([u8], [flags], [when], ...).
/// A field is immutable and can be shared by any number of schemes.
sealed class Field {
  Field._(this._node);

  final Node _node;

  Field _with(Node node) => _Plain(node);
}

final class _Plain extends Field {
  _Plain(super.node) : super._();
}

/// A field that holds one value of the Dart type [V]: `int` for the integers,
/// `double` for the floats, `Uint8List` for fixed bytes, `bool` for a flag
/// bool. In a map row the value sits under the field's name; [bind] binds it
/// to a member of a typed row instead.
final class ValueField<V extends Object> extends ElementField<V> {
  ValueField._(super.node) : super._();

  @override
  ValueField<V> _with(Node node) => ValueField<V>._(node);

  /// This field bound to a member of the typed row [R]. [get] gives the
  /// member's value for pack, null being no value; [set] stores the value
  /// unpack read, and is not called for a field that was not read. Name the
  /// row type:
  ///
  /// ```dart
  /// u16(0, 'sid').bind<Position>(get: (r) => r.sid, set: (r, v) => r.sid = v)
  /// ```
  Field bind<R extends Object>({
    required V? Function(R row) get,
    required void Function(R row, V value) set,
  }) => _Plain(
    _node.copy(
      binding: Binding(
        (Object row) => get(row as R),
        (Object row, Object value) => set(row as R, value as V),
        R,
        <S>() => <S>[] is List<R>,
      ),
    ),
  );
}

/// An anchored group, made by [groupOf].
final class GroupField extends Field {
  GroupField._(super.node) : super._();

  /// This group with no member bound to a member of the typed row [R]: [get]
  /// gives `true` to set the mark's bit, null (or `false`) leaves it clear;
  /// [set] stores `true` when unpack read the bit set. A group that has
  /// members binds those instead, so it is refused here.
  Field bind<R extends Object>({
    required bool? Function(R row) get,
    required void Function(R row, bool value) set,
  }) => _Plain(
    _node.fields.isNotEmpty
        ? _node.copy(
            error:
                'group ${_node.name}: only a group with no member binds a value; bind its members',
          )
        : _node.copy(
            binding: Binding(
              (Object row) => get(row as R),
              (Object row, Object value) => set(row as R, value as bool),
              R,
              <S>() => <S>[] is List<R>,
            ),
          ),
  );
}

/// A `repeat` or `times`, made by [repeat] and [times]. In a map row each name
/// the round holds is a list with one entry per round; [bind] binds the rounds
/// of a typed row.
final class RoundField extends Field {
  RoundField._(super.node) : super._();

  /// This round bound to the member of the typed row [R] that holds its
  /// rounds: a `List<E>` with one row of the type [E] a round. [create] makes
  /// the row of one round that unpack reads; [get] gives the rounds for pack
  /// (null is no round) and [set] stores the list unpack read. Bind the
  /// round's own members to [E]:
  ///
  /// ```dart
  /// times(1, 0, [i32(1, 'lat').bind<Point>(...)]).bind<Route, Point>(
  ///   create: Point.new, get: (r) => r.points, set: (r, v) => r.points = v)
  /// ```
  Field bind<R extends Object, E extends Object>({
    required E Function() create,
    required List<E>? Function(R row) get,
    required void Function(R row, List<E> rounds) set,
  }) => _Plain(
    _node.copy(
      roundBinding: RoundBinding(
        create,
        (Object row) => get(row as R),
        (Object row, List<Object> rounds) => set(row as R, rounds as List<E>),
        () => <E>[],
        R,
        <S>() => <S>[] is List<R>,
        (check, body) => check<E>(body),
      ),
    ),
  );
}

/// A split-form flag byte: put the handle itself in the field list where the
/// byte is read, and [bit] puts a member under its next bit. A handle can be
/// read more than once and shared by schemes.
final class FlagByte extends Field {
  FlagByte._(String name, this._tag)
    : super._(Node(NodeKind.flagByte, name: name, handle: _tag));

  final FlagTag _tag;

  /// [member] under the next bit of this flag byte, read before it in the
  /// same scope. The scheme numbers the bits when it is built.
  Field bit(Field member) =>
      _Plain(Node(NodeKind.flagBit, fields: [member._node], handle: _tag));
}

Node nodeOf(Field field) => field._node;

ValueField<int> _int(int id, String name, int size, bool signed) =>
    ValueField<int>._(
      Node(NodeKind.integer, id: id, name: name, size: size, signed: signed),
    );

/// An unsigned 8-bit integer.
ValueField<int> u8(int id, String name) => _int(id, name, 1, false);

/// An unsigned 16-bit integer, little-endian.
ValueField<int> u16(int id, String name) => _int(id, name, 2, false);

/// An unsigned 32-bit integer, little-endian.
ValueField<int> u32(int id, String name) => _int(id, name, 4, false);

/// An unsigned 64-bit integer, little-endian. A Dart `int` holds its 64 bits:
/// a value above 2^63 - 1 is the negative `int` with the same bits.
ValueField<int> u64(int id, String name) => _int(id, name, 8, false);

/// A signed 8-bit integer.
ValueField<int> i8(int id, String name) => _int(id, name, 1, true);

/// A signed 16-bit integer, little-endian.
ValueField<int> i16(int id, String name) => _int(id, name, 2, true);

/// A signed 32-bit integer, little-endian.
ValueField<int> i32(int id, String name) => _int(id, name, 4, true);

/// A signed 64-bit integer, little-endian.
ValueField<int> i64(int id, String name) => _int(id, name, 8, true);

/// An IEEE 754 single, little-endian. NaN and the infinities are written as
/// given; a finite value too large for f32 is refused.
ValueField<double> f32(int id, String name) =>
    ValueField<double>._(Node(NodeKind.float, id: id, name: name, size: 4));

/// An IEEE 754 double, little-endian.
ValueField<double> f64(int id, String name) =>
    ValueField<double>._(Node(NodeKind.float, id: id, name: name, size: 8));

/// Exactly [size] raw bytes, with no length.
ValueField<Uint8List> bytes(int id, String name, int size) =>
    ValueField<Uint8List>._(
      Node(
        NodeKind.bytes,
        id: id,
        name: name,
        size: size < 0 ? 0 : size,
        error: size < 0 ? 'bytes size $size: expected 0 or more' : null,
      ),
    );

/// A flag bit with no payload (`bool` in the other packages), set only for
/// `true`. It stands only directly under [flags] or a flag byte's bit.
ValueField<bool> flagBool(int id, String name) =>
    ValueField<bool>._(Node(NodeKind.boolean, id: id, name: name));

/// That integer or float, big-endian; any other field is returned as it is.
T be<T extends Field>(T field) {
  final n = field._node;
  switch (n.kind) {
    case NodeKind.integer:
    case NodeKind.float:
      return field._with(n.copy(bigEndian: true)) as T;
    case NodeKind.flagBit:
      return field._with(n.copy(fields: [be(_Plain(n.member))._node])) as T;
    case NodeKind.bytes:
    case NodeKind.boolean:
    case NodeKind.flags:
    case NodeKind.flagByte:
    case NodeKind.when:
    case NodeKind.group:
    case NodeKind.sized:
    case NodeKind.u2:
    case NodeKind.slot:
    case NodeKind.bits:
    case NodeKind.packed:
    case NodeKind.repeat:
    case NodeKind.times:
    case NodeKind.utf8:
    case NodeKind.list:
    case NodeKind.dict:
    case NodeKind.nested:
      return field;
  }
}

/// One byte in front of its [members]: bit i is member i, a set bit writes
/// that member, a clear bit skips it. At most 8 members. The [anchor] is the
/// next id and is not written.
Field flags(int anchor, List<Field> members) {
  final nodes = [for (final m in members) m._node];
  final error = nodes.length > flagBits
      ? 'flags: ninth bit (${nodes[flagBits].declaredName}); a flag byte holds $flagBits bits'
      : null;
  return _Plain(Node(NodeKind.flags, id: anchor, fields: nodes, error: error));
}

/// An anchored group: [members] under the one [name]. It writes no byte of
/// its own and shares the ids and the scope of the fields around it, so the
/// [anchor] is the next id and a `when` or a flag byte outside it can name or
/// read what is inside. In a map row the members are a `Map<String, Object?>`
/// under [name], on pack and on unpack; a member given in the row around it
/// while the group is not given is refused. In a typed row the members are
/// bound to the same row as the fields around the group. Under [flags] or a
/// flag byte's bit the group's bit is set when the map is given (a typed row:
/// when a member holds a value). A group with no member is a presence mark:
/// it stands only directly under [flags] or a flag byte's bit, and `true`
/// sets its bit.
///
/// Named `groupOf` because `group` is taken by `package:test`.
GroupField groupOf(int anchor, String name, List<Field> members) =>
    GroupField._(
      Node(
        NodeKind.group,
        id: anchor,
        name: name,
        fields: [for (final m in members) m._node],
      ),
    );

/// A split-form flag byte named [name].
FlagByte flagByte(String name) => FlagByte._(name, FlagTag());

/// True when the integer or bool field [fieldId], read earlier in the same
/// scope, equals [value] (an `int`, or `true` for a bool field).
Condition eq(int fieldId, Object value) => Condition(fieldId, value);

/// The [members] only when [condition] holds on what was written (pack) or
/// read (unpack). The [anchor] is the next id and is not written.
Field when(int anchor, Condition condition, List<Field> members) => _Plain(
  Node(
    NodeKind.when,
    id: anchor,
    fields: [for (final m in members) m._node],
    condition: condition,
  ),
);

/// Raw bytes whose length is the earlier integer [countId]; there is no
/// length of its own.
ValueField<Uint8List> sized(int id, String name, int countId) =>
    ValueField<Uint8List>._(
      Node(NodeKind.sized, id: id, name: name, countId: countId),
    );

/// One 2-bit slot (0 to 3) of a [u2], with the field id [id].
ValueField<int> slot(int id, String name) =>
    ValueField<int>._(Node(NodeKind.slot, id: id, name: name));

/// Fixed 2-bit [slots] (made by [slot], bound or not), four to a byte, low
/// bits first; the last byte's unused bits are 0. Needs at least one slot.
Field u2(List<Field> slots) {
  final nodes = [for (final s in slots) s._node];
  final other = nodes.where((n) => n.kind != NodeKind.slot).firstOrNull;
  final error = nodes.isEmpty
      ? 'u2 needs at least one slot'
      : other != null
      ? 'u2: ${other.declaredName} is not a slot; make the members with slot'
      : null;
  return _Plain(Node(NodeKind.u2, fields: nodes, error: error));
}

/// A list of 0 and 1 (`List<int>`); the item count is the earlier integer
/// [countId], and the list holds exactly that many items.
ValueField<List<int>> bits(int id, String name, int countId) =>
    ValueField<List<int>>._(
      Node(NodeKind.bits, id: id, name: name, countId: countId),
    );

/// A list of small integers [width] bits each (1 or 2), with no length of its
/// own; the item count is the earlier integer [countId] plus [bias] (0 or -1).
ValueField<List<int>> packed(
  int width,
  int id,
  String name,
  int countId, {
  int bias = 0,
}) => ValueField<List<int>>._(
  Node(
    NodeKind.packed,
    id: id,
    name: name,
    size: width,
    countId: countId,
    bias: bias,
    error: width != 1 && width != 2
        ? 'packed width $width: expected 1 or 2'
        : bias != 0 && bias != -1
        ? 'packed bias $bias: expected 0 or -1'
        : null,
  ),
);

/// The [members] as a round, repeated until the packet ends; there is no
/// count, so it must be the last thing the packet reads. A scheme is refused
/// when it is built if a field that can write a byte stands after the repeat
/// (also after the `when`, `flags`, flag bit, group or nested row that holds
/// it), or if the repeat sits inside a [list] or [dict] element or a round;
/// use [times] there, which has a count. A round is one entry of each of its
/// names' lists in a map row. The [anchor] is the next id and is not written.
RoundField repeat(int anchor, List<Field> members) => RoundField._(
  Node(NodeKind.repeat, id: anchor, fields: [for (final m in members) m._node]),
);

/// The [members] as a round, exactly as many times as the earlier integer
/// [countId] says, then the next field. The [anchor] is the next id and is
/// not written.
RoundField times(int anchor, int countId, List<Field> members) => RoundField._(
  Node(
    NodeKind.times,
    id: anchor,
    countId: countId,
    fields: [for (final m in members) m._node],
  ),
);
