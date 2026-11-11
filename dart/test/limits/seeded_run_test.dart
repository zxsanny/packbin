import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/repo.dart';
import 'fuzz_schemes.dart';
import 'fuzz_support.dart';

// AZ-4139 AC-4 (DT-5): the seeded unpack run. Every input of
// fixtures/hostile/fuzz/corpus.txt, read as a packet of each fuzz scheme, of
// its corpus kind and of all fuzz schemes at once, then random mutations
// until the time box ends. Asserted: 0 uncaught exceptions, 0 unpack calls
// over 1 second, 0 results above the slot budget.
//
// The run lasts PACKBIN_FUZZ_SECONDS seconds (3 when unset; CI asks 60:
// .github/workflows/run-suite-dart.sh) and replays from PACKBIN_FUZZ_SEED.

/// The seconds of the random run.
double fuzzSeconds() {
  final text = Platform.environment['PACKBIN_FUZZ_SECONDS'];
  if (text == null || text.isEmpty) return 3;
  final seconds = double.tryParse(text);
  if (seconds == null || seconds < 0) {
    throw FormatException(
      'PACKBIN_FUZZ_SECONDS is not a number of seconds',
      text,
    );
  }
  return seconds;
}

/// The seed of the random run: PACKBIN_FUZZ_SEED, else a fresh one.
int fuzzSeed() {
  final text = Platform.environment['PACKBIN_FUZZ_SEED'];
  if (text == null || text.isEmpty) return Random().nextInt(1 << 32);
  final seed = int.tryParse(text);
  if (seed == null) {
    throw FormatException('PACKBIN_FUZZ_SEED is not an integer', text);
  }
  return seed;
}

void main() {
  final seconds = fuzzSeconds();

  group('the corpus and the hostile cases', () {
    test('the corpus and the case file name each other, both ways', () {
      // Arrange
      final cases = hostileCases();
      final ring = kindSchemes().keys.toSet().difference(cases.keys.toSet());

      // Act
      final problems = corpusProblems(fuzzCorpus(), cases, ring);

      // Assert
      expect(
        cases.values.where((c) => c.$1 == 'unpack' || c.$1 == 'limit'),
        isNotEmpty,
      );
      expect(problems, isEmpty);
    });

    test(
      'a corpus line that names a case id missing from cases.txt is found',
      () {
        // Arrange
        final cases = {'a_case': ('unpack', '0100')};
        final corpus = [
          FuzzInput('hostile_a_case', 'a_case', unhex('0100')),
          FuzzInput('hostile_gone', 'gone', unhex('0100')),
        ];

        // Act
        final problems = corpusProblems(corpus, cases, {'any'});

        // Assert
        expect(problems, [
          'hostile_gone: kind gone is no case id of cases.txt',
        ]);
      },
    );

    test(
      'a case missing from the corpus, or with another packet, is found',
      () {
        // Arrange
        final cases = {
          'one': ('unpack', '0100'),
          'two': ('limit', '0101'),
          'three': ('construct', '-'),
        };
        final corpus = [FuzzInput('hostile_two', 'two', unhex('0102'))];

        // Act
        final problems = corpusProblems(corpus, cases, {'any'});

        // Assert
        expect(problems, [
          'case one is not in the corpus with its packet',
          'case two is not in the corpus with its packet',
        ]);
      },
    );

    test('a kind with no scheme set and an unused ring kind are found', () {
      // Arrange
      final corpus = [FuzzInput('ring_x', 'unknown', unhex('01'))];

      // Act
      final problems = corpusProblems(corpus, {}, {'any', 'position'});

      // Assert
      expect(problems, [
        'ring_x: kind unknown has no scheme set',
        'ring kind position has no corpus input',
      ]);
    });

    test('the corpus loader reads every line of the file', () {
      // Arrange
      final corpus = fuzzCorpus();

      // Act
      final lines = dataLines(repoText('fixtures/hostile/fuzz/corpus.txt'));

      // Assert
      expect(corpus, isNotEmpty);
      expect(corpus.length, lines.length);
    });

    test('a seed gives the same random inputs, so a failure replays', () {
      // Arrange
      final corpus = fuzzCorpus();
      List<String> draw(int seed) {
        final random = Random(seed);
        return [
          for (var i = 0; i < 200; i++)
            () {
              final (packet, kind) = fuzzInput(corpus, random);
              return '$kind ${hex(packet)}';
            }(),
        ];
      }

      // Act
      final a = draw(7);
      final b = draw(7);
      final c = draw(8);

      // Assert
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('the corpus read every way', () {
    test('gives a row or a well-formed error, in time, with no throw', () {
      // Arrange
      final run = FuzzRun();
      final corpus = fuzzCorpus();
      final tally = FuzzTally();

      // Act
      for (final input in corpus) {
        final inputTally = FuzzTally();
        run.check(input.packet, input.kind, inputTally);
        tally.reads += inputTally.reads;
        if (inputTally.slowest > tally.slowest) {
          tally.slowest = inputTally.slowest;
        }
        tally.failures.addAll(
          inputTally.failures.map((f) => '${input.name}: $f'),
        );
      }

      // Assert
      // ignore: avoid_print
      print('seeded run: corpus of ${corpus.length} inputs: ${tally.summary}');
      expect(tally.failures, isEmpty);
      expect(tally.reads, greaterThan(corpus.length));
    });

    test(
      'a mebibyte of 0, 1 or 255 is read by every scheme within the bound',
      () {
        // Arrange
        final run = FuzzRun();
        final tally = FuzzTally();

        // Act
        for (final fill in [0, 1, 0xff]) {
          run.checkBody(Uint8List(1 << 20)..fillRange(0, 1 << 20, fill), tally);
        }

        // Assert
        // ignore: avoid_print
        print('seeded run: mebibyte packets: ${tally.summary}');
        expect(tally.failures, isEmpty);
      },
    );
  });

  group('the seeded random run', () {
    test('for the asked seconds finds no failure', () {
      // Arrange
      final seed = fuzzSeed();
      final random = Random(seed);
      final run = FuzzRun();
      final corpus = fuzzCorpus();
      final tally = FuzzTally();
      // ignore: avoid_print
      print(
        'seeded run: seed $seed, $seconds s; replay with PACKBIN_FUZZ_SEED=$seed',
      );

      // Act
      final watch = Stopwatch()..start();
      final limit = Duration(microseconds: (seconds * 1e6).round());
      var inputs = 0;
      while (watch.elapsed < limit && tally.failures.length < 10) {
        final (packet, kind) = fuzzInput(corpus, random);
        final before = tally.failures.length;
        run.check(packet, kind, tally);
        for (var i = before; i < tally.failures.length; i++) {
          tally.failures[i] =
              'input $inputs (${hex(packet.take(64).toList())}): ${tally.failures[i]}';
        }
        inputs++;
      }
      watch.stop();

      // Assert
      // ignore: avoid_print
      print(
        'seeded run: seed $seed: $inputs inputs in ${watch.elapsed.inMilliseconds / 1000} s: ${tally.summary}',
      );
      expect(tally.failures, isEmpty, reason: 'seed $seed');
      expect(inputs, greaterThan(0));
      expect(watch.elapsed, greaterThanOrEqualTo(limit));
    }, timeout: Timeout(Duration(seconds: seconds.ceil() + 120)));
  });
}
