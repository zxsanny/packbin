import 'dart:typed_data';

import 'counted_pack.dart';
import 'errors.dart';
import 'group_rows.dart';
import 'limits.dart';
import 'node.dart';
import 'pack.dart';
import 'round_shape.dart';

/// The longest list among the round's names; a value that is not a list is one
/// round.
int roundCount(RoundShape shape, Map<String, Object?> row) {
  var count = 0;
  for (final n in shape.names) {
    final v = row[n.name];
    if (v == null) continue;
    final here = isRoundList(v) ? (v as List<Object?>).length : 1;
    if (here > count) count = here;
  }
  return count;
}

/// Round [i] of [row] in [view]: each list among the round's names read at
/// [i] (an absent entry leaves the name out), a value that is not a list as
/// it is.
void _slice(
  RoundShape shape,
  Map<String, Object?> row,
  int i,
  Map<String, Object?> view,
) {
  view.clear();
  for (final n in shape.names) {
    final v = row[n.name];
    if (v == null) continue;
    if (isRoundList(v)) {
      final list = v as List<Object?>;
      final entry = i < list.length ? list[i] : null;
      if (entry != null) view[n.name] = entry;
    } else {
      view[n.name] = v;
    }
  }
}

PackbinException _fail(Node round, RoundShape shape, String text) {
  final (id, name) = shape.member(round);
  return packFail(
    id,
    name,
    name.isEmpty ? '${round.label} ${round.id}: $text' : '$name: $text',
  );
}

/// The first byte buffer in the members [nodes] of a group whose map [map]
/// is given once for every round.
Node? _bufferIn(List<Node> nodes, Map<String, Object?> map) {
  for (final n in nodes) {
    switch (n.kind) {
      case NodeKind.bytes:
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
        if (map[n.name] != null) return n;
      case NodeKind.when:
      case NodeKind.flags:
      case NodeKind.flagBit:
      case NodeKind.u2:
        final found = _bufferIn(n.fields, map);
        if (found != null) return found;
      case NodeKind.group:
        final nested = map[n.name];
        if (n.fields.isNotEmpty && nested is Map<String, Object?>) {
          final found = _bufferIn(n.fields, nested);
          if (found != null) return found;
        }
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.boolean:
      case NodeKind.flagByte:
      case NodeKind.slot:
      case NodeKind.repeat:
      case NodeKind.times:
        break;
    }
  }
  return null;
}

extension RoundPack on Packer {
  /// The first value under the round [n] the row gives, at any depth; null
  /// when it holds none. A round holds one when it has a round, or a lone
  /// byte buffer that would reach every round.
  Node? roundHeld(Node n, Object row) {
    final shape = n.shape!;
    if (typed) {
      final rounds = n.roundBinding!.get(row);
      return rounds != null && rounds.isNotEmpty
          ? (shape.names.isEmpty ? n : shape.names.first)
          : null;
    }
    final map = row as Map<String, Object?>;
    final lone = shape.buffers.any((b) => map[b.name] != null);
    if (roundCount(shape, map) == 0 && !lone) return null;
    return shape.names.isEmpty ? n : shape.names.first;
  }

  /// A `repeat` is on when a round holds a value.
  bool repeatOn(Node n, Object row) {
    if (typed) return n.roundBinding!.get(row)?.isNotEmpty ?? false;
    return roundCount(n.shape!, row as Map<String, Object?>) > 0;
  }

  /// A `times` is on when its count is above 0 (a count that was not written
  /// is no round; a count of 0 refuses a list of values).
  bool timesOn(Node n, Object row) {
    if (seen[n.refSlot] == null) return false;
    final count = borrowedCount(n);
    if (count == 0) _refuseValuesForNone(n, row);
    return count > 0;
  }

  void _refuseValuesForNone(Node n, Object row) {
    final shape = n.shape!;
    if (typed) {
      final rounds = n.roundBinding!.get(row);
      if (rounds != null && rounds.isNotEmpty) {
        throw _fail(
          n,
          shape,
          'the times count is 0, but the row holds ${rounds.length} rounds',
        );
      }
      return;
    }
    final map = row as Map<String, Object?>;
    _refuseLongLists(n, shape, map, 0);
    _refuseLoneBuffers(n, shape, map);
  }

