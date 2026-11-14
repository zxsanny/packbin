import 'errors.dart';
import 'node.dart';

/// The construction checks that look at the declared fields only, in
/// TypeScript's order: a constructor's refusal, the ids, the presence marks
/// and the member names. The references are checked in `references.dart`.

/// The most containers one path of a scheme may hold (contract
/// `scheme-depth.md`).
const int maxSchemeDepth = 256;

/// Whether the nodes of [kind] hold fields of their own: a level of nesting.
bool _isContainer(NodeKind kind) => switch (kind) {
  NodeKind.flags ||
  NodeKind.flagBit ||
  NodeKind.when ||
  NodeKind.group ||
  NodeKind.repeat ||
  NodeKind.times ||
  NodeKind.list ||
  NodeKind.dict ||
  NodeKind.nested => true,
  _ => false,
};

/// Refuses a scheme nested more than [maxSchemeDepth] levels: the most
/// containers on one path from the top to a field. It runs first, with a
/// stack of its own, so every later walk, which recurses once per level,
/// sees at most [maxSchemeDepth] levels.
void checkDepth(List<Node> declared) {
  final nodes = [...declared];
  final depths = List<int>.filled(nodes.length, 0, growable: true);
  while (nodes.isNotEmpty) {
    final n = nodes.removeLast();
    final level = depths.removeLast() + (_isContainer(n.kind) ? 1 : 0);
    if (level > maxSchemeDepth) {
      throw schemeFail(
        null,
        '',
        'scheme nested too deep: more than $maxSchemeDepth levels; the limit '
            'is $maxSchemeDepth',
      );
    }
    for (final child in n.fields) {
      nodes.add(child);
      depths.add(level);
    }
  }
}

/// Reports a constructor's refusal at any depth.
void checkErrors(List<Node> nodes) {
  for (final n in nodes) {
    final error = n.error;
    if (error != null) throw schemeFail(n.errorId, n.declaredName, error);
    checkErrors(n.fields);
  }
}

/// A slot belongs to a [u2]: standing anywhere else it would write nothing.
void checkSlots(List<Node> nodes, {bool inU2 = false}) {
  for (final n in nodes) {
    if (n.kind == NodeKind.slot && !inU2) {
      throw schemeFail(
        n.id,
        n.name,
        'slot ${n.name}: stands only inside u2; put it in a u2',
      );
    }
    checkSlots(n.fields, inU2: n.kind == NodeKind.u2);
  }
}

/// Every value id and anchor is the next id, from [next] on: a gap, a repeated
/// id or an anchor that is not the next id is refused, naming the id. An
/// anchor takes no id of its own, so the field after an empty group has the
/// group's id.
int checkIds(List<Node> nodes, int next) {
  for (final n in nodes) {
    // An empty `nested` is a mark that takes no id of the row around it.
    if (n.isMark && n.id == null) continue;
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
        if (n.id != next) {
          throw schemeFail(
            n.id,
            n.name,
            'field id: expected $next, got ${n.id}',
          );
        }
        next++;
      case NodeKind.flags:
      case NodeKind.when:
      case NodeKind.group:
      case NodeKind.repeat:
      case NodeKind.times:
        if (n.id != next) {
          throw schemeFail(
            n.id,
            n.declaredName,
            'field id: expected $next, got ${n.id}',
          );
        }
        next = checkIds(n.fields, next);
      case NodeKind.flagBit:
      case NodeKind.u2:
        next = checkIds(n.fields, next);
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        // An element or a nested row is a scope of its own: its ids start at
        // 0 and the row around it gives none to it.
        checkIds(n.fields, 0);
      case NodeKind.flagByte:
        break;
    }
  }
  return next;
}

/// A round packs entry i of each list a round name holds, so a `repeat` or
/// `times` inside one would read every inner round from the same entry. It is
/// refused wherever it sits in the round: directly, or under `when`, `flags`,
/// flag bits and groups.
void checkNesting(List<Node> nodes, {bool inRound = false}) {
  for (final n in nodes) {
    if (n.isRound) {
      if (inRound) {
        throw schemeFail(
          n.id,
          n.declaredName,
          '${n.label} ${n.id} is inside a repeat or times round; a round cannot hold another repeat or times',
        );
      }
      checkNesting(n.fields, inRound: true);
    } else if (n.isCollection || n.kind == NodeKind.nested) {
      // Its items are rows of their own, so a round in them is a round of
      // that row, not of the round around.
      checkNesting(n.fields);
    } else {
      checkNesting(n.fields, inRound: inRound);
    }
  }
}

