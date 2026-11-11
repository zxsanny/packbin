import 'dart:io';

import 'package:test/test.dart';

import '../support/repo.dart';

void main() {
  group('AC-9 purity', () {
    test(
      'no file under dart/lib imports dart:mirrors, dart:ffi or dart:io',
      () {
        // Arrange
        final lib = Directory('${repoRoot().path}/dart/lib');
        final forbidden = RegExp(
          r'''^\s*(import|export)\s+['"]dart:(mirrors|ffi|io)['"]''',
          multiLine: true,
        );

        // Act
        final sources = [
          for (final entry in lib.listSync(recursive: true))
            if (entry is File && entry.path.endsWith('.dart')) entry,
        ];
        final hits = [
          for (final file in sources)
            if (forbidden.hasMatch(file.readAsStringSync())) file.path,
        ];

        // Assert
        expect(sources, isNotEmpty);
        expect(hits, isEmpty);
      },
    );

    test('pubspec.yaml has no runtime dependency and only test and lints for development', () {
      // Arrange
      final pubspec = repoText('dart/pubspec.yaml');

      // Act
      final runtime = RegExp(
        r'^dependencies:',
        multiLine: true,
      ).hasMatch(pubspec);
      final dev = pubspec
          .split(RegExp(r'^dev_dependencies:\s*$', multiLine: true))
          .last;
      final names = [
        for (final m in RegExp(r'^  (\w+):', multiLine: true).allMatches(dev))
          m.group(1),
      ];

      // Assert
      expect(runtime, isFalse);
      expect(names..sort(), ['lints', 'test']);
      expect(pubspec, contains('sdk: ^3.13.0'));
    });
  });
}
