import 'dart:typed_data';

import 'group_rows.dart';
import 'round_shape.dart';

/// The number of bits one flag byte holds.
const int flagBits = 8;

enum NodeKind {
  integer,
  float,
  bytes,
  boolean,
  flags,
  flagByte,
  flagBit,
  when,
  group,
  sized,
  u2,
  slot,
  bits,
  packed,
  repeat,
  times,
  utf8,
  list,
  dict,
  nested,
}

/// The identity of a split-form flag byte handle.
final class FlagTag {
  FlagTag();
}

/// One read of a split-form flag byte in a built scheme. `slot` indexes the
/// per-call flag state; `bits` are the flag bits bound to this read. Both are
/// filled while the scheme is built and never change after.
final class FlagRead {
  FlagRead(this.name, this.slot);
  final String name;
  final int slot;
  final List<Node> bits = [];
}

/// The condition of `when`, made by `eq`.
final class Condition {
  /// A condition on the field with id [fieldId] equal to [value].
  const Condition(this.fieldId, this.value);

  /// The id of the field that is tested.
  final int fieldId;

  /// The value the field must equal.
  final Object value;
}

/// Binds a value field to a member of a typed row.
final class Binding {
  Binding(this.get, this.set, this.rowType, this.fits);

  /// The member's value for pack; null is no value.
  final Object? Function(Object row) get;

  /// Stores a value unpack read (the Dart type of its field).
  final void Function(Object row, Object value) set;
  final Type rowType;

  /// Whether a row of type `S` can be given to `get` and `set`.
  final bool Function<S>() fits;
}

/// Binds the member of a typed row that holds the rounds of a `repeat` or
/// `times`: one element of the row type [rowType]'s element a round.
final class RoundBinding {
  RoundBinding(
    this.create,
    this.get,
    this.set,
    this.newList,
    this.rowType,
    this.fits,
    this.checkBody,
  );

  /// Makes the row one round unpack read fills.
  final Object Function() create;

  /// The rounds of the row; null is no value (no round).
  final List<Object>? Function(Object row) get;

  /// Stores the list [newList] made, filled by unpack.
  final void Function(Object row, List<Object> rounds) set;

  /// An empty list of the element type, for unpack to fill.
  final List<Object> Function() newList;

  /// The row type the member belongs to.
  final Type rowType;

  /// Whether a row of type `S` can be given to `get` and `set`.
  final bool Function<S>() fits;

  /// Calls `check` for the body with the element type as its type argument.
  final void Function(
    void Function<S extends Object>(List<Node> body) check,
    List<Node> body,
  )
  checkBody;
}

/// A typed row made by `nestedRow`: how unpack makes one, what the row type
/// is, and how its members are checked against it.
final class RowSpec {
  RowSpec(this.create, this.isRow, this.checkBody);

  /// Makes the row unpack fills.
  final Object Function() create;

  /// Whether a value is a row of this type.
  final bool Function(Object value) isRow;

  /// Calls `check` for the members with the row type as its type argument.
  final void Function(
    void Function<S extends Object>(List<Node> body) check,
    List<Node> body,
  )
  checkBody;
}

/// One field. Constructors make it and a scheme makes changed copies, never
/// changing one, so a field can be shared by any number of schemes.
final class Node {
  Node(
    this.kind, {
    this.id,
    this.name = '',
    this.size = 0,
    this.signed = false,
    this.bigEndian = false,
    this.fields = const [],
    this.handle,
    this.read,
    this.bit = 0,
    this.condition,
    this.slot = -1,
    this.refSlot = -1,
    this.binding,
    this.error,
    this.path = const [],
    this.countId = -1,
    this.bias = 0,
    this.refNode,
    this.refPath = const [],
    this.slotLo = 0,
    this.slotHi = 0,
    this.shape,
    this.roundBinding,
    this.make,
    this.row,
    this.place,
    this.minItem = 1,
  }) : endian = bigEndian ? Endian.big : Endian.little;

  final NodeKind kind;

  /// The value id; the anchor of flags, when and group; null for a split flag
  /// byte or bit.
  final int? id;
  final String name;

  /// Bytes of an integer, a float or fixed bytes.
  final int size;
  final bool signed;
  final bool bigEndian;
  final Endian endian;

  /// When members; a flag bit's one member; a built flags: its flag bits in
  /// bit order (a declared flags: its members).
  final List<Node> fields;

  /// A declared split flag byte or bit: the handle it was made from.
  final FlagTag? handle;

  /// A built split flag byte or bit: the read it belongs to.
  final FlagRead? read;

  /// Flag bit: its number in the byte.
  final int bit;
  final Condition? condition;

  /// An integer or bool a when tests: where pack and unpack keep its value
  /// for the call; -1 when no when names it.
  final int slot;

  /// When: the slot of the field `eq` names.
  final int refSlot;
  final Binding? binding;

  /// A constructor's refusal, reported when the scheme is built.
  final String? error;

  /// A split flag bit of a map scheme: the names of the groups from the row
  /// of its place down to the row the bit's member is read from.
  final List<String> path;

  /// The id of the earlier integer a `sized`, `bits`, `packed` or `times`
  /// counts by.
  final int countId;

  /// `packed`: the bias added to the count, 0 or -1; `size` is its width.
  final int bias;

