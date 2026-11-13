import 'dart:math';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';

import '../support/hex.dart';
import '../support/repo.dart';
import '../support/timing.dart';
import 'fuzz_schemes.dart';

/// One corpus input (fixtures/hostile/fuzz/corpus.txt).
class FuzzInput {
  FuzzInput(this.name, this.kind, this.packet);

  final String name;
  final String kind;
  final Uint8List packet;
}

/// The data lines of [text]: fields split on spaces and tabs, `#` lines and
/// blank lines left out.
List<List<String>> dataLines(String text) => [
  for (final line in text.split('\n'))
    if (line.trim().isNotEmpty && !line.trimLeft().startsWith('#'))
      line.trim().split(RegExp(r'\s+')),
];

/// Every input of the corpus file; a line that is not `name kind hex` throws.
List<FuzzInput> fuzzCorpus() => [
  for (final parts in dataLines(repoText('fixtures/hostile/fuzz/corpus.txt')))
    if (parts.length == 3)
      FuzzInput(parts[0], parts[1], unhex(parts[2]))
    else
      throw FormatException(
        'corpus line is not name kind hex',
        parts.join(' '),
      ),
];

/// The case ids of fixtures/hostile/cases.txt with their stage and packet hex.
Map<String, (String, String)> hostileCases() => {
  for (final parts in dataLines(repoText('fixtures/hostile/cases.txt')))
    if (parts.length == 4) parts[0]: (parts[1], parts[3]),
};

/// What is wrong between the corpus and the case file, both ways: a hostile
/// `unpack` or `limit` case the corpus lacks (or holds with another packet),
/// a hostile corpus input whose case id is not in the case file, an input
/// whose kind has no scheme set, a ring kind no input has, a repeated name.
List<String> corpusProblems(
  List<FuzzInput> corpus,
  Map<String, (String, String)> cases,
  Set<String> ringKinds,
) {
  final problems = <String>[];
  for (final e in cases.entries) {
    final (stage, packet) = e.value;
    if (stage != 'unpack' && stage != 'limit') continue;
    final held = corpus.any(
      (c) =>
          c.name == 'hostile_${e.key}' &&
          c.kind == e.key &&
          hex(c.packet) == packet,
    );
    if (!held) {
      problems.add('case ${e.key} is not in the corpus with its packet');
    }
  }
  for (final c in corpus) {
    if (c.name.startsWith('hostile_')) {
      if (c.name != 'hostile_${c.kind}' || !cases.containsKey(c.kind)) {
        problems.add('${c.name}: kind ${c.kind} is no case id of cases.txt');
      }
    } else if (!ringKinds.contains(c.kind)) {
      problems.add('${c.name}: kind ${c.kind} has no scheme set');
    }
  }
  for (final k in ringKinds) {
    if (k != 'any' && !corpus.any((c) => c.kind == k)) {
      problems.add('ring kind $k has no corpus input');
    }
  }
  final names = corpus.map((c) => c.name);
  if (names.toSet().length != corpus.length) problems.add('a name is repeated');
  return problems;
}

/// What the reads of a run found.
class FuzzTally {
  final failures = <String>[];
  int reads = 0;
  int slowest = 0;

  String get summary =>
      '$reads unpack calls, slowest ${slowest / 1000} ms, '
      '${failures.length} failures';
}

/// The most microseconds one unpack may take (project AC-2: 1 second).
const int unpackBoundMicros = 1000000;

/// The same bound as a [Duration]; a call over it is judged against the load factor.
const Duration unpackBound = Duration(microseconds: unpackBoundMicros);

/// The schemes of a run and the checks each read must pass: an unpack throws
/// nothing, takes under a second, gives a row inside the slot budget or a
/// well-formed error.
class FuzzRun {
  FuzzRun()
    : schemes = fuzzSchemes(),
      typed = fuzzTypedSchemes(),
      kinds = kindSchemes();

  final List<Scheme<Object>> schemes;
  final List<Scheme<Object>> typed;
  final Map<String, List<Scheme<Object>>> kinds;

  /// Reads [packet] with every fuzz scheme at once, with the schemes of
  /// [kind], and as the body of a packet of every scheme, as it is and
  /// without its first byte.
  void check(Uint8List packet, String? kind, FuzzTally tally) {
    read(packet, schemes, tally);
    for (final s in kinds[kind] ?? const <Scheme<Object>>[]) {
      read(packet, [s], tally);
    }
    checkBody(packet, tally);
    if (packet.isNotEmpty) checkBody(Uint8List.sublistView(packet, 1), tally);
  }

  /// Reads [body] after the type byte of each scheme, one scheme a call.
  void checkBody(Uint8List body, FuzzTally tally) {
    for (final s in [...schemes, ...typed]) {
      final packet = Uint8List(body.length + 1)
        ..[0] = s.typeNumber
        ..setRange(1, body.length + 1, body);
      read(packet, [s], tally);
    }
  }

  /// One packet read with [with]. A throw, a call over the bound, a row
  /// above the slot budget of its scheme or an ill-formed error is a failure.
  void read(Uint8List packet, List<Scheme<Object>> with_, FuzzTally tally) {
    final watch = Stopwatch()..start();
    Unpacked<Object>? got;
    try {
      got = unpack(packet, [for (final s in with_) s.on((_) {})]);
    } on Object catch (e) {
      tally.failures.add('unpack threw ${e.runtimeType}: $e');
    }
    watch.stop();
    final micros = watch.elapsedMicroseconds;
    tally.reads++;
    if (micros > tally.slowest) tally.slowest = micros;
    if (overLoadBound(Duration(microseconds: micros), unpackBound)) {
      tally.failures.add(
        'unpack of ${packet.length} bytes took ${micros / 1000} ms',
      );
    }
    if (got == null) return;
    final error = got.error;
    if (error != null) {
      final wrong = malformed(error, packet, with_);
      if (wrong != null) tally.failures.add('$wrong: $error');
      return;
    }
    _checkRow(got.row!, packet, with_, tally);
  }

