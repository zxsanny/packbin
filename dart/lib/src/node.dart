import 'dart:typed_data';

/// The number of bits one flag byte holds.
const int flagBits = 8;

enum NodeKind { integer, float, bytes, boolean, flags, flagByte, flagBit, when }

/// The identity of a split-form flag byte handle.
final class FlagTag {
  FlagTag(this.name);
  final String name;
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
  }) : endian = bigEndian ? Endian.big : Endian.little;

  final NodeKind kind;

  /// The value id; the anchor of flags and when; null for a split flag byte
  /// or bit.
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

  Node copy({
    bool? bigEndian,
    List<Node>? fields,
    FlagRead? read,
    int? bit,
    int? slot,
    int? refSlot,
    Binding? binding,
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
    error: error,
  );

  /// The member a flag bit guards.
  Node get member => fields[0];

  bool get isValue =>
      kind == NodeKind.integer ||
      kind == NodeKind.float ||
      kind == NodeKind.bytes ||
      kind == NodeKind.boolean;

  /// A value field with bytes of its own.
  bool get isLeaf =>
      kind == NodeKind.integer ||
      kind == NodeKind.float ||
      kind == NodeKind.bytes;

  /// The name a field declares; a flag bit is named by its member, and a
  /// flags or when by the first name inside it.
  String get declaredName {
    if (name.isNotEmpty || kind == NodeKind.flagByte) return name;
    for (final child in fields) {
      final inner = child.declaredName;
      if (inner.isNotEmpty) return inner;
    }
    return '';
  }

  /// The id an error names: the value id or anchor; a flag bit's member's.
  int? get errorId => kind == NodeKind.flagBit ? member.errorId : id;

  String get label => switch (kind) {
    NodeKind.integer => '${signed ? 'i' : 'u'}${size * 8}',
    NodeKind.float => 'f${size * 8}',
    NodeKind.bytes => 'bytes($size)',
    NodeKind.boolean => 'bool',
    NodeKind.flags => 'flags',
    NodeKind.flagByte => 'flag byte',
    NodeKind.flagBit => 'flag bit',
    NodeKind.when => 'when',
  };
}
