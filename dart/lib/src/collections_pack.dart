import 'dart:typed_data';

import 'errors.dart';
import 'group_rows.dart';
import 'node.dart';
import 'pack.dart';
import 'text/text.dart';
import 'utf8_order.dart';

/// The most items a list or dict holds: a u16 count.
const int maxItems = 65535;

extension CollectionPack on Packer {
  /// Writes the text [v] as the compact text field of the field [id] (named
  /// [name]); a value that is not a `String`, a text with an unpaired surrogate
  /// and a text over 65,535 UTF-8 bytes are refused.
  void writeText(int? id, String name, Object v) {
    if (v is! String) {
      throw packFail(
        id,
        name,
        'expected a String for utf8, got ${v.runtimeType}',
      );
    }
    final Uint8List field;
    try {
      field = encodeText(v, textCache ??= TextCache());
    } on TextEncodeException catch (e) {
      throw packFail(id, name, switch (e.problem) {
        TextEncodeProblem.loneSurrogate =>
          '$name: the text holds an unpaired surrogate at unit ${e.detail}',
        TextEncodeProblem.tooLong =>
          '$name: the text is ${e.detail} UTF-8 bytes, above the limit of $maxTextBytes',
      });
    }
    out.bytes(field);
  }

  /// Packs the list, dict or nested row [n] the row [row] gives a value for.
  void packCollection(Node n, Object row) {
    final v = value(n, row);
    if (v == null) throw packFail(n.id, n.name, 'missing ${n.name}');
    switch (n.kind) {
      case NodeKind.list:
        _list(n, v);
      case NodeKind.dict:
        _dict(n, v);
      default:
        _nested(n, v, n.name);
    }
  }

  void _list(Node n, Object v) {
    if (v is! List<Object?> || (!typed && v is Uint8List)) {
      throw packFail(
        null,
        n.name,
        '${n.name}: expected a list, got ${v.runtimeType}',
      );
    }
    final count = v.length;
    if (count > maxItems) {
      throw packFail(
        null,
        n.name,
        '${n.name}: the list holds $count items, above the limit of $maxItems',
      );
    }
    out.integer(count, 2, false, Endian.little);
    final e = n.fields[0];
    for (var i = 0; i < count; i++) {
      _item(n, e, v[i], i);
    }
  }

  void _dict(Node n, Object v) {
    if (v is! Map) {
      throw packFail(
        null,
        n.name,
        '${n.name}: expected a dictionary, got ${v.runtimeType}',
      );
    }
    final count = v.length;
    if (count > maxItems) {
      throw packFail(
        null,
        n.name,
        '${n.name}: the dictionary holds $count pairs, above the limit of $maxItems',
      );
    }
    final keys = <String>[];
    var i = 0;
    for (final k in v.keys) {
      if (k is! String) {
        throw packFail(
          null,
          n.name,
          '${n.name}[$i]: the key is a ${k.runtimeType}, expected a String',
        );
      }
      keys.add(k);
      i++;
    }
    // By the bytes of the keys, never String.compareTo: UTF-16 order differs
    // from UTF-8 order above U+FFFF.
    keys.sort(compareUtf8);
    out.integer(count, 2, false, Endian.little);
    final e = n.fields[0];
    for (final k in keys) {
      writeText(null, n.name, k);
      _item(n, e, v[k], k);
    }
  }

  /// One item of the list or dict [owner]: [at] is its index, or its key.
  void _item(Node owner, Node e, Object? item, Object at) {
    final where = '${owner.name}[$at]';
    if (item == null) throw packFail(null, owner.name, '$where: no value');
    switch (e.kind) {
      case NodeKind.list:
        _guard(owner, where, () => _list(e, item));
      case NodeKind.dict:
        _guard(owner, where, () => _dict(e, item));
      case NodeKind.nested:
        _nested(e, item, where);
      default:
        _guard(owner, where, () => write(e, item));
    }
  }

  /// Runs [body]; a refusal of the item is named by the list or dict [owner]
  /// and the item [where].
  void _guard(Node owner, String where, void Function() body) {
    try {
      body();
    } on PackbinException catch (x) {
      throw packFail(null, owner.name, '$where: ${x.reason}');
    }
  }

  /// A nested row [item] in a scope of its own: the slots its references use
  /// are clear, and its flag bytes and groups read its row.
  void _nested(Node e, Object item, String where) {
    if (typed) {
      if (!e.row!.isRow(item)) {
        throw packFail(
          null,
          e.name,
          '$where: expected a nested row, got ${item.runtimeType}',
        );
      }
    } else if (item is! Map<String, Object?>) {
      throw packFail(
        null,
        e.name,
        '$where: expected a Map<String, Object?>, got ${item.runtimeType}',
      );
    }
    final outer = placeRow;
    placeRow = item;
    if (e.slotHi > e.slotLo) seen.fillRange(e.slotLo, e.slotHi, null);
    final place = e.place;
    if (place != null && !typed) {
      checkGroupRows(place, item as Map<String, Object?>);
    }
    fields(e.fields, item);
    placeRow = outer;
  }
}
