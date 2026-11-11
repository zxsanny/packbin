import 'errors.dart';
import 'node.dart';

/// A name declared only inside a group of a place, and the groups from the
/// place's row down to it.
final class Foreign {
  Foreign(this.member, this.path);
  final Node member;
  final List<Node> path;
}

/// A group of a place with the place of its own map; a mark has none.
final class GroupMember {
  GroupMember(this.node, this.place);
  final Node node;
  final GroupPlace? place;
}

/// One row of a map scheme: the top level or the map of a group with
/// members. Its members are the value fields, groups and marks at any depth
/// under flags, flag bits and `when`, outside a group of their own. Nothing
/// here is keyed by identity, so a scheme can be sent to another isolate.
final class GroupPlace {
  GroupPlace(this.groups, this.foreign);

  /// The groups (with members, or marks) whose name no other kind of field of
  /// the place declares, in scheme order.
  final List<GroupMember> groups;

  /// The names declared inside a group of the place that the place itself
  /// does not declare.
  final List<Foreign> foreign;
}

/// The place of the built [fields], or null when no field is a group.
GroupPlace? groupPlaces(List<Node> fields) {
  final top = _place(fields);
  return top.groups.isEmpty && top.foreign.isEmpty ? null : top;
}

/// The members of a place: value fields, marks and groups outside a group of
/// their own. The names inside a round are lists in the row around it, so a
/// round adds its value names only; its groups and marks are entries of its
/// own lists and belong to the round's place.
void _members(List<Node> nodes, List<Node> out, {bool inRound = false}) {
  for (final n in nodes) {
    switch (n.kind) {
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
        out.add(n);
      case NodeKind.boolean:
      case NodeKind.group:
        if (!inRound) out.add(n);
      case NodeKind.flags:
      case NodeKind.flagBit:
      case NodeKind.when:
      case NodeKind.u2:
        _members(n.fields, out, inRound: inRound);
      case NodeKind.repeat:
      case NodeKind.times:
        _members(n.fields, out, inRound: true);
      case NodeKind.flagByte:
        break;
    }
  }
}

int _class(Node n) => n.isMark || n.kind == NodeKind.boolean
    ? 2
    : n.kind == NodeKind.group
    ? 4
    : 1;

GroupPlace _place(List<Node> nodes) {
  final members = <Node>[];
  _members(nodes, members);
  final classes = <String, int>{};
  for (final m in members) {
    classes[m.name] = (classes[m.name] ?? 0) | _class(m);
  }
  final groups = <GroupMember>[];
  for (final m in members) {
    if (m.kind == NodeKind.group && classes[m.name] == _class(m)) {
      groups.add(GroupMember(m, m.isMark ? null : _place(m.fields)));
    }
  }
  final own = classes.keys.toSet();
  final seen = <String>{};
  final foreign = <Foreign>[];
  void walk(Node group, List<Node> path) {
    final here = [...path, group];
    final inside = <Node>[];
    _members(group.fields, inside);
    for (final x in inside) {
      if (!own.contains(x.name) && seen.add(x.name)) {
        foreign.add(Foreign(x, here));
      }
      if (x.kind == NodeKind.group && !x.isMark) walk(x, here);
    }
  }

  for (final m in members) {
    if (m.kind == NodeKind.group && !m.isMark) walk(m, const []);
  }
  return GroupPlace(groups, foreign);
}

/// Refuses what a map row gives for the groups of [place] that pack could not
/// read: a group that is not a map, a mark that is not a bool, and a name
/// declared only inside a group, given in the row around it while the group is
/// not given (the owner's Go-4 rule: the members of a group are in its map,
/// never flat beside it).
void checkGroupRows(GroupPlace place, Map<String, Object?> row) {
  for (final member in place.groups) {
    final g = member.node;
    final v = row[g.name];
    if (v == null) continue;
    if (g.isMark) {
      if (v is! bool) {
        throw packFail(
          g.id,
          g.name,
          'expected a bool for group ${g.name}, got ${v.runtimeType}',
        );
      }
    } else if (v is Map<String, Object?>) {
      checkGroupRows(member.place!, v);
    } else {
      throw packFail(
        g.id,
        g.name,
        'expected a Map<String, Object?> for group ${g.name}, got ${v.runtimeType}',
      );
    }
  }
  for (final f in place.foreign) {
    if (row[f.member.name] == null) continue;
    final absent = _absent(row, f.path);
    if (absent == null) continue;
    throw packFail(
      f.member.id,
      f.member.name,
      '${f.member.name} is a member of group ${absent.name}, which is not given; give the value in the group\'s Map, not in the row around it',
    );
  }
}

/// The first group on [path] the row does not give, or null.
Node? _absent(Map<String, Object?> row, List<Node> path) {
  var map = row;
  for (final g in path) {
    final v = map[g.name];
    if (v == null) return g;
    if (v is! Map<String, Object?>) return null;
    map = v;
  }
  return null;
}