/// A round of a body with no member charges no slot and writes no byte, so a
/// count of 65,535 would loop for no output and no limit could stop it. A
/// member is any field but a container (`when`, group) that holds none, so a
/// body of only empty containers is empty too. A zero-width `bytes`, a flag
/// byte or a `flags` without members is a member: it names a slot or writes a
/// byte, so the limits still bound it.
void checkBodies(List<Node> nodes) {
  for (final n in nodes) {
    if (n.isRound && !_holdsMember(n.fields)) {
      throw schemeFail(
        n.id,
        n.declaredName,
        '${n.label} ${n.id}: the body holds no member; a round of it would charge no slot and write nothing',
      );
    }
    checkBodies(n.fields);
  }
}

bool _holdsMember(List<Node> nodes) {
  for (final n in nodes) {
    switch (n.kind) {
      case NodeKind.when:
      case NodeKind.group:
      case NodeKind.repeat:
      case NodeKind.times:
      case NodeKind.flagBit:
        if (_holdsMember(n.fields)) return true;
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
      case NodeKind.flags:
      case NodeKind.flagByte:
      case NodeKind.sized:
      case NodeKind.u2:
      case NodeKind.slot:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.utf8:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        return true;
    }
  }
  return false;
}

const _readsToTheEnd = 'a repeat reads to the end of the packet';

/// A `repeat` has no count on the wire: unpack reads rounds until the buffer
/// ends, so whatever a packet holds after a repeat is read as more rounds of
/// it. Refused when the scheme is built: a repeat that a field which can write
/// a byte follows, in its own place or after the `when`, `flags`, flag bit,
/// group or nested row that holds it, up to the top level; a repeat inside a
/// list or dict element, which the next element follows; and a repeat inside
/// a nested row of a round, which the next round follows ([checkNesting] has
/// refused a repeat that a round holds in any other way). It looks at the
/// scheme only, never at a row, and walks it once: the cost follows the size
/// of the scheme, whatever its shape. A scheme that breaks the rule in two
/// places is refused for the first one in document order, the body of a repeat
/// before the field after it.
void checkRepeatLast(List<Node> nodes) => _RepeatLast().walk(nodes, null);

final class _RepeatLast {
  /// What each `when`, group, nested row, flag bit and round writes first,
  /// worked out once: every list above a node asks for it.
  final Map<Node, Node?> _held = Map.identity();

  /// Walks [nodes]. [after] is the first field that can write a byte after
  /// the place [nodes] stand in.
  void walk(
    List<Node> nodes,
    Node? after, {
    bool inElement = false,
    bool inRound = false,
  }) {
    final next = _followers(nodes, after);
    for (var i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      switch (n.kind) {
        case NodeKind.repeat:
          _repeat(n, next[i + 1], inElement, inRound);
        case NodeKind.times:
          walk(n.fields, null, inRound: true);
        case NodeKind.when:
        case NodeKind.flags:
        case NodeKind.flagBit:
        case NodeKind.group:
        case NodeKind.nested:
          walk(n.fields, next[i + 1], inElement: inElement, inRound: inRound);
        case NodeKind.list:
        case NodeKind.dict:
          walk(n.fields, null, inElement: true);
        case NodeKind.integer:
        case NodeKind.float:
        case NodeKind.bytes:
        case NodeKind.boolean:
        case NodeKind.flagByte:
        case NodeKind.sized:
        case NodeKind.u2:
        case NodeKind.slot:
        case NodeKind.bits:
        case NodeKind.packed:
        case NodeKind.utf8:
          break;
      }
    }
  }

  void _repeat(Node n, Node? follower, bool inElement, bool inRound) {
    if (inElement) {
      throw schemeFail(
        n.id,
        n.declaredName,
        'repeat ${n.id} is inside a list or dict element; $_readsToTheEnd, so another element cannot follow it; use times',
      );
    }
    if (inRound) {
      throw schemeFail(
        n.id,
        n.declaredName,
        'repeat ${n.id} is inside a repeat or times round; $_readsToTheEnd, so another round cannot follow it; use times',
      );
    }
    walk(n.fields, null, inRound: true);
    if (follower != null) {
      throw schemeFail(
        n.id,
        n.declaredName,
        'repeat ${n.id}: ${_writerName(follower)} follows it; $_readsToTheEnd, so nothing can follow it; use times',
      );
    }
  }

  /// `result[i]` is the first field of [nodes], from index i on, that can
  /// write a byte for some row, else [after]; `result[nodes.length]` is
  /// [after].
  List<Node?> _followers(List<Node> nodes, Node? after) {
    final next = List<Node?>.filled(nodes.length + 1, after);
    for (var i = nodes.length - 1; i >= 0; i--) {
      next[i] = _writer(nodes[i]) ?? next[i + 1];
    }
    return next;
  }

