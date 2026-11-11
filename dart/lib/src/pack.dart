import 'dart:typed_data';

import 'build.dart';
import 'collections_pack.dart';
import 'counted_pack.dart';
import 'errors.dart';
import 'group_rows.dart';
import 'limits.dart';
import 'node.dart';
import 'rounds_pack.dart';
import 'text/text.dart';
import 'writer.dart';

/// The packet of [row]: the type byte, then the fields in order.
Uint8List packRow(Plan plan, int typeNumber, Object row, Limits limits) {
  if (!plan.isRow(row)) {
    final first = plan.fields.isEmpty ? null : plan.fields.first;
    throw packFail(
      first?.errorId,
      first?.declaredName ?? '',
      'the row is a ${row.runtimeType}; this scheme packs a ${plan.rowType}',
    );
  }
  final groups = plan.groups;
  if (groups != null) {
    checkGroupRows(groups, row as Map<String, Object?>);
  }
  final packer = Packer(plan, typeNumber, row, limits);
  packer.fields(plan.fields, row);
  return packer.out.take();
}

/// One pack call: the bytes so far, what the scope has written for a `when`
/// to test, and the split flag bytes written (where each sits, its bits).
final class Packer {
  Packer(Plan plan, int typeNumber, this.placeRow, this.limits)
    : out = Writer(typeNumber, limits.maxBytes),
      typed = plan.typed,
      seen = plan.seenCount == 0
          ? const []
          : List<Object?>.filled(plan.seenCount, null),
      _split = plan.splitCount == 0 ? null : Int32List(plan.splitCount * 2);

  final Writer out;

  /// The round, slot and byte limits of the scheme.
  final Limits limits;

  /// The row of the place being packed: the row the groups of a map scheme
  /// are found from. The split flag bytes of the place read their bits there.
  /// A round is a place of its own: it is the round's row while it is packed.
  Object placeRow;

  /// The slots the rounds of this call have charged against the slot limit.
  int charged = 0;

  /// The last text this call encoded, made when the first text is written.
  TextCache? textCache;
  final bool typed;
  final List<Object?> seen;
  final Int32List? _split;

  /// The value the row gives for [n]; null is no value.
  Object? value(Node n, Object row) =>
      typed ? n.binding!.get(row) : (row as Map<String, Object?>)[n.name];

  /// The row the members of the group [n] are read from: the map under its
  /// name (an empty one when the row does not give it); a typed row has one
  /// row for the group and the fields around it.
  Object groupRow(Node n, Object row) {
    if (typed) return row;
    final given = (row as Map<String, Object?>)[n.name];
    return given is Map<String, Object?> ? given : const <String, Object?>{};
  }

  /// The row a split bit's member is read from: the row of its place, then
  /// the maps of the groups the bit sits in.
  Object bitRow(Node bit) {
    var row = placeRow;
    for (final name in bit.path) {
      final given = (row as Map<String, Object?>)[name];
      row = given is Map<String, Object?> ? given : const <String, Object?>{};
    }
    return row;
  }

  /// Whether the condition of the `when` [n] holds on what was written.
  bool holds(Node n) => seen[n.refSlot] == n.condition!.value;

