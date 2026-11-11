import 'package:test/test.dart';

import '../limits/fuzz_schemes.dart';
import '../support/repo.dart';
import 'hostile_cases.dart';
import 'hostile_constructs.dart';
import 'hostile_packs.dart';
import 'hostile_rules.dart';

// AZ-4143 AC-1 (DT-4, S2): every data line of fixtures/hostile/cases.txt runs
// in Dart at its stage, each scheme written by hand from
// fixtures/hostile/README.md. A line the loader does not run, or a case with
// no handler, fails the suite; a handler with no case fails it too.

/// The handler ids of each stage.
Map<String, Set<String>> stageTables() => {
  'unpack': hostileUnpackSchemes.keys.toSet(),
  'limit': hostileLimitSchemes.keys.toSet(),
  'construct': hostileConstructs.keys.toSet(),
  'pack': hostilePacks.keys.toSet(),
};

/// The handler of the case [c] at its stage; null is an id with no handler.
String? runCase(HostileCase c) => switch (c.stage) {
  'unpack' => checkUnpack(c, hostileUnpackSchemes[c.id], hostileRules),
  'limit' => checkLimit(c, hostileLimitSchemes[c.id], hostileRules),
  'construct' => checkConstruct(c, hostileConstructs[c.id]),
  'pack' => checkPack(c, hostilePacks[c.id], hostileRules),
  _ => '${c.id}: the stage ${c.stage} has no Dart runner',
};

/// What is wrong in the cases of [stage]: the problems, and how many ran.
(List<String>, int) runStage(List<HostileCase> cases, String stage) {
  final problems = <String>[];
  var ran = 0;
  for (final c in cases.where((c) => c.stage == stage)) {
    if (notRun.containsKey(c.id)) continue;
    final wrong = runCase(c);
    ran++;
    if (wrong != null) problems.add(wrong);
  }
  return (problems, ran);
}

/// What is wrong between the README and [notRun]: every `pack` and `limit`
/// section names Dart exactly once in `Run by` and `Not run by`, and in
/// `Not run by` exactly for the cases of [notRun].
List<String> readmeProblems(String readme, List<HostileCase> cases) {
  final problems = <String>[];
  for (final c in cases.where((c) => c.stage == 'pack' || c.stage == 'limit')) {
    final section = _section(readme, c.id);
    final run = section.where((l) => l.startsWith('- Run by: ')).join(' ');
    final not = section.where((l) => l.startsWith('- Not run by: ')).join(' ');
    final inRun = _words(run).contains('Dart');
    final inNot = _words(not).contains('Dart');
    if (inRun == inNot) {
      problems.add('${c.id}: Dart is in ${inRun ? 'both' : 'neither'} line');
    } else if (inNot != notRun.containsKey(c.id)) {
      problems.add('${c.id}: Not run by and notRun disagree');
    }
  }
  return problems;
}

List<String> _section(String readme, String id) {
  final lines = readme.split('\n');
  final start = lines.indexOf('## $id');
  if (start < 0) return const [];
  final next = lines.indexWhere((l) => l.startsWith('## '), start + 1);
  return lines.sublist(start + 1, next < 0 ? lines.length : next);
}

Set<String> _words(String text) =>
    text.split(RegExp(r'[^A-Za-z0-9_#+]+')).toSet();

