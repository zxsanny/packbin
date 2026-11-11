import 'dart:typed_data';

import 'build.dart';
import 'errors.dart';
import 'node.dart';
import 'writer.dart';

/// The packet of [row]: the type byte, then the fields in order.
Uint8List packRow(Plan plan, int typeNumber, Object row) {
  if (!plan.isRow(row)) {
    final first = plan.fields.isEmpty ? null : plan.fields.first;
    throw packFail(
      first?.errorId,
      first?.declaredName ?? '',
      'the row is a ${row.runtimeType}; this scheme packs a ${plan.rowType}',
    );
  }
  final packer = Packer(plan, typeNumber);
  packer.fields(plan.fields, row);
  return packer.out.take();
}

/// One pack call: the bytes so far, what the scope has written for a `when`
/// to test, and the split flag bytes written (where each sits, its bits).
final class Packer {
  Packer(Plan plan, int typeNumber)
    : out = Writer(typeNumber),
      typed = plan.typed,
      seen = plan.seenCount == 0
          ? const []
          : List<Object?>.filled(plan.seenCount, null),
      _split = plan.splitCount == 0 ? null : Int32List(plan.splitCount * 2);

  final Writer out;
  final bool typed;
  final List<Object?> seen;
  final Int32List? _split;

  /// The value the row gives for [n]; null is no value.
  Object? value(Node n, Object row) =>
      typed ? n.binding!.get(row) : (row as Map<String, Object?>)[n.name];

  /// Whether the condition of the `when` [n] holds on what was written.
  bool holds(Node n) => seen[n.refSlot] == n.condition!.value;

