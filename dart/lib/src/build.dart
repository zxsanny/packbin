import 'errors.dart';
import 'node.dart';

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

  bool get typed => create != null;
}

/// Checks the declared fields and builds the plan. The checks run in
/// TypeScript's order: constructor refusals, field ids, flag bits, presence
/// marks, references; then the row bindings.
Plan buildPlan<R extends Object>(
  int typeNumber,
  List<Node> declared,
  R Function()? create,
) {
  if (typeNumber < 0 || typeNumber > 255) {
    throw schemeFail(null, '', 'type number $typeNumber: expected 0..255');
  }
  _checkErrors(declared);
  _checkIds(declared, 0);
  final flagBinder = _FlagBinder();
  final bound = flagBinder.all(declared, Map.identity());
  _checkMarks(bound, false);
  final sources = Map<Node, Node>.identity();
  _resolve(bound, {}, sources);
  final finisher = _Finisher(sources);
  final fields = finisher.all(bound);
  final typed = create != null;
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
  );
}

void _checkErrors(List<Node> nodes) {
  for (final n in nodes) {
    final error = n.error;
    if (error != null) throw schemeFail(n.errorId, n.declaredName, error);
    _checkErrors(n.fields);
  }
}

int _checkIds(List<Node> nodes, int next) {
  for (final n in nodes) {
    switch (n.kind) {
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
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
        if (n.id != next) {
          throw schemeFail(
            n.id,
            n.declaredName,
            'field id: expected $next, got ${n.id}',
          );
        }
        next = _checkIds(n.fields, next);
      case NodeKind.flagBit:
        next = _checkIds(n.fields, next);
      case NodeKind.flagByte:
        break;
    }
  }
  return next;
}

/// Gives each read of a split flag byte an identity of its own and numbers
/// its bits by their place after it. A bit reads the flag byte of its own
/// scope, read before it; a `when` body and each flags or flag-bit member see
/// the bytes read around them, and a byte read inside them is not seen after.
final class _FlagBinder {
  int reads = 0;

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
    }
  }
}

final class _Read {
  _Read(this.read);
  final FlagRead read;
  int taken = 0;
}

/// A bool is a presence mark: it has no bytes, only a flag bit, so it stands
/// only as the member of a flag bit. Anywhere else it would always read true.
void _checkMarks(List<Node> nodes, bool onFlagBit) {
  for (final n in nodes) {
    if (n.kind == NodeKind.boolean && !onFlagBit) {
      throw schemeFail(
        n.id,
        n.name,
        'bool ${n.name}: allowed only directly inside flags or a flag bit; move it into flags',
      );
    }
    _checkMarks(n.fields, n.kind == NodeKind.flagBit);
  }
}

String _shown(Object value) {
  if (value is String) return '"$value"';
  if (value is num || value is bool) return '$value';
  return 'a ${value.runtimeType}';
}

/// An `eq` id names an integer or bool field read earlier in the same scope.
/// Flags, flag bits and `when` share the scope around them.
void _resolve(List<Node> nodes, Map<int, Node> scope, Map<Node, Node> sources) {
  for (final n in nodes) {
    switch (n.kind) {
      case NodeKind.integer:
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.boolean:
        scope[n.id!] = n;
      case NodeKind.when:
        sources[n] = _source(n, scope);
        _resolve(n.fields, scope, sources);
      case NodeKind.flags:
      case NodeKind.flagBit:
        _resolve(n.fields, scope, sources);
      case NodeKind.flagByte:
        break;
    }
  }
}

Node _source(Node when, Map<int, Node> scope) {
  final condition = when.condition!;
  final id = condition.fieldId;
  final value = condition.value;
  final source = scope[id];
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
  } else if (source.kind != NodeKind.integer) {
    throw fail(
      ': eq names field id $id (${source.name}), which is not an integer or a bool',
    );
  } else if (value is! int) {
    throw fail(
      ' tests ${source.label} field $id (\'${source.name}\') against ${_shown(value)}; the value must be a whole number',
    );
  }
  return source;
}

/// Gives each field a `when` tests its slot, each `when` the slot it reads,
/// and each split flag byte read its bits.
final class _Finisher {
  _Finisher(this._sources)
    : _referenced = Set.identity()..addAll(_sources.values);

  final Map<Node, Node> _sources;
  final Set<Node> _referenced;
  final Map<Node, int> slots = Map.identity();

  List<Node> all(List<Node> nodes) => [for (final n in nodes) one(n)];

  Node one(Node n) {
    switch (n.kind) {
      case NodeKind.integer:
      case NodeKind.boolean:
        if (!_referenced.contains(n)) return n;
        return n.copy(slot: slots[n] = slots.length);
      case NodeKind.float:
      case NodeKind.bytes:
      case NodeKind.flagByte:
        return n;
      case NodeKind.flagBit:
        final bit = n.copy(fields: all(n.fields));
        n.read?.bits.add(bit);
        return bit;
      case NodeKind.flags:
        return n.copy(fields: all(n.fields));
      case NodeKind.when:
        return n.copy(fields: all(n.fields), refSlot: slots[_sources[n]!]!);
    }
  }
}

/// A typed scheme binds every value field to a member of its row type.
void _checkBindings<R extends Object>(List<Node> nodes) {
  for (final n in nodes) {
    if (n.isValue) {
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
