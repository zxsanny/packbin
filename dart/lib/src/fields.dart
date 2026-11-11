import 'dart:typed_data';

import 'node.dart';

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
final class ValueField<V extends Object> extends Field {
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

/// A field of [node], for the helpers of other files.
Field fieldOf(Node node) => _Plain(node);

/// A value field of [node], for the helpers of other files.
ValueField<V> valueFieldOf<V extends Object>(Node node) =>
    ValueField<V>._(node);

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

/// A split-form flag byte named [name].
FlagByte flagByte(String name) => FlagByte._(name, FlagTag(name));

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
