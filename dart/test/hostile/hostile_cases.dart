import 'dart:typed_data';

import 'package:packbin/packbin.dart';

import '../support/hex.dart';
import '../support/repo.dart';
import '../support/timing.dart';

typedef Row = Map<String, Object?>;

/// One data line of fixtures/hostile/cases.txt: `id stage expected hex`.
class HostileCase {
  HostileCase(this.id, this.stage, this.expected, this.hex);

  final String id;
  final String stage;
  final List<String> expected;
  final String hex;

  bool accepts(String term) => expected.contains(term);

  String get terms => expected.join('|');

  Uint8List get packet => unhex(hex);

  @override
  String toString() => id;
}

/// Every data line of the case file at run time, in file order; a line that
/// does not hold four fields throws.
List<HostileCase> hostileCases() => [
  for (final line in repoText('fixtures/hostile/cases.txt').split('\n'))
    if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
      _parse(line.trim()),
];

HostileCase _parse(String line) {
  final f = line.split(RegExp(r'\s+'));
  if (f.length != 4) {
    throw FormatException('cases.txt line is not id stage expected hex', line);
  }
  return HostileCase(f[0], f[1], f[2].split('|'), f[3]);
}

/// What one guarded call gave: the value or the error it threw, and the
/// microseconds it took.
class HostileRun<T> {
  HostileRun(this.value, this.error, this.micros);

  final T? value;
  final Object? error;
  final int micros;
}

/// Runs [body] and keeps what it throws, whatever it is.
HostileRun<T> guarded<T>(T Function() body) {
  final watch = Stopwatch()..start();
  try {
    final value = body();
    return HostileRun(value, null, watch.elapsedMicroseconds);
  } on Object catch (e) {
    return HostileRun(null, e, watch.elapsedMicroseconds);
  }
}

/// The most microseconds one unpack of a case may take (1 second).
const int unpackBoundMicros = 1000000;

/// The same bound as a [Duration]: nominal, scaled by the load factor when a
/// call goes over it (`support/timing.dart`).
const Duration unpackBound = Duration(microseconds: unpackBoundMicros);

/// What is wrong with a [run] whose error must be a [PackbinError] (or a
/// [PackbinException] wrapping one) of a kind the case accepts, with the whole
/// text [rule], or null. [bounded] adds the 1 second bound of an unpack.
String? checkRefusal(
  HostileCase c,
  HostileRun<Object?> run,
  String? rule, {
  bool bounded = false,
}) {
  final thrown = run.error;
  final PackbinError? error = switch (thrown) {
    PackbinException(:final error) => error,
    _ =>
      run.value is Unpacked<Object>
          ? (run.value! as Unpacked<Object>).error
          : null,
  };
  if (error == null) {
    return thrown != null
        ? '${c.id}: threw ${thrown.runtimeType}: $thrown'
        : '${c.id}: expected ${c.terms}, got no error';
  }
  if (!c.accepts(error.kind.term)) {
    return '${c.id}: returned ${error.kind.term} ($error), vector accepts ${c.terms}';
  }
  if (rule == null) {
    return '${c.id}: no rule is pinned for this refusal: $error';
  }
  if (error.toString() != rule) {
    return '${c.id}: refused by another rule: "$error", want "$rule"';
  }
  if (bounded &&
      overLoadBound(Duration(microseconds: run.micros), unpackBound)) {
    return '${c.id}: took ${run.micros / 1000} ms, bound 1000 ms times the load factor';
  }
  return null;
}

/// An unpack case: builds the scheme and unpacks the packet. A scheme refused
/// at construction is the case's outcome (`scheme_error`), which some cases
/// accept; otherwise the result must be an error value and no row.
String? checkUnpack(
  HostileCase c,
  Scheme<Row> Function()? build,
  Map<String, String> rules, {
  Scheme<Row> Function(Scheme<Row>)? limit,
}) {
  if (build == null) return 'no Dart scheme for ${c.stage} case ${c.id}';
  Scheme<Row>? layout;
  final built = guarded(() {
    final s = build();
    layout = limit == null ? s : limit(s);
  });
  if (built.error != null) return checkRefusal(c, built, rules[c.id]);
  final run = guarded(() => unpackRow(c.packet, layout!));
  final result = run.value;
  if (result != null && result.row != null) {
    return '${c.id}: expected ${c.terms}, got a row ${result.row}';
  }
  return checkRefusal(c, run, rules[c.id], bounded: true);
}

/// A limit case: unpack with the section's low limit. The round past the
/// limit is refused when it would start, so no bytes are needed and its byte
/// is left.
String? checkLimit(
  HostileCase c,
  Scheme<Row> Function()? build,
  Map<String, String> rules,
) {
  final wrong = checkUnpack(
    c,
    build,
    rules,
    limit: (s) => s.withLimits(maxRounds: 3),
  );
  if (wrong != null) return wrong;
  final error = unpackRow(c.packet, build!().withLimits(maxRounds: 3)).error!;
  return error.needed == 0 && error.left == 1
      ? null
      : '${c.id}: $error, want needed 0 and left 1';
}

/// What differs between cases.txt and the Dart tables, one entry per problem:
/// a case twice, a stage no table runs, a case with no handler and not listed
/// in [notRun], a handler with no case, a [notRun] id with no case, a rule for
/// a case that is not refused and a refused case with no rule.
List<String> hostileTableProblems(
  List<HostileCase> cases, {
  required Map<String, Set<String>> tables,
  required Set<String> rules,
  required Set<String> refused,
  required Map<String, String> notRun,
}) {
  final problems = <String>[];
  final seen = <String>{};
  for (final c in cases) {
    if (!seen.add(c.id)) problems.add('case ${c.id} is listed twice');
    final handlers = tables[c.stage];
    if (handlers == null) {
      problems.add(
        'case ${c.id} has the stage ${c.stage}, which no table runs',
      );
    } else if (!notRun.containsKey(c.id) && !handlers.contains(c.id)) {
      problems.add('case ${c.id} has no Dart handler (${c.stage})');
    }
  }
  for (final MapEntry(key: stage, value: handlers) in tables.entries) {
    final ids = {
      for (final c in cases)
        if (c.stage == stage) c.id,
    };
    if (ids.isEmpty) problems.add('cases.txt holds no $stage case');
    for (final id in handlers.difference(ids)) {
      problems.add('Dart $stage handler $id has no case in cases.txt');
    }
  }
  for (final id in notRun.keys) {
    if (!seen.contains(id)) problems.add('notRun $id has no case in cases.txt');
  }
  for (final id in rules.difference(refused)) {
    problems.add('rule $id is for a case that is not refused');
  }
  for (final id in refused.difference(rules)) {
    if (!notRun.containsKey(id)) problems.add('refused case $id has no rule');
  }
  return problems..sort();
}
