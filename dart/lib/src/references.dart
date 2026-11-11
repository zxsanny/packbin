import 'errors.dart';
import 'node.dart';

/// The field a `when` or a counted kind reads, and the names of the groups
/// from the row of its place down to the row that field sits in (a typed
/// scheme has none: a typed row shares one row).
final class Reference {
  Reference(this.source, this.path);
  final Node source;
  final List<String> path;
}

/// The field each `when`, `sized`, `bits`, `packed` and `times` of [nodes]
/// reads, by that node. An `eq` or count id names an integer field (a `bool`
/// too for `eq`) read earlier in the same scope; flags, flag bits, groups and
/// `when` share the scope around them, and a `repeat` or `times` body is a
/// scope of its own, closed both ways.
Map<Node, Reference> resolveReferences(
  List<Node> nodes, {
  required bool typed,
}) {
  final sources = Map<Node, Reference>.identity();
  _resolve(nodes, {}, const [], typed, sources);
  return sources;
}

typedef _Scope = Map<int, Reference>;

void _resolve(
  List<Node> nodes,
  _Scope scope,
  List<String> path,
  bool typed,
  Map<Node, Reference> sources,
) {
  for (final n in nodes) {
    switch (n.kind) {
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
      case NodeKind.slot:
      case NodeKind.utf8:
        scope[n.id!] = Reference(n, path);
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
        sources[n] = _count(n, scope);
        scope[n.id!] = Reference(n, path);
      case NodeKind.when:
        sources[n] = Reference(
          _source(n, scope),
          scope[n.condition!.fieldId]!.path,
        );
        _resolve(n.fields, scope, path, typed, sources);
      case NodeKind.times:
        sources[n] = _count(n, scope);
        _resolve(n.fields, {}, const [], typed, sources);
      case NodeKind.repeat:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        _resolve(n.fields, {}, const [], typed, sources);
      case NodeKind.group:
        _resolve(
          n.fields,
          scope,
          typed || n.fields.isEmpty ? path : [...path, n.name],
          typed,
          sources,
        );
      case NodeKind.flags:
      case NodeKind.flagBit:
      case NodeKind.u2:
        _resolve(n.fields, scope, path, typed, sources);
      case NodeKind.flagByte:
        break;
    }
  }
}

/// The integer field [n] counts by: it must be declared earlier in the same
/// scope, and an integer (a `u2` slot counts).
Reference _count(Node n, _Scope scope) {
  final id = n.countId;
  final source = scope[id];
  PackbinException fail(String reason) => schemeFail(
    n.id,
    n.declaredName,
    '${n.label} ${n.id}: count names field id $id$reason',
  );
  if (source == null) {
    throw fail(', which is not declared earlier in the same scope');
  }
  final kind = source.source.kind;
  if (kind != NodeKind.integer && kind != NodeKind.slot) {
    throw fail(' (${source.source.name}), which is not an integer');
  }
  return source;
}

String _shown(Object value) {
  if (value is String) return '"$value"';
  if (value is num || value is bool) return '$value';
  return 'a ${value.runtimeType}';
}

int _bits(Node source) => source.kind == NodeKind.slot ? 2 : source.size * 8;

/// The whole numbers an integer source can hold, as the refusal shows them.
/// A 64-bit source holds every Dart `int`: a `u64` above 2^63 - 1 is the
/// negative `int` with the same bits, so `eq(u64, -1)` is 2^64 - 1.
(String, String) _bounds(Node source) {
  final bits = _bits(source);
  if (bits == 64) {
    return source.signed
        ? ('-9223372036854775808', '9223372036854775807')
        : ('0', '18446744073709551615');
  }
  return source.signed
      ? ('${-(1 << (bits - 1))}', '${(1 << (bits - 1)) - 1}')
      : ('0', '${(1 << bits) - 1}');
}

bool _holds(Node source, int value) {
  final bits = _bits(source);
  if (bits == 64) return true;
  return source.signed
      ? value >= -(1 << (bits - 1)) && value < 1 << (bits - 1)
      : value >= 0 && value < 1 << bits;
}

Node _source(Node when, _Scope scope) {
  final condition = when.condition!;
  final id = condition.fieldId;
  final value = condition.value;
  final source = scope[id]?.source;
  PackbinException fail(String reason) =>
      schemeFail(when.id, when.declaredName, 'when ${when.id}$reason');
  if (source == null) {
    throw fail(
      ': eq names field id $id, which is not declared earlier in the same scope',
    );
  }
  if (source.kind == NodeKind.boolean) {
    if (value != true) {
      throw fail(
        ': eq names bool field id $id (${source.name}) and accepts only true, not ${_shown(value)}',
      );
    }
  } else if (source.kind != NodeKind.integer && source.kind != NodeKind.slot) {
    throw fail(
      ': eq names field id $id (${source.name}), which is not an integer or a bool',
    );
  } else if (value is! int || !_holds(source, value)) {
    final (low, high) = _bounds(source);
    throw fail(
      ' tests ${source.label} field $id (\'${source.name}\') against ${_shown(value)}; the value must be a whole number from $low to $high',
    );
  }
  return source;
}
