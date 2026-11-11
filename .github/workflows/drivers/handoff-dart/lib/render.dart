import 'dart:convert';
import 'dart:typed_data';

import 'hex.dart';

/// A typed text of a row value, to compare rows by type and value as the Go
/// driver does with reflect.DeepEqual: each scalar with its type, a map with
/// its keys sorted, an absent round entry as nil.
String render(Object? v) {
  if (v == null) return 'nil';
  if (v is String) return 'String(${jsonEncode(v)})';
  if (v is Uint8List) return 'bytes(${hexString(v)})';
  if (v is Map) {
    if (v.isEmpty) return '{}';
    final keys = v.keys.cast<String>().toList()..sort();
    return '{${[for (final k in keys) '${jsonEncode(k)}: ${render(v[k])}'].join(', ')}}';
  }
  if (v is List) return '[${v.map(render).join(', ')}]';
  return '${v.runtimeType}($v)';
}
