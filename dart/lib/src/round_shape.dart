import 'group_rows.dart';
import 'node.dart';

/// What a `repeat` or `times` asks of its body, worked out once when the
/// scheme is built. Nothing in it changes after, and nothing is keyed by
/// identity, so a scheme can be sent to another isolate.
final class RoundShape {
  RoundShape._(
    this.names,
    this.optional,
    this.buffers,
    this.dicts,
    this.width,
    this.place,
  );

  /// Builds the shape of a round whose members are [body].
  factory RoundShape.of(List<Node> body) {
    final names = <Node>[];
    _names(body, names, <String>{});
    final optional = <Node>[];
    _optional(body, false, optional, <String>{});
    final width = roundWidth(body);
    return RoundShape._(
      names,
      optional,
      [
        for (final n in names)
          if (n.kind == NodeKind.bytes || n.isCounted) n,
      ],
      [
        for (final n in names)
          if (n.kind == NodeKind.dict) n,
      ],
      width,
      groupPlaces(body),
    );
  }

  /// The members of one round's row in the map form, one per name, in scheme
  /// order: a value, a mark, or a group (whose members sit in its own map).
  final List<Node> names;

  /// The names a flag bit can leave absent in a round: under `flags` or a flag
  /// bit, also through a `when` below them.
  final List<Node> optional;

  /// The names whose value is itself a run of bytes or bits: one given for a
  /// round's name would reach every round, so it is refused.
  final List<Node> buffers;

  /// The `dict` names: a dictionary given once for one would reach every
  /// round, so it is refused.
  final List<Node> dicts;

  /// The slots one round charges against the slot limit: the names unpack
  /// gives one entry a round.
  final int width;

  /// The groups of a round's row, to check on pack; null when it has none.
  final GroupPlace? place;

  /// The id and name a refusal about a whole round names: its first member.
  (int?, String) member(Node round) {
    if (names.isEmpty) return (round.id, '');
    final first = names.first;
    return (first.errorId, first.name);
  }
}

void _names(List<Node> nodes, List<Node> out, Set<String> seen) {
  for (final n in nodes) {
    switch (n.kind) {
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.slot:
      case NodeKind.group:
      case NodeKind.utf8:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        if (seen.add(n.name)) out.add(n);
      case NodeKind.flags:
      case NodeKind.flagBit:
      case NodeKind.when:
      case NodeKind.u2:
        _names(n.fields, out, seen);
      case NodeKind.flagByte:
      case NodeKind.repeat:
      case NodeKind.times:
        break;
    }
  }
}

void _optional(
  List<Node> nodes,
  bool underFlag,
  List<Node> out,
  Set<String> seen,
) {
  for (final n in nodes) {
    switch (n.kind) {
      case NodeKind.flags:
      case NodeKind.flagBit:
        _optional(n.fields, true, out, seen);
      case NodeKind.when:
      case NodeKind.u2:
        _optional(n.fields, underFlag, out, seen);
      case NodeKind.flagByte:
      case NodeKind.repeat:
      case NodeKind.times:
        break;
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.slot:
      case NodeKind.group:
      case NodeKind.utf8:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        if (underFlag && seen.add(n.name)) out.add(n);
    }
  }
}

/// The slots one round of [body] charges: the distinct names it can hold, a
/// group's members flattened into the round and an empty group counted as a
/// name of its own. A nested row is a scope of its own, so it charges the
/// width of its own members apart from the names around it (as Go and
/// Swift).
int roundWidth(List<Node> body) {
  final names = <String>{};
  return _width(body, names) + names.length;
}

/// Collects the names of [nodes] into [names] and returns the slots of the
/// nested rows among them.
int _width(List<Node> nodes, Set<String> names) {
  var nested = 0;
  for (final n in nodes) {
    switch (n.kind) {
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.slot:
      case NodeKind.utf8:
      case NodeKind.list:
      case NodeKind.dict:
        names.add(n.name);
      case NodeKind.nested:
        nested += roundWidth(n.fields);
      case NodeKind.group:
        if (n.fields.isEmpty) names.add(n.name);
        nested += _width(n.fields, names);
      case NodeKind.flags:
      case NodeKind.flagBit:
      case NodeKind.when:
      case NodeKind.u2:
        nested += _width(n.fields, names);
      case NodeKind.flagByte:
      case NodeKind.repeat:
      case NodeKind.times:
        break;
    }
  }
  return nested;
}