  /// The first field that can write a byte for some row in [n], or null. A
  /// bool is a bit of a flag byte written earlier and a zero-width `bytes`
  /// has no byte. A `when`, a group, a nested row and a flag bit write what
  /// they hold, so the field found is the one inside them; a `repeat` or
  /// `times` whose body can write a byte is found itself. Everything else
  /// writes: a flag byte and a `flags`, a list and a dict (their count) too.
  Node? _writer(Node n) {
    switch (n.kind) {
      case NodeKind.boolean:
        return null;
      case NodeKind.bytes:
        return n.size > 0 ? n : null;
      case NodeKind.when:
      case NodeKind.group:
      case NodeKind.nested:
      case NodeKind.flagBit:
      case NodeKind.repeat:
      case NodeKind.times:
        if (_held.containsKey(n)) return _held[n];
        Node? found;
        for (final child in n.fields) {
          found = _writer(child);
          if (found != null) break;
        }
        if (n.isRound && found != null) found = n;
        return _held[n] = found;
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.flags:
      case NodeKind.flagByte:
      case NodeKind.sized:
      case NodeKind.u2:
      case NodeKind.slot:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.utf8:
      case NodeKind.list:
      case NodeKind.dict:
        return n;
    }
  }
}

/// The words a refusal names the field after a repeat by: the member name, as
/// the other scheme errors do (a `u2` by its first slot); a `repeat` or
/// `times` by its kind and anchor; a flag byte by its name, and the byte of a
/// `flags` as `flags`.
String _writerName(Node n) => switch (n.kind) {
  NodeKind.repeat || NodeKind.times => '${n.label} ${n.id}',
  NodeKind.flags => 'flags',
  NodeKind.flagByte => 'flag byte "${n.name}"',
  _ => n.declaredName,
};

/// A bool or an empty group is a presence mark: it has no bytes, only a flag
/// bit, so it stands only as the member of a flag bit. Anywhere else it would
/// always read true.
void checkMarks(List<Node> nodes, bool onFlagBit) {
  for (final n in nodes) {
    final mark = n.kind == NodeKind.boolean
        ? 'bool'
        : n.isMark
        ? 'empty group'
        : null;
    if (mark != null && !onFlagBit) {
      throw schemeFail(
        n.id,
        n.name,
        '$mark ${n.name}: allowed only directly inside flags or a flag bit; move it into flags',
      );
    }
    checkMarks(n.fields, n.kind == NodeKind.flagBit);
  }
}

/// A row holds one value per name. A group, `when`, `flags` and a flag bit
/// share the place around them, and a group's own name belongs to that place
/// too, so a name declared twice there is refused, unless all but one of its
/// declarations sit under a `when` (the branches of a chain may share a
/// member).
void checkNames(List<Node> nodes) {
  final always = <String, bool>{};

  void declare(Node n, bool conditional) {
    final first = always[n.name];
    if (first == null) {
      always[n.name] = !conditional;
      return;
    }
    if (conditional) return;
    if (first) {
      throw schemeFail(
        n.id,
        n.name,
        'member ${n.name}: declared twice in one scope; a row holds one value per name, so one would be lost',
      );
    }
    always[n.name] = true;
  }

  void walk(List<Node> list, bool conditional) {
    for (final n in list) {
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
          declare(n, conditional);
        case NodeKind.list:
        case NodeKind.dict:
        case NodeKind.nested:
          declare(n, conditional);
          // The names of an element or a nested row are its own.
          checkNames(n.fields);
        case NodeKind.group:
          declare(n, conditional);
          walk(n.fields, conditional);
        case NodeKind.when:
          walk(n.fields, true);
        case NodeKind.flags:
        case NodeKind.flagBit:
        case NodeKind.u2:
        case NodeKind.repeat:
        case NodeKind.times:
          walk(n.fields, conditional);
        case NodeKind.flagByte:
          break;
      }
    }
  }

  walk(nodes, false);
}

/// A list or dict element is a value of its own: an integer, a float, fixed
/// bytes, `utf8`, another list or dict, or a nested row. Any other field would
/// read the row around the element (a `sized`, `bits`, `packed`) or is no
/// value of its own (a `u2`).
void checkElements(List<Node> nodes) {
  for (final n in nodes) {
    if (n.isCollection) {
      final e = n.fields[0];
      switch (e.kind) {
        case NodeKind.integer:
        case NodeKind.float:
        case NodeKind.bytes:
        case NodeKind.utf8:
        case NodeKind.list:
        case NodeKind.dict:
        case NodeKind.nested:
          break;
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
          throw schemeFail(
            null,
            n.name,
            '${n.label} ${n.name}: a ${e.label} cannot be an element; use an integer, float, bytes, utf8, list, dict or nested row',
          );
      }
    }
    checkElements(n.fields);
  }
}