  /// A built `when` or counted kind: the field it reads, and the names of the
  /// groups from the row of its place down to the row that field sits in.
  final Node? refNode;
  final List<String> refPath;

  /// A built round: the slots its body numbers, `slotLo` up to `slotHi`; they
  /// are cleared when each round starts.
  final int slotLo;
  final int slotHi;

  /// A built round: what the map form and the limits ask of its body.
  final RoundShape? shape;

  /// A `repeat` or `times` bound to a member of a typed row.
  final RoundBinding? roundBinding;

  /// A `list` or `dict`: makes the empty container of its element type that a
  /// typed row holds (`List<E>` or `Map<String, E>`).
  final Object Function()? make;

  /// A `nested` made by `nestedRow`: the typed row.
  final RowSpec? row;

  /// A built `nested` row of a map scheme: the groups of its own map.
  final GroupPlace? place;

  /// A built `list` or `dict`: the fewest bytes one item takes, at least 1,
  /// which a count from the wire is compared with the bytes left.
  final int minItem;

  Node copy({
    bool? bigEndian,
    List<Node>? fields,
    FlagRead? read,
    int? bit,
    int? slot,
    int? refSlot,
    Binding? binding,
    String? error,
    List<String>? path,
    Node? refNode,
    List<String>? refPath,
    int? slotLo,
    int? slotHi,
    RoundShape? shape,
    RoundBinding? roundBinding,
    GroupPlace? place,
    int? minItem,
  }) => Node(
    kind,
    id: id,
    name: name,
    size: size,
    signed: signed,
    bigEndian: bigEndian ?? this.bigEndian,
    fields: fields ?? this.fields,
    handle: handle,
    read: read ?? this.read,
    bit: bit ?? this.bit,
    condition: condition,
    slot: slot ?? this.slot,
    refSlot: refSlot ?? this.refSlot,
    binding: binding ?? this.binding,
    error: error ?? this.error,
    path: path ?? this.path,
    countId: countId,
    bias: bias,
    refNode: refNode ?? this.refNode,
    refPath: refPath ?? this.refPath,
    slotLo: slotLo ?? this.slotLo,
    slotHi: slotHi ?? this.slotHi,
    shape: shape ?? this.shape,
    roundBinding: roundBinding ?? this.roundBinding,
    make: make,
    row: row,
    place: place ?? this.place,
    minItem: minItem ?? this.minItem,
  );

  /// The member a flag bit guards.
  Node get member => fields[0];

  bool get isValue =>
      kind == NodeKind.integer ||
      kind == NodeKind.float ||
      kind == NodeKind.bytes ||
      kind == NodeKind.boolean ||
      kind == NodeKind.sized ||
      kind == NodeKind.bits ||
      kind == NodeKind.packed ||
      kind == NodeKind.slot ||
      kind == NodeKind.utf8;

  /// A `repeat` or `times`.
  bool get isRound => kind == NodeKind.repeat || kind == NodeKind.times;

  /// A `sized`, `bits` or `packed`: a value whose length is an earlier integer.
  bool get isCounted =>
      kind == NodeKind.sized ||
      kind == NodeKind.bits ||
      kind == NodeKind.packed;

  /// A group with no member: a presence mark like a bool, set only by `true`.
  bool get isMark => kind == NodeKind.group && fields.isEmpty;

  /// A `list` or `dict`.
  bool get isCollection => kind == NodeKind.list || kind == NodeKind.dict;

  /// A value field with bytes of its own.
  bool get isLeaf =>
      kind == NodeKind.integer ||
      kind == NodeKind.float ||
      kind == NodeKind.bytes ||
      kind == NodeKind.utf8;

  /// The name a field declares; a flag bit is named by its member, and a
  /// flags or when by the first name inside it. A round with no name inside
  /// is named by its kind and anchor, as `repeat 0`.
  String get declaredName {
    if (name.isNotEmpty || kind == NodeKind.flagByte) return name;
    for (final child in fields) {
      final inner = child.declaredName;
      if (inner.isNotEmpty) return inner;
    }
    return isRound ? '$label $id' : '';
  }

  /// The id an error names: the value id or anchor; a flag bit's member's.
  int? get errorId => switch (kind) {
    NodeKind.flagBit => member.errorId,
    NodeKind.u2 => fields.isEmpty ? null : fields[0].id,
    _ => id,
  };

  String get label => switch (kind) {
    NodeKind.integer => '${signed ? 'i' : 'u'}${size * 8}',
    NodeKind.float => 'f${size * 8}',
    NodeKind.bytes => 'bytes($size)',
    NodeKind.boolean => 'bool',
    NodeKind.flags => 'flags',
    NodeKind.flagByte => 'flag byte',
    NodeKind.flagBit => 'flag bit',
    NodeKind.when => 'when',
    NodeKind.group => 'group',
    NodeKind.sized => 'sized',
    NodeKind.u2 || NodeKind.slot => 'u2',
    NodeKind.bits => 'bits',
    NodeKind.packed => 'packed',
    NodeKind.repeat => 'repeat',
    NodeKind.times => 'times',
    NodeKind.utf8 => 'utf8',
    NodeKind.list => 'list',
    NodeKind.dict => 'dict',
    NodeKind.nested => 'nested row',
  };
}
