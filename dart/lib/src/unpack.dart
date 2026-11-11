import 'dart:typed_data';

import 'build.dart';
import 'collections_unpack.dart';
import 'errors.dart';
import 'limits.dart';
import 'counted_unpack.dart';
import 'node.dart';
import 'rounds_unpack.dart';

/// Reads one packet from its second byte. Every read checks the bytes left
/// first and records a short-packet error, so no input reaches an index out
/// of range and nothing is thrown.
final class Reader {
  Reader(Plan plan, this.buf, this.limits)
    : data = ByteData.sublistView(buf),
      end = buf.length,
      typed = plan.typed,
      seen = plan.seenCount == 0
          ? const []
          : List<Object?>.filled(plan.seenCount, null),
      _split = plan.splitCount == 0 ? null : Uint8List(plan.splitCount);

  final Uint8List buf;
  final ByteData data;
  final int end;
  final bool typed;

  /// The round and slot limits of the scheme.
  final Limits limits;

  /// What the scope has read so far for a `when` or a count to read.
  final List<Object?> seen;

  /// The slots the rounds read so far have charged against the slot limit.
  int slots = 0;
  final Uint8List? _split;

  /// The next byte to read; never above [end].
  int off = 1;

  /// Why the packet was refused; set by the read that returns false or null.
  PackbinError? error;

  int get left => end - off;

  /// Reads [nodes] into [row]; false when the packet is refused.
  bool fields(List<Node> nodes, Object row) {
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      switch (n.kind) {
        case NodeKind.integer:
        case NodeKind.float:
        case NodeKind.bytes:
        case NodeKind.utf8:
          final v = value(n);
          if (v == null) return false;
          store(n, row, v);
        case NodeKind.list:
        case NodeKind.dict:
        case NodeKind.nested:
          final v = collection(n);
          if (v == null) return false;
          store(n, row, v);
        case NodeKind.boolean:
          // Reached only through a set flag bit.
          store(n, row, true);
        case NodeKind.flags:
          if (!_flags(n, row)) return false;
        case NodeKind.flagByte:
          if (off >= end) {
            error = shortPacket(n.id, n.name, 1, 0);
            return false;
          }
          _split![n.read!.slot] = buf[off++];
        case NodeKind.flagBit:
          if (_split![n.read!.slot] & (1 << n.bit) != 0 &&
              !fields(n.fields, row)) {
            return false;
          }
        case NodeKind.when:
          if (seen[n.refSlot] == n.condition!.value && !fields(n.fields, row)) {
            return false;
          }
        case NodeKind.group:
          if (n.isMark) {
            // Reached only through a set flag bit.
            store(n, row, true);
          } else if (typed) {
            if (!fields(n.fields, row)) return false;
          } else {
            final inner = <String, Object?>{};
            (row as Map<String, Object?>)[n.name] = inner;
            if (!fields(n.fields, inner)) return false;
          }
        case NodeKind.sized:
        case NodeKind.bits:
        case NodeKind.packed:
        case NodeKind.u2:
          if (!counted(n, row)) return false;
        case NodeKind.repeat:
        case NodeKind.times:
          if (!readRounds(n, row)) return false;
        case NodeKind.slot:
          // Reached only inside a u2, which reads its slots itself.
          break;
      }
    }
    return true;
  }

  bool _flags(Node n, Object row) {
    if (off >= end) {
      error = shortPacket(n.id, '', 1, 0);
      return false;
    }
    final flags = buf[off++];
    final bits = n.fields;
    for (var i = 0; i < bits.length; i++) {
      final bit = bits[i];
      if (flags & (1 << bit.bit) == 0) continue;
      final member = bit.member;
      if (member.isLeaf) {
        final v = value(member);
        if (v == null) return false;
        store(member, row, v);
      } else if (!fields(bit.fields, row)) {
        return false;
      }
    }
    return true;
  }

  /// The value of an integer, float or fixed bytes field; null when the
  /// buffer ends inside it.
  Object? value(Node n) {
    if (n.kind == NodeKind.utf8) return readText(n.id, n.name);
    final size = n.size;
    final at = off;
    if (size > end - at) {
      error = shortPacket(n.id, n.name, size, end - at);
      return null;
    }
    off = at + size;
    switch (n.kind) {
      case NodeKind.integer:
        switch (size) {
          case 1:
            return n.signed ? data.getInt8(at) : buf[at];
          case 2:
            return n.signed
                ? data.getInt16(at, n.endian)
                : data.getUint16(at, n.endian);
          case 4:
            return n.signed
                ? data.getInt32(at, n.endian)
                : data.getUint32(at, n.endian);
          default:
            // A u64 above 2^63 - 1 is the negative int with the same bits.
            return data.getInt64(at, n.endian);
        }
      case NodeKind.float:
        return size == 4
            ? data.getFloat32(at, n.endian)
            : data.getFloat64(at, n.endian);
      default:
        return buf.sublist(at, at + size);
    }
  }

  void store(Node n, Object row, Object v) {
    if (typed) {
      n.binding!.set(row, v);
    } else {
      (row as Map<String, Object?>)[n.name] = v;
    }
    if (n.slot >= 0) seen[n.slot] = v;
  }
}

/// The row of the packet [buf], whose first byte is already matched to the
/// scheme of [plan], or the error that refuses it.
(Object?, PackbinError?) readRow(Plan plan, Uint8List buf, Limits limits) {
  final reader = Reader(plan, buf, limits);
  final create = plan.create;
  final Object row = create == null ? <String, Object?>{} : create();
  if (!reader.fields(plan.fields, row)) return (null, reader.error);
  if (reader.left > 0) {
    return (null, PackbinError(ErrorKind.trailing, left: reader.left));
  }
  return (row, null);
}