void main() {
  final cases = hostileCases();

  group('the shared hostile vectors, every data line at its stage', () {
    test('the tables hold every case once and no other', () {
      // Arrange
      final refused = {
        for (final c in cases)
          if (c.stage != 'construct' && c.terms != 'bytes') c.id,
      };

      // Act
      final problems = hostileTableProblems(
        cases,
        tables: stageTables(),
        rules: hostileRules.keys.toSet(),
        refused: refused,
        notRun: notRun,
      );

      // Assert
      expect(cases, isNotEmpty);
      expect(problems, isEmpty);
    });

    for (final stage in ['unpack', 'limit', 'construct', 'pack']) {
      test('every $stage case gives an allowed outcome with its rule', () {
        // Arrange
        final lines = cases.where((c) => c.stage == stage).length;
        final skipped = notRun.keys.where(
          (id) => cases.any((c) => c.id == id && c.stage == stage),
        );

        // Act
        final (problems, ran) = runStage(cases, stage);

        // Assert
        // ignore: avoid_print
        print(
          'hostile $stage: $ran of $lines cases ran, ${skipped.length} not run',
        );
        expect(problems, isEmpty);
        expect(ran + skipped.length, lines);
        expect(lines, greaterThan(0));
      });
    }

    test('the stages hold all the data lines', () {
      // Arrange
      final data = repoText('fixtures/hostile/cases.txt')
          .split('\n')
          .where((l) => l.trim().isNotEmpty && !l.trimLeft().startsWith('#'))
          .length;

      // Act
      final perStage = [
        for (final stage in stageTables().keys)
          cases.where((c) => c.stage == stage).length,
      ];

      // Assert
      expect(cases, hasLength(data));
      expect(perStage.reduce((a, b) => a + b), data);
    });

    test('the README names Dart once in every pack and limit section', () {
      // Arrange
      final readme = repoText('fixtures/hostile/README.md');

      // Act
      final problems = readmeProblems(readme, cases);

      // Assert
      expect(problems, isEmpty);
    });
  });

  group('the loader catches a wrong table or rule', () {
    HostileCase one(String id) => cases.firstWhere((c) => c.id == id);

    test('a case with no handler, a handler with no case and a notRun id with '
        'no case are named', () {
      // Arrange
      final tables = stageTables();
      tables['pack']!
        ..remove('pack_repeat_over_limit')
        ..add('pack_gone');
      final skipped = {'pack_gone_too': 'a reason'};

      // Act
      final problems = hostileTableProblems(
        cases,
        tables: tables,
        rules: hostileRules.keys.toSet(),
        refused: {
          for (final c in cases)
            if (c.stage != 'construct' && c.terms != 'bytes') c.id,
        },
        notRun: skipped,
      );

      // Assert
      expect(
        problems,
        contains('case pack_repeat_over_limit has no Dart handler (pack)'),
      );
      expect(
        problems,
        contains('Dart pack handler pack_gone has no case in cases.txt'),
      );
      expect(
        problems,
        contains('notRun pack_gone_too has no case in cases.txt'),
      );
    });

    test(
      'a case listed as not run is not silently skipped: it still fails',
      () {
        // Arrange
        final listed = [
          for (final c in cases)
            if (notRun.containsKey(c.id)) c,
        ];

        // Act
        final results = [for (final c in listed) runCase(c)];

        // Assert
        expect(
          results.every((r) => r != null),
          isTrue,
          reason: 'a notRun case that now passes must leave the map',
        );
      },
    );

    test('a case line with a stage no table runs is named', () {
      // Arrange
      final odd = [
        HostileCase('odd_case', 'replay', ['bytes'], '01'),
      ];

      // Act
      final problems = hostileTableProblems(
        odd,
        tables: stageTables(),
        rules: {},
        refused: {},
        notRun: {},
      );

      // Assert
      expect(
        problems,
        contains('case odd_case has the stage replay, which no table runs'),
      );
    });

    test('a pack case with a wrong rule fails naming the case', () {
      // Arrange
      final c = one('pack_slots_over_limit');
      final wrong = {
        ...hostileRules,
        c.id: hostileRules['pack_repeat_over_limit']!,
      };

      // Act
      final failure = checkPack(c, hostilePacks[c.id], wrong);

      // Assert
      expect(
        failure,
        startsWith('pack_slots_over_limit: refused by another rule'),
      );
    });

    test('a pack case that expects other bytes fails naming the case', () {
      // Arrange
      final c = one('pack_aligned_round_row');
      final other = HostileCase(c.id, c.stage, c.expected, '${c.hex}00');

      // Act
      final failure = checkPack(other, hostilePacks[c.id], hostileRules);

      // Assert
      expect(failure, startsWith('pack_aligned_round_row: packed '));
    });

    test('a construct case with a wrong rule fails naming the case', () {
      // Arrange
      final c = one('construct_empty_times_body');
      final right = hostileConstructs[c.id]!;
      final wrong = HostileConstruct(
        right.build,
        right.field,
        hostileConstructs['construct_empty_repeat_body']!.rule,
      );

      // Act
      final failure = checkConstruct(c, wrong);

      // Assert
      expect(
        failure,
        startsWith('construct_empty_times_body: refused by another rule'),
      );
    });

    test('an unpack case with a wrong rule fails naming the case', () {
      // Arrange
      final c = one('oversize_count_times');
      final wrong = {
        ...hostileRules,
        c.id: hostileRules['oversize_list_count']!,
      };

      // Act
      final failure = checkUnpack(c, hostileUnpackSchemes[c.id], wrong);

      // Assert
      expect(
        failure,
        startsWith('oversize_count_times: refused by another rule'),
      );
    });

    test('an unpack case whose outcome the line does not list fails', () {
      // Arrange
      final c = one('oversize_count_times');
      final other = HostileCase(c.id, c.stage, ['trailing_bytes'], c.hex);

      // Act
      final failure = checkUnpack(
        other,
        hostileUnpackSchemes[c.id],
        hostileRules,
      );

      // Assert
      expect(
        failure,
        startsWith('oversize_count_times: returned short_packet'),
      );
    });

    test('a case with no scheme fails naming the case', () {
      // Arrange
      final c = one('oversize_count_times');

      // Act
      final failure = checkUnpack(c, null, hostileRules);

      // Assert
      expect(failure, contains('oversize_count_times'));
    });
  });
}
