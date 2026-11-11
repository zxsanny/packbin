import 'checks.dart';
import 'errors.dart';
import 'group_rows.dart';
import 'item_size.dart';
import 'node.dart';
import 'references.dart';
import 'round_shape.dart';

/// What a built scheme holds for the walkers. Nothing in it changes after it
/// is made.
final class Plan {
  Plan(
    this.fields,
    this.seenCount,
    this.splitCount,
    this.create,
    this.isRow,
    this.rowType,
    this.groups,
  );

  final List<Node> fields;

  /// The values one call keeps for the `when`s of the scheme.
  final int seenCount;

  /// The split flag byte reads of the scheme.
  final int splitCount;

  /// Makes the typed row unpack fills; null for a scheme of map rows.
  final Object Function()? create;
  final bool Function(Object row) isRow;
  final String rowType;

  /// The groups and their members' names of a scheme of map rows that has a
  /// group; null otherwise.
  final GroupPlace? groups;

  bool get typed => create != null;
}

/// Checks the declared fields and builds the plan. The checks run in
/// TypeScript's order: constructor refusals, field ids, flag bits, presence
/// marks, member names, round nesting and bodies, references; then the row
/// bindings.
Plan buildPlan<R extends Object>(
  int typeNumber,
  List<Node> declared,
  R Function()? create,
) {
  if (typeNumber < 0 || typeNumber > 255) {
    throw schemeFail(null, '', 'type number $typeNumber: expected 0..255');
  }
  checkErrors(declared);
  checkSlots(declared);
  checkIds(declared, 0);
  final typed = create != null;
  final flagBinder = _FlagBinder(typed);
  final bound = flagBinder.all(declared, Map.identity());
  checkMarks(bound, false);
  checkNames(bound);
  checkNesting(bound);
  checkBodies(bound);
  final sources = resolveReferences(bound, typed: typed);
  checkElements(bound);
  final finisher = _Finisher(sources);
  final fields = finisher.all(bound);
  if (typed) _checkBindings<R>(fields);
  return Plan(
    fields,
    finisher.slots.length,
    flagBinder.reads,
    create,
    typed
        ? (Object row) => row is R
        : (Object row) => row is Map<String, Object?>,
    typed ? '$R' : 'Map<String, Object?>',
    typed ? null : groupPlaces(fields),
  );
}

/// Gives each read of a split flag byte an identity of its own and numbers
/// its bits by their place after it. A bit reads the flag byte of its own
/// scope, read before it; a `when` body and each flags or flag-bit member see
/// the bytes read around them, and a byte read inside them is not seen after.
final class _FlagBinder {
  _FlagBinder(this._typed);

  /// A typed scheme has no nested map to name a group's row by.
  final bool _typed;
  int reads = 0;

  /// The groups with members between the row of the place and the field met.
  final List<String> _path = [];

  /// The bits met so far per handle, in any scope: the number a bit with no
  /// byte to follow is named by.
  final Map<FlagTag, int> _met = Map.identity();

  List<Node> all(List<Node> nodes, Map<FlagTag, _Read> seen) => [
    for (final n in nodes) one(n, seen),
  ];

  Map<FlagTag, _Read> _inner(Map<FlagTag, _Read> seen) =>
      Map.identity()..addAll(seen);

  Node one(Node n, Map<FlagTag, _Read> seen) {
    switch (n.kind) {
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
      case NodeKind.slot:
      case NodeKind.u2:
      case NodeKind.utf8:
        return n;
      case NodeKind.flagByte:
        final read = _Read(FlagRead(n.name, reads++));
        seen[n.handle!] = read;
        return n.copy(read: read.read);
      case NodeKind.flagBit:
        final handle = n.handle!;
        final before = _met[handle] ?? 0;
        _met[handle] = before + 1;
        final read = seen[handle];
        if (read == null) {
          throw schemeFail(
            n.errorId,
            n.declaredName,
            'flag bit $before (${n.declaredName}): its flag byte is not read earlier in the same scope',
          );
        }
        if (read.taken >= flagBits) {
          throw schemeFail(
            n.errorId,
            n.declaredName,
            'flag byte "${read.read.name}": ninth bit (${n.declaredName}); a flag byte holds $flagBits bits',
          );
        }
        final bit = read.taken++;
        return n.copy(
          read: read.read,
          bit: bit,
          path: _path.isEmpty ? const [] : List.unmodifiable(_path),
          fields: [one(n.member, _inner(seen))],
        );
      case NodeKind.flags:
        return n.copy(
          fields: [
            for (var i = 0; i < n.fields.length; i++)
              Node(
                NodeKind.flagBit,
                bit: i,
                fields: [one(n.fields[i], _inner(seen))],
              ),
          ],
        );
      case NodeKind.when:
        return n.copy(fields: all(n.fields, _inner(seen)));
      case NodeKind.repeat:
      case NodeKind.times:
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        // A round body, an element and a nested row are a scope of their own,
        // and their row is a row of its own.
        final outer = _path.toList();
        _path.clear();
        final fields = all(n.fields, Map.identity());
        _path.addAll(outer);
        return n.copy(fields: fields);
      case NodeKind.group:
        // A group shares the flag byte scope around it.
        final named = !_typed && n.fields.isNotEmpty;
        if (named) _path.add(n.name);
        final fields = all(n.fields, seen);
        if (named) _path.removeLast();
        return n.copy(fields: fields);
    }
  }
}