  void fields(List<Node> nodes, Object row) {
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      switch (n.kind) {
        case NodeKind.integer:
        case NodeKind.float:
        case NodeKind.bytes:
          final v = value(n, row);
          if (v == null) throw packFail(n.id, n.name, 'missing ${n.name}');
          write(n, v);
        case NodeKind.boolean:
          // Reached only through a set flag bit: the bit is the value.
          if (n.slot >= 0) seen[n.slot] = true;
        case NodeKind.flags:
          _flags(n, row);
        case NodeKind.flagByte:
          _splitByte(n, row);
        case NodeKind.flagBit:
          _splitBit(n, row);
        case NodeKind.when:
          if (holds(n)) fields(n.fields, row);
      }
    }
  }

  /// A combined flags: each bit is decided as its member is reached, so a
  /// `when` member sees what the members before it wrote.
  void _flags(Node n, Object row) {
    final at = out.length;
    out.byte(0);
    var flags = 0;
    final bits = n.fields;
    for (var i = 0; i < bits.length; i++) {
      final bit = bits[i];
      final member = bit.member;
      if (member.isLeaf) {
        final v = value(member, row);
        if (v == null) continue;
        flags |= 1 << bit.bit;
        write(member, v);
      } else if (bitOn(member, row)) {
        flags |= 1 << bit.bit;
        fields(bit.fields, row);
      }
    }
    out.patch(at, flags);
  }

  /// A split flag byte decides all its bits where it sits.
  void _splitByte(Node n, Object row) {
    final read = n.read!;
    var flags = 0;
    for (final bit in read.bits) {
      if (bitOn(bit.member, row)) flags |= 1 << bit.bit;
    }
    final split = _split!;
    split[read.slot * 2] = out.length;
    split[read.slot * 2 + 1] = flags;
    out.byte(flags);
  }

  void _splitBit(Node n, Object row) {
    final split = _split!;
    final slot = n.read!.slot * 2;
    // A byte this call did not write (it sits in a when that is false) has no bits.
    if (split[slot] == 0) return;
    final flags = split[slot + 1];
    if (flags & (1 << n.bit) == 0) {
      // A body whose condition is written only after the byte would be
      // dropped without a word, and its own unpack reads no bit for it.
      final dropped = _dropped(n.member, row);
      if (dropped != null) {
        throw packFail(
          dropped.id,
          dropped.name,
          '${dropped.name}: a value is given, but the condition or count of its when or times is not written '
          'before the flag byte, so its bit is clear; write that field before the flag byte',
        );
      }
      return;
    }
    fields(n.fields, row);
  }

  /// A flag bit is on when its member holds a value at any depth. A bool is
  /// on only for `true`; a `when` when its condition holds on what was
  /// written so far and its body holds a value.
  bool bitOn(Node member, Object row) {
    switch (member.kind) {
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
        return value(member, row) != null;
      case NodeKind.boolean:
        final v = value(member, row);
        if (v == null) return false;
        if (v is! bool) {
          throw packFail(
            member.id,
            member.name,
            'expected a bool for ${member.name}, got ${v.runtimeType}',
          );
        }
        return v;
      case NodeKind.flagByte:
        return false;
      case NodeKind.when:
        return holds(member) && _anyOn(member.fields, row);
      case NodeKind.flags:
      case NodeKind.flagBit:
        return _anyOn(member.fields, row);
    }
  }

  bool _anyOn(List<Node> nodes, Object row) {
    for (final n in nodes) {
      if (bitOn(n, row)) return true;
    }
    return false;
  }

  /// The first field under [member] the row gives a value for, at any depth
  /// and whatever its `when` says; null when it holds none.
  Node? _held(Node member, Object row) {
    switch (member.kind) {
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
        return value(member, row) != null ? member : null;
      case NodeKind.boolean:
        return value(member, row) == true ? member : null;
      case NodeKind.flagByte:
        return null;
      case NodeKind.flags:
      case NodeKind.flagBit:
      case NodeKind.when:
        for (final child in member.fields) {
          final held = _held(child, row);
          if (held != null) return held;
        }
        return null;
    }
  }

  /// The value a clear split bit would drop although a look at what is
  /// written by now would write it; a `when` that is false stays a silent
  /// skip.
  Node? _dropped(Node member, Object row) {
    final held = _held(member, row);
    return held != null && bitOn(member, row) ? held : null;
  }

  void write(Node n, Object v) {
    switch (n.kind) {
      case NodeKind.integer:
        if (v is! int) {
          throw packFail(
            n.id,
            n.name,
            'expected an integer for ${n.label}, got ${v.runtimeType}',
          );
        }
        final size = n.size;
        if (size < 8) {
          final bits = size * 8;
          final min = n.signed ? -(1 << (bits - 1)) : 0;
          final max = n.signed ? (1 << (bits - 1)) - 1 : (1 << bits) - 1;
          if (v < min || v > max) {
            throw packFail(n.id, n.name, '$v does not fit in ${n.label}');
          }
        }
        out.integer(v, size, n.signed, n.endian);
        if (n.slot >= 0) seen[n.slot] = v;
      case NodeKind.float:
        if (v is! num) {
          throw packFail(
            n.id,
            n.name,
            'expected a number for ${n.label}, got ${v.runtimeType}',
          );
        }
        final x = v.toDouble();
        if (n.size == 8) {
          out.float64(x, n.endian);
        } else if (!out.float32(x, n.endian)) {
          throw packFail(n.id, n.name, '$x does not fit in f32');
        }
      case NodeKind.bytes:
        if (v is! Uint8List) {
          throw packFail(
            n.id,
            n.name,
            'expected a Uint8List for ${n.label}, got ${v.runtimeType}',
          );
        }
        if (v.length != n.size) {
          throw packFail(
            n.id,
            n.name,
            'expected ${n.size} bytes, got ${v.length}',
          );
        }
        out.bytes(v);
      case NodeKind.boolean:
      case NodeKind.flags:
      case NodeKind.flagByte:
      case NodeKind.flagBit:
      case NodeKind.when:
        throw packFail(n.errorId, n.declaredName, '${n.label} takes no value');
    }
  }
}