  void fields(List<Node> nodes, Object row) {
    var i = 0;
    try {
      for (; i < nodes.length; i++) {
        final n = nodes[i];
        switch (n.kind) {
          case NodeKind.integer:
          case NodeKind.float:
          case NodeKind.bytes:
          case NodeKind.utf8:
            final v = value(n, row);
            if (v == null) throw packFail(n.id, n.name, 'missing ${n.name}');
            write(n, v);
          case NodeKind.list:
          case NodeKind.dict:
          case NodeKind.nested:
            packCollection(n, row);
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
          case NodeKind.group:
            // A mark is reached only through a set flag bit: the bit is the value.
            if (n.fields.isNotEmpty) fields(n.fields, groupRow(n, row));
          case NodeKind.sized:
          case NodeKind.u2:
          case NodeKind.bits:
          case NodeKind.packed:
            packCounted(n, row);
          case NodeKind.repeat:
            packRepeat(n, row);
          case NodeKind.times:
            packTimes(n, row);
          case NodeKind.slot:
            // Reached only inside a u2, which writes its slots itself.
            break;
        }
      }
    } on ByteBudgetExceeded catch (e) {
      final n = nodes[i];
      throw packFail(
        n.errorId,
        n.declaredName,
        '${n.declaredName}: the packet would be ${e.need} bytes, above the limit of ${e.limit} bytes',
      );
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
      } else {
        _refuseWhenOff(member, row);
      }
    }
    out.patch(at, flags);
  }

  /// A split flag byte decides all its bits where it sits.
  void _splitByte(Node n, Object row) {
    final read = n.read!;
    var flags = 0;
    for (final bit in read.bits) {
      if (bitOn(bit.member, bitRow(bit))) flags |= 1 << bit.bit;
    }
    final split = _split!;
    split[read.slot * 2] = out.length;
    split[read.slot * 2 + 1] = flags;
    out.byte(flags);
  }

  /// A clear bit of a combined flags drops nothing silently: a `times` whose
  /// count is not written, or a count the row gives that no field wrote, is
  /// refused.
  void _refuseWhenOff(Node member, Object row) {
    final held = _held(member, row);
    if (held != null && countNeverWritten(member, row)) {
      throw packFail(
        held.id,
        held.name,
        '${held.name}: a value is given, but the count of its times is not written, so its bit is clear; write the count before the times',
      );
    }
    refuseUnwrittenCount(member, row);
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
      refuseUnwrittenCount(n.member, row);
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
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.slot:
      case NodeKind.utf8:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        return value(member, row) != null;
      case NodeKind.repeat:
        return repeatOn(member, row);
      case NodeKind.times:
        return timesOn(member, row);
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
      case NodeKind.u2:
        return _anyOn(member.fields, row);
      case NodeKind.group:
        if (member.isMark) {
          final v = value(member, row);
          if (v == null) return false;
          if (v is! bool) {
            throw packFail(
              member.id,
              member.name,
              'expected a bool for group ${member.name}, got ${v.runtimeType}',
            );
          }
          return v;
        }
        // The map under its name sets the bit by being given; a group not
        // given is still on for a `times` whose count is above 0, which must
        // write its rounds (TypeScript and Go refuse its missing values). A
        // typed row's group is on when a member holds a value.
        if (typed) return _anyOn(member.fields, row);
        return (row as Map<String, Object?>)[member.name] != null ||
            _anyOn(member.fields, const <String, Object?>{});
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
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.slot:
      case NodeKind.utf8:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        return value(member, row) != null ? member : null;
      case NodeKind.repeat:
      case NodeKind.times:
        return roundHeld(member, row);
      case NodeKind.boolean:
        return value(member, row) == true ? member : null;
      case NodeKind.flagByte:
        return null;
      case NodeKind.flags:
      case NodeKind.flagBit:
      case NodeKind.when:
      case NodeKind.u2:
        for (final child in member.fields) {
          final held = _held(child, row);
          if (held != null) return held;
        }
        return null;
      case NodeKind.group:
        if (member.isMark) return value(member, row) == true ? member : null;
        if (!typed) {
          if ((row as Map<String, Object?>)[member.name] != null) return member;
          return null;
        }
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
    if (held == null) return null;
    return bitOn(member, row) || countNeverWritten(member, row) ? held : null;
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
      case NodeKind.utf8:
        writeText(n.id, n.name, v);
      case NodeKind.boolean:
      case NodeKind.flags:
      case NodeKind.flagByte:
      case NodeKind.flagBit:
      case NodeKind.when:
      case NodeKind.group:
      case NodeKind.sized:
      case NodeKind.u2:
      case NodeKind.slot:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.repeat:
      case NodeKind.times:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        throw packFail(n.errorId, n.declaredName, '${n.label} takes no value');
    }
  }
}
