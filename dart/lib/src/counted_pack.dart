import 'dart:typed_data';

import 'errors.dart';
import 'node.dart';
import 'pack.dart';
import 'rounds_pack.dart';

/// The count [raw] plus [bias], or null when the field cannot count: a
/// negative value (a `u64` above 2^63 - 1 is one: it is never wrapped).
int? countOf(int raw, int bias) {
  if (raw < 0) return null;
  final count = raw + bias;
  return count < 0 ? null : count;
}

/// [raw] plus [bias] as text, exact for a `u64` above 2^63 - 1.
String shownCount(int raw, int bias, Node source) {
  if (raw < 0 && !source.signed && source.size == 8) {
    return (BigInt.from(raw).toUnsigned(64) + BigInt.from(bias)).toString();
  }
  return '${raw + bias}';
}

/// The bytes [count] items of [width] bits take, without overflow for any
/// count.
int itemBytes(int width, int count) {
  final shift = width == 2 ? 2 : 3;
  final rest = count & ((1 << shift) - 1);
  return (count >> shift) + (rest == 0 ? 0 : 1);
}

/// Whether [v] is the list of rounds of a name: a list that is not a byte run.
bool isRoundList(Object? v) => v is List<Object?> && v is! Uint8List;

extension CountedPack on Packer {
  /// The id and name a refusal about [n] names: a round by its first member.
  (int?, String) _member(Node n) =>
      n.isRound ? n.shape!.member(n) : (n.id, n.name);

  /// The count pack wrote in the scope for [n] plus the bias of `packed`. A
  /// count field that was skipped or absent was not written, and unpack would
  /// not read it either.
  int borrowedCount(Node n) {
    final (id, name) = _member(n);
    final label = n.isRound ? 'times' : n.name;
    final raw = seen[n.refSlot];
    if (raw == null) {
      throw packFail(
        id,
        name,
        '$label: count ${n.refNode!.name} was not written',
      );
    }
    final count = raw is int ? countOf(raw, n.bias) : null;
    if (count == null) {
      throw packFail(
        id,
        name,
        '$label: item count ${raw is int ? shownCount(raw, n.bias, n.refNode!) : raw}',
      );
    }
    return count;
  }

  /// Packs a `sized`, `bits`, `packed` or `u2`.
  void packCounted(Node n, Object row) {
    switch (n.kind) {
      case NodeKind.sized:
        _sized(n, row);
      case NodeKind.u2:
        _u2(n, row);
      default:
        _items(n, row);
    }
  }

  void _sized(Node n, Object row) {
    final count = borrowedCount(n);
    final v = value(n, row);
    if (v == null) throw packFail(n.id, n.name, 'missing ${n.name}');
    if (v is! Uint8List) {
      throw packFail(
        n.id,
        n.name,
        'expected a Uint8List for sized, got ${v.runtimeType}',
      );
    }
    if (v.length != count) {
      throw packFail(n.id, n.name, 'expected $count bytes, got ${v.length}');
    }
    out.bytes(v);
  }

  /// A `bits` or `packed` list: [count] items of the width, low bits first.
  void _items(Node n, Object row) {
    final count = borrowedCount(n);
    final v = value(n, row);
    if (v == null) throw packFail(n.id, n.name, 'missing ${n.name}');
    if (v is! List<Object?>) {
      throw packFail(
        n.id,
        n.name,
        'expected a list of ints for ${n.label}, got ${v.runtimeType}',
      );
    }
    if (v.length != count) {
      throw packFail(
        n.id,
        n.name,
        '${n.name}: expected $count items for ${n.label}, got ${v.length}',
      );
    }
    final width = n.kind == NodeKind.bits ? 1 : n.size;
    final top = (1 << width) - 1;
    final at = out.reserve(itemBytes(width, count));
    for (var i = 0; i < count; i++) {
      final item = v[i];
      if (item is! int || item < 0 || item > top) {
        throw packFail(
          n.id,
          n.name,
          '${n.name}: item $i is ${item ?? 'no value'}; expected 0..$top',
        );
      }
      final bit = i * width;
      out.or(at + (bit >> 3), item << (bit & 7));
    }
  }

