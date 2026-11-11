import 'counted_unpack.dart';
import 'errors.dart';
import 'node.dart';
import 'round_shape.dart';
import 'unpack.dart';

/// The list a `repeat` built joins what the row already holds under that
/// name.
void _appendList(Map<String, Object?> into, String name, List<Object?> list) {
  final prev = into[name];
  if (prev is List<Object?>) {
    prev.addAll(list);
  } else if (prev != null) {
    into[name] = [prev, ...list];
  } else {
    into[name] = list;
  }
}

extension RoundUnpack on Reader {
  /// Reads the rounds of a `repeat` (to the end of the packet) or a `times`
  /// (its count) into [row]; false when the packet is refused. A map row gets
  /// one list for each name a round holds, an entry a round, null where the
  /// round skipped it, and an empty list when no round was read; a typed row
  /// gets the list of the rows the rounds made.
  bool readRounds(Node n, Object row) {
    final shape = n.shape!;
    final (id, name) = shape.member(n);
    int? count;
    if (n.kind == NodeKind.times) {
      count = readCount(n);
      if (count == null) {
        error = unreadable(id, name);
        return false;
      }
    }
    final binding = n.roundBinding;
    final rounds = typed ? binding!.newList() : <Object>[];
    while (count != null ? rounds.length < count : left > 0) {
      if (!_charge(n, shape, rounds.length)) return false;
      final before = off;
      if (n.slotHi > n.slotLo) seen.fillRange(n.slotLo, n.slotHi, null);
      final Object one = typed ? binding!.create() : <String, Object?>{};
      if (!fields(n.fields, one)) return false;
      if (off == before && count != null) {
        // A times round that reads nothing would repeat up to the count for
        // no input.
        error = emptyItem(id, name);
        return false;
      }
      rounds.add(one);
      // A repeat round that reads nothing ends the repeat; the bytes left are
      // trailing.
      if (off == before) break;
    }
    if (typed) {
      binding!.set(row, rounds);
      return true;
    }
    final map = row as Map<String, Object?>;
    for (final m in shape.names) {
      final list = <Object?>[
        for (final r in rounds) (r as Map<String, Object?>)[m.name],
      ];
      if (n.kind == NodeKind.repeat) {
        _appendList(map, m.name, list);
      } else {
        map[m.name] = list;
      }
    }
    return true;
  }

  /// Charges a round as it starts, before its bytes are read: a round past
  /// the round limit, or one that would take the slots past the slot limit, is
  /// refused.
  bool _charge(Node n, RoundShape shape, int index) {
    if (index < limits.maxRounds && shape.width <= limits.maxSlots - slots) {
      slots += shape.width;
      return true;
    }
    final (id, name) = shape.member(n);
    final label = name.isEmpty ? '${n.label} ${n.id}' : name;
    final String reason;
    if (index >= limits.maxRounds) {
      reason =
          '$label: round ${index + 1} is above the limit of ${limits.maxRounds} rounds';
    } else {
      reason =
          '$label: the rounds would hold ${slots + shape.width} slots, above the limit of ${limits.maxSlots} slots';
    }
    error = PackbinError(
      ErrorKind.tooMany,
      field: id,
      name: name,
      left: left,
      reason: reason,
    );
    return false;
  }
}
