import 'counted_unpack.dart';
import 'dict_map.dart';
import 'errors.dart';
import 'node.dart';
import 'text/text.dart';
import 'unpack.dart';
import 'utf8_order.dart';

extension CollectionUnpack on Reader {
  /// The text field at the cursor, for the field [id] (named [name]); null
  /// when it is refused. A buffer that ends inside it is short with the bytes
  /// needed; a payload that breaks a rule of the format is a short packet with
  /// `needed` 0 (as TypeScript, Go and Swift), `left` the bytes from the start
  /// of the field.
  String? readText(int? id, String name) {
    switch (decodeText(buf, off)) {
      case TextValue(:final value, :final next):
        off = next;
        return value;
      case TextFailure(:final needed, :final left):
        error = shortPacket(id, name, needed, left);
        return null;
    }
  }

  /// Reads the list, dict or nested row [n]; null when the packet is refused.
  /// A count is compared with the bytes left before anything is made for it,
  /// so a count from the wire sets no allocation.
  Object? collection(Node n) {
    if (n.kind == NodeKind.nested) return _nested(n);
    if (left < 2) {
      error = shortPacket(null, n.name, 2, left);
      return null;
    }
    final count = buf[off] | (buf[off + 1] << 8);
    off += 2;
    final needed = count * n.minItem;
    if (needed > left) {
      error = shortPacket(null, n.name, needed, left);
      return null;
    }
    final e = n.fields[0];
    if (n.kind == NodeKind.list) {
      final items = typed ? n.make!() as List<Object?> : <Object?>[];
      for (var i = 0; i < count; i++) {
        final before = off;
        final v = _item(e);
        if (v == null) return null;
        if (off == before) {
          // An item that reads nothing would be repeated up to 65,535 times
          // for no input.
          error = emptyItem(null, n.name);
          return null;
        }
        items.add(v);
      }
      return items;
    }
    final items = typed
        ? n.make!() as Map<String, Object?>
        : newDict<Object?>();
    String? previous;
    for (var i = 0; i < count; i++) {
      final key = readText(null, n.name);
      if (key == null) return null;
      // Strictly ascending by UTF-8 bytes: an equal key is a repeat, a
      // smaller one is out of order; both are a short packet with `needed`
      // and `left` 0, as TypeScript, Go and Swift.
      if (previous != null && compareUtf8(key, previous) <= 0) {
        error = shortPacket(null, n.name, 0, 0);
        return null;
      }
      previous = key;
      final before = off;
      final v = _item(e);
      if (v == null) return null;
      if (off == before) {
        error = emptyItem(null, n.name);
        return null;
      }
      items[key] = v;
    }
    return items;
  }

  Object? _item(Node e) =>
      e.kind == NodeKind.list ||
          e.kind == NodeKind.dict ||
          e.kind == NodeKind.nested
      ? collection(e)
      : value(e);

  /// A nested row: a row of its own, in a scope of its own.
  Object? _nested(Node n) {
    if (n.slotHi > n.slotLo) seen.fillRange(n.slotLo, n.slotHi, null);
    final Object row = typed ? n.row!.create() : <String, Object?>{};
    return fields(n.fields, row) ? row : null;
  }
}