final class _Read {
  _Read(this.read);
  final FlagRead read;
  int taken = 0;
}

/// Gives each field a `when` tests its slot, each `when` the slot it reads,
/// and each split flag byte read its bits.
final class _Finisher {
  _Finisher(this._sources)
    : _referenced = Set.identity()
        ..addAll([for (final r in _sources.values) r.source]);

  final Map<Node, Reference> _sources;
  final Set<Node> _referenced;
  final Map<Node, int> slots = Map.identity();

  List<Node> all(List<Node> nodes) => [for (final n in nodes) one(n)];

  Node one(Node n) {
    switch (n.kind) {
      case NodeKind.integer:
      case NodeKind.boolean:
      case NodeKind.slot:
        if (!_referenced.contains(n)) return n;
        return n.copy(slot: slots[n] = slots.length);
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.flagByte:
      case NodeKind.utf8:
        return n;
      case NodeKind.list:
      case NodeKind.dict:
      case NodeKind.nested:
        final low = slots.length;
        final fields = all(n.fields);
        return n.copy(
          fields: fields,
          slotLo: low,
          slotHi: slots.length,
          place: n.kind == NodeKind.nested ? groupPlaces(fields) : null,
          minItem: n.isCollection ? minItemBytes(n.kind, fields[0]) : null,
        );
      case NodeKind.sized:
      case NodeKind.bits:
      case NodeKind.packed:
        return _reading(n);
      case NodeKind.repeat:
      case NodeKind.times:
        final low = slots.length;
        final fields = all(n.fields);
        return _reading(n).copy(
          fields: fields,
          slotLo: low,
          slotHi: slots.length,
          shape: RoundShape.of(fields),
        );
      case NodeKind.flagBit:
        final bit = n.copy(fields: all(n.fields));
        n.read?.bits.add(bit);
        return bit;
      case NodeKind.flags:
      case NodeKind.group:
      case NodeKind.u2:
        return n.copy(fields: all(n.fields));
      case NodeKind.when:
        return _reading(n).copy(fields: all(n.fields));
    }
  }

  /// [n] with the slot and the field of what it reads; a `repeat` reads none.
  Node _reading(Node n) {
    final reference = _sources[n];
    if (reference == null) return n;
    return n.copy(
      refSlot: slots[reference.source]!,
      refNode: reference.source,
      refPath: reference.path,
    );
  }
}

/// A typed scheme binds every value field to a member of its row type.
void _checkBindings<R extends Object>(List<Node> nodes) {
  for (final n in nodes) {
    if (n.isRound) {
      _checkRound<R>(n);
      continue;
    }
    if (n.isCollection || n.kind == NodeKind.nested) {
      _checkCollection<R>(n);
      continue;
    }
    if (n.isValue || n.isMark) {
      final binding = n.binding;
      if (binding == null) {
        throw schemeFail(
          n.id,
          n.name,
          '${n.name}: a scheme of $R rows needs every value field bound with bind',
        );
      }
      if (!binding.fits<R>()) {
        throw schemeFail(
          n.id,
          n.name,
          '${n.name}: bound to ${binding.rowType}, but the scheme\'s row is $R',
        );
      }
    }
    _checkBindings<R>(n.fields);
  }
}

/// A round of a typed scheme is bound to the member that holds its rounds, and
/// its own members are bound to the row type of one round.
void _checkRound<R extends Object>(Node n) {
  final (id, name) = n.shape!.member(n);
  final label = '${n.label} ${n.id}';
  final binding = n.roundBinding;
  if (binding == null) {
    throw schemeFail(
      id,
      name,
      '$label: a scheme of $R rows needs every round bound with bind',
    );
  }
  if (!binding.fits<R>()) {
    throw schemeFail(
      id,
      name,
      '$label: bound to ${binding.rowType}, but the scheme\'s row is $R',
    );
  }
  binding.checkBody(<S extends Object>(List<Node> body) {
    _checkBindings<S>(body);
  }, n.fields);
}

/// A list, dict or nested row of a typed scheme is bound to the member that
/// holds it, and what it holds is checked for the typed rows it makes.
void _checkCollection<R extends Object>(Node n) {
  final binding = n.binding;
  if (binding == null) {
    throw schemeFail(
      null,
      n.name,
      '${n.name}: a scheme of $R rows needs every ${n.label} bound with bind',
    );
  }
  if (!binding.fits<R>()) {
    throw schemeFail(
      null,
      n.name,
      '${n.name}: bound to ${binding.rowType}, but the scheme\'s row is $R',
    );
  }
  _checkItems(n);
}

/// The rows the items of [n] are: an element that is a nested row is made by
/// `nestedRow`, and its members are bound to its row type.
void _checkItems(Node n) {
  if (n.kind == NodeKind.nested) {
    final row = n.row;
    if (row == null) {
      throw schemeFail(
        null,
        n.name,
        '${n.name}: a typed scheme needs the nested row made with nestedRow',
      );
    }
    row.checkBody(<S extends Object>(List<Node> body) {
      _checkBindings<S>(body);
    }, n.fields);
  } else if (n.isCollection) {
    _checkItems(n.fields[0]);
  }
}