  void _checkRow(
    Object row,
    Uint8List packet,
    List<Scheme<Object>> with_,
    FuzzTally tally,
  ) {
    final matched = with_.firstWhere(
      (s) => s.typeNumber == packet[0],
      orElse: () => with_.first,
    );
    if (row is Map<String, Object?> && roundEntries(row) > matched.maxSlots) {
      tally.failures.add(
        'a row of ${roundEntries(row)} entries, above the slot budget '
        '${matched.maxSlots}',
      );
    }
    // Packed again only to look for an exception that is no pack refusal: a
    // refusal is allowed (a flags times whose bit is clear unpacks, then
    // refuses to pack).
    try {
      pack(matched, row);
    } on PackbinException {
      // A refusal is a value of pack, not a failure.
    } on Object catch (e) {
      tally.failures.add('pack of an unpacked row threw ${e.runtimeType}: $e');
    }
  }

  /// What is wrong with the error unpack returned, or null.
  String? malformed(
    PackbinError e,
    Uint8List packet,
    List<Scheme<Object>> with_,
  ) {
    if (e.kind == ErrorKind.schemeError || e.kind == ErrorKind.packError) {
      return 'a kind unpack never returns';
    }
    if (!e.toString().startsWith('packbin: ')) {
      return 'a message without the package prefix';
    }
    if (e.needed < 0 || e.left < 0 || e.left > packet.length) {
      return 'a number out of range';
    }
    if (e.kind == ErrorKind.tooMany && e.needed != 0) {
      return 'a round limit with bytes needed';
    }
    if (e.kind == ErrorKind.trailing && (e.left == 0 || e.needed != 0)) {
      return 'trailing bytes that are none';
    }
    if (e.kind == ErrorKind.unknownType &&
        (packet.isEmpty ||
            packet[0] != e.actual ||
            with_.any((s) => s.typeNumber == e.actual))) {
      return 'an unknown type that is not the first byte or is known';
    }
    if (e.kind == ErrorKind.short &&
        packet.isEmpty &&
        (e.needed != 1 || e.left != 0)) {
      return 'an empty packet that is not a one-byte short read';
    }
    return null;
  }
}

/// The entries of the lists at the top level of [row]: what the rounds of a
/// map scheme made, which the slot budget bounds.
int roundEntries(Map<String, Object?> row) {
  var total = 0;
  for (final v in row.values) {
    if (v is List<Object?>) total += v.length;
  }
  return total;
}

const List<int> _pool = [0, 1, 2, 3, 4, 0x40, 0x7f, 0x80, 0xfe, 0xff];

int _interesting(Random random) => random.nextBool()
    ? _pool[random.nextInt(_pool.length)]
    : random.nextInt(256);

/// One random input and the corpus kind it was made from: fresh bytes, a
/// mutated corpus input (a flipped bit, a replaced, inserted or removed byte,
/// a repeated run, a truncation, a run of 0xff), or two corpus inputs
/// spliced; now and then a long run of one byte is added, which reaches the
/// round limits.
(Uint8List, String?) fuzzInput(List<FuzzInput> corpus, Random random) {
  var packet = <int>[];
  String? kind;
  switch (random.nextInt(8)) {
    case 0 || 1:
      packet = [
        for (var i = random.nextInt(49); i > 0; i--) _interesting(random),
      ];
    case 7:
      final a = corpus[random.nextInt(corpus.length)];
      final b = corpus[random.nextInt(corpus.length)];
      packet = [
        ...a.packet.take(random.nextInt(a.packet.length + 1)),
        ...b.packet.skip(random.nextInt(b.packet.length + 1)),
      ];
      kind = a.kind;
    default:
      final input = corpus[random.nextInt(corpus.length)];
      packet = [...input.packet];
      kind = input.kind;
      for (var i = 1 + random.nextInt(4); i > 0; i--) {
        _mutate(packet, random);
      }
  }
  if (random.nextInt(64) == 0) {
    final fill = _interesting(random);
    packet.addAll(List.filled(256 + random.nextInt(8192), fill));
  }
  return (Uint8List.fromList(packet), kind);
}

void _mutate(List<int> packet, Random random) {
  final at = packet.isEmpty ? 0 : random.nextInt(packet.length);
  switch (random.nextInt(7)) {
    case 0 when packet.isNotEmpty:
      packet[at] ^= 1 << random.nextInt(8);
    case 1 when packet.isNotEmpty:
      packet[at] = _interesting(random);
    case 2:
      packet.insert(at, _interesting(random));
    case 3 when packet.isNotEmpty:
      packet.removeAt(at);
    case 4 when packet.isNotEmpty:
      final end = min(packet.length, at + 1 + random.nextInt(8));
      packet.insertAll(end, packet.sublist(at, end));
    case 5:
      packet.removeRange(at, packet.length);
    default:
      final end = min(packet.length, at + [2, 4, 8][random.nextInt(3)]);
      for (var i = at; i < end; i++) {
        packet[i] = 0xff;
      }
  }
}
