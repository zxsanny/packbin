import 'dart:typed_data';

import 'counted_pack.dart';
import 'errors.dart';
import 'node.dart';
import 'unpack.dart';

extension CountedUnpack on Reader {
  /// The count [n] reads from the scope plus its bias; null when the count
  /// field was not read (a clear bit, a false `when`), is negative or is a
  /// `u64` above 2^63 - 1.
  int? readCount(Node n) {
    final raw = seen[n.refSlot];
    return raw is int ? countOf(raw, n.bias) : null;
  }

  /// The error of an item or round that reads no byte: nothing more needed,
  /// the bytes left where it starts.
  PackbinError emptyItem(int? id, String name) =>
      shortPacket(id, name, 0, left);

  /// The error of a count that has no value (its source is behind a clear bit
  /// or was never read) or is negative: a bad value of the counted field.
  PackbinError unreadable(int? id, String name) => PackbinError(
    ErrorKind.badValue,
    field: id,
    name: name,
    reason: 'the count has no value or is negative',
  );

  /// Reads a `sized`, `bits`, `packed` or `u2` into [row]; false when the
  /// packet is refused. A count is checked against the bytes left before
  /// anything is made for it, so a count from the wire sets no allocation.
  bool counted(Node n, Object row) {
    if (n.kind == NodeKind.u2) return _u2(n, row);
    final count = readCount(n);
    if (count == null) {
      error = unreadable(n.id, n.name);
      return false;
    }
    if (n.kind == NodeKind.sized) {
      if (count > left) {
        error = shortPacket(n.id, n.name, count, left);
        return false;
      }
      store(n, row, buf.sublist(off, off + count));
      off += count;
      return true;
    }
    final width = n.kind == NodeKind.bits ? 1 : n.size;
    final size = itemBytes(width, count);
    if (size > left) {
      error = shortPacket(n.id, n.name, size, left);
      return false;
    }
    final items = Uint8List(count);
    final mask = (1 << width) - 1;
    for (var i = 0; i < count; i++) {
      final bit = i * width;
      items[i] = (buf[off + (bit >> 3)] >> (bit & 7)) & mask;
    }
    off += size;
    store(n, row, items);
    return true;
  }

  bool _u2(Node n, Object row) {
    final slots = n.fields;
    final size = (slots.length + 3) >> 2;
    if (size > left) {
      error = shortPacket(n.errorId, n.declaredName, size, left);
      return false;
    }
    for (var i = 0; i < slots.length; i++) {
      store(slots[i], row, (buf[off + (i >> 2)] >> ((i & 3) * 2)) & 3);
    }
    off += size;
    return true;
  }
}
