import 'dart:io';

import 'package:test/test.dart';

import '../support/repo.dart';
import 'readme_examples.dart';

// AZ-4148 AC-1 (DT-13): every Dart block of the README is compiled and run
// against the package and prints the output block under it. The README is read
// as a file, so an edit that breaks an example, or an output that no longer
// matches, fails here.

void main() {
  late Directory work;
  setUpAll(() => work = Directory.systemTemp.createTempSync('packbin_readme_'));
  tearDownAll(() => work.deleteSync(recursive: true));

  final readme = repoText('README.md');
  final examples = extractExamples(readme);

  group('AC-1 the README examples', () {
    test('the README holds the Dart examples of its sections', () {
      // Act
      final sections = examples.map((e) => e.section).toSet();

      // Assert
      expect(examples.length, greaterThanOrEqualTo(6));
      expect(sections, containsAll(['Example', 'Error correction']));
      expect(sections, contains('Frame session'));
      expect(examples.every((e) => e.expected != null), isTrue);
    });

    test(
      'the first example prints the golden packet of fixtures/golden.hex',
      () {
        // Act
        final first = examples.first.expected!.split('\n').first;

        // Assert
        expect(first, goldenHex());
      },
    );

    test('every example compiles, runs and prints the README output', () async {
      // Act
      final failures = await verifyExamples(examples, work);

      // Assert
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('a README block with a changed hex fails', () async {
      // Arrange
      final changed = readme.replaceFirst(
        goldenHex(),
        '${goldenHex().substring(0, 24)}01',
      );
      final first = extractExamples(changed).first;

      // Act
      final failures = await verifyExamples([first], work);

      // Assert
      expect(changed, isNot(readme));
      expect(failures, hasLength(1));
      expect(failures.single, contains('README line ${first.line}'));
      expect(failures.single, contains('printed'));
    });

    test('a block with no output block under it fails', () async {
      // Arrange
      final block = ReadmeExample(1, 'Example', 'print(1);', null);

      // Act
      final failures = await verifyExamples([block], work);

      // Assert
      expect(failures.single, contains('no output block'));
    });

    test('a block that does not compile fails', () async {
      // Arrange
      final block = ReadmeExample(2, 'Example', 'print(nope);', '1');

      // Act
      final failures = await verifyExamples([block], work);

      // Assert
      expect(failures.single, contains('README line 2'));
      expect(failures.single, contains('exited'));
    });
  });

  group('AC-2 the pub.dev package files', () {
    test('dart/README.md examples run and print their output', () async {
      // Arrange
      final own = extractExamples(repoText('dart/README.md'));

      // Act
      final failures = await verifyExamples(own, work);

      // Assert
      expect(own, isNotEmpty);
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test(
      'dart/example/packbin_example.dart prints the golden packet',
      () async {
        // Arrange
        final program = repoText('dart/example/packbin_example.dart');

        // Act
        final printed = await runProgram(program, work, 'package_example');

        // Assert
        expect(printed.split('\n').first, goldenHex());
        expect(printed, '${goldenHex()}\n500000000 true\n');
      },
    );

    test('the CHANGELOG has an entry for the version of pubspec.yaml', () {
      // Arrange
      final version = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(repoText('dart/pubspec.yaml'))!.group(1);

      // Act
      final changelog = repoText('dart/CHANGELOG.md');

      // Assert
      expect('\n$changelog', contains('\n## $version\n'));
    });
  });
}