  void _u2(Node n, Object row) {
    final slots = n.fields;
    final at = out.reserve((slots.length + 3) >> 2);
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final v = value(slot, row);
      if (v is! int || v < 0 || v > 3) {
        throw packFail(
          slot.id,
          slot.name,
          '${slot.name}: expected a 2-bit integer 0..3, got ${v ?? 'no value'}',
        );
      }
      out.or(at + (i >> 2), v << ((i & 3) * 2));
      if (slot.slot >= 0) seen[slot.slot] = v;
    }
  }

  /// The value the row gives for the count field of [n], read from the row of
  /// the place along the groups that hold it; null when the row gives none.
  Object? rowCount(Node n) {
    final source = n.refNode!;
    if (typed) return source.binding?.get(placeRow);
    var map = placeRow as Map<String, Object?>;
    for (final name in n.refPath) {
      final given = map[name];
      if (given is! Map<String, Object?>) return null;
      map = given;
    }
    return map[source.name];
  }

  /// Refuses a `times`, `bits`, `packed` or `sized` in the scope of [field]
  /// (itself, or under groups, flags, flag bits and a `when` whose condition
  /// holds) whose count the row gives above 0 although no field wrote it,
  /// which is what a clear `when` that holds the count leaves: the bit is
  /// clear and nothing is read, so the count the row gives would mean nothing.
  void refuseUnwrittenCount(Node field, Object row) {
    switch (field.kind) {
      case NodeKind.times:
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
        if (seen[field.refSlot] != null) return;
        final raw = rowCount(field);
        if (raw is! int) return;
        final source = field.refNode!;
        final count = countOf(raw, field.bias);
        // A negative count of a signed source is no count; an unsigned
        // 64-bit one above 2^63 - 1 is a count above 0.
        final huge = raw < 0 && !source.signed && source.size == 8;
        if (!huge && (count == null || count == 0)) return;
        final shown = shownCount(raw, 0, source);
        final given =
            'the count ${source.name} is $shown in the row, but no field wrote it (the when that holds it is clear)';
        const fix = 'give the count 0, leave it out, or make the when hold';
        if (field.isRound) {
          final (id, name) = field.shape!.member(field);
          throw packFail(
            id,
            name,
            '$name: $given, so its times reads no round; $fix',
          );
        }
        throw packFail(
          field.id,
          field.name,
          '${field.name}: $given, so the member reads nothing; $fix',
        );
      case NodeKind.when:
        if (!holds(field)) return;
        for (final child in field.fields) {
          refuseUnwrittenCount(child, row);
        }
      case NodeKind.group:
        if (field.isMark) return;
        final inner = groupRow(field, row);
        for (final child in field.fields) {
          refuseUnwrittenCount(child, inner);
        }
      case NodeKind.flags:
      case NodeKind.flagBit:
        for (final child in field.fields) {
          refuseUnwrittenCount(child, row);
        }
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
      case NodeKind.flagByte:
      case NodeKind.u2:
      case NodeKind.slot:
      case NodeKind.repeat:
      case NodeKind.utf8:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        return;
    }
  }

  /// Whether a `times` in the scope of [field] (itself, or under groups,
  /// flags, flag bits and a `when` whose condition holds) holds a value
  /// although its count was never written.
  bool countNeverWritten(Node field, Object row) {
    switch (field.kind) {
      case NodeKind.times:
        return seen[field.refSlot] == null && roundHeld(field, row) != null;
      case NodeKind.when:
        if (!holds(field)) return false;
        return field.fields.any((c) => countNeverWritten(c, row));
      case NodeKind.group:
        if (field.isMark) return false;
        final inner = groupRow(field, row);
        return field.fields.any((c) => countNeverWritten(c, inner));
      case NodeKind.flags:
      case NodeKind.flagBit:
        return field.fields.any((c) => countNeverWritten(c, row));
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
      case NodeKind.flagByte:
      case NodeKind.sized:
      case NodeKind.u2:
      case NodeKind.slot:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.repeat:
      case NodeKind.utf8:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        return false;
    }
  }
}