  /// Packs the rounds of a `repeat`: one round per entry of the longest list.
  void packRepeat(Node n, Object row) {
    final shape = n.shape!;
    if (typed) {
      final rounds = n.roundBinding!.get(row) ?? const <Object>[];
      if (rounds.length > defaultMaxRounds) {
        throw _fail(
          n,
          shape,
          'the repeat count is ${rounds.length}, above the limit of $defaultMaxRounds rounds',
        );
      }
      _typedRounds(n, shape, rounds);
      return;
    }
    final map = row as Map<String, Object?>;
    for (final m in shape.names) {
      final v = map[m.name];
      if (isRoundList(v) && (v as List<Object?>).length > defaultMaxRounds) {
        throw packFail(
          m.errorId,
          m.name,
          '${m.name}: the repeat count is ${v.length}, above the limit of $defaultMaxRounds rounds',
        );
      }
    }
    final count = roundCount(shape, map);
    for (final m in shape.optional) {
      final v = map[m.name];
      if (isRoundList(v) &&
          (v as List<Object?>).isNotEmpty &&
          v.length < count) {
        throw packFail(
          m.errorId,
          m.name,
          '${m.name}: ${v.length} items, repeat count $count; give one entry per round, null where the member is absent',
        );
      }
    }
    _refuseLoneBuffers(n, shape, map);
    _mapRounds(n, shape, count, map);
  }

  /// Packs the rounds of a `times`: exactly as many as its count says.
  void packTimes(Node n, Object row) {
    final shape = n.shape!;
    final count = borrowedCount(n);
    if (count > defaultMaxRounds) {
      throw _fail(
        n,
        shape,
        'the times count is $count, above the limit of $defaultMaxRounds rounds',
      );
    }
    if (typed) {
      final rounds = n.roundBinding!.get(row) ?? const <Object>[];
      if (rounds.length != count) {
        throw _fail(
          n,
          shape,
          'the times count is $count, but the row holds ${rounds.length} rounds',
        );
      }
      _typedRounds(n, shape, rounds);
      return;
    }
    final map = row as Map<String, Object?>;
    _refuseLongLists(n, shape, map, count);
    _refuseLoneBuffers(n, shape, map);
    _mapRounds(n, shape, count, map);
  }

  /// A times writes exactly its count of rounds, so a list that holds more
  /// would lose its tail.
  void _refuseLongLists(
    Node n,
    RoundShape shape,
    Map<String, Object?> map,
    int count,
  ) {
    for (final m in shape.names) {
      final v = map[m.name];
      if (isRoundList(v) && (v as List<Object?>).length > count) {
        throw packFail(
          m.errorId,
          m.name,
          '${m.name}: ${v.length} items, times count $count',
        );
      }
    }
  }

  /// One byte buffer given for a name of a round would reach every round, so
  /// it is refused: a buffer per round goes in a list. Inside a group map
  /// given once for every round it is refused too.
  void _refuseLoneBuffers(Node n, RoundShape shape, Map<String, Object?> map) {
    for (final m in shape.buffers) {
      if (map[m.name] is Uint8List) {
        throw packFail(
          m.id,
          m.name,
          '${m.name}: a byte buffer in a repeat or times round needs a list with one buffer per round',
        );
      }
    }
    for (final g in shape.names) {
      final lone = map[g.name];
      if (g.kind != NodeKind.group ||
          g.isMark ||
          lone is! Map<String, Object?>) {
        continue;
      }
      final found = _bufferIn(g.fields, lone);
      if (found != null) {
        throw packFail(
          found.id,
          found.name,
          '${found.name}: a byte buffer in a group given once for every round needs one group per round',
        );
      }
    }
  }

  /// Each round is charged its width against the slot limit as it starts,
  /// before its bytes, as unpack charges it.
  void _charge(Node n, RoundShape shape) {
    final width = shape.width;
    if (width > defaultMaxSlots - charged) {
      throw _fail(
        n,
        shape,
        'the rounds would hold ${charged + width} slots, above the limit of $defaultMaxSlots slots',
      );
    }
    charged += width;
  }

  void _mapRounds(
    Node n,
    RoundShape shape,
    int count,
    Map<String, Object?> row,
  ) {
    final view = <String, Object?>{};
    final outer = placeRow;
    for (var i = 0; i < count; i++) {
      _charge(n, shape);
      _slice(shape, row, i, view);
      final place = shape.place;
      if (place != null) checkGroupRows(place, view);
      _startRound(n, view);
      fields(n.fields, view);
    }
    placeRow = outer;
  }

  void _typedRounds(Node n, RoundShape shape, List<Object> rounds) {
    final outer = placeRow;
    for (final round in rounds) {
      _charge(n, shape);
      _startRound(n, round);
      fields(n.fields, round);
    }
    placeRow = outer;
  }

  /// A round is a scope of its own: nothing the round before it wrote is seen.
  void _startRound(Node n, Object row) {
    if (n.slotHi > n.slotLo) seen.fillRange(n.slotLo, n.slotHi, null);
    placeRow = row;
  }
}
