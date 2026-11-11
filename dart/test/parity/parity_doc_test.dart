import 'dart:io';

import 'package:test/test.dart';

import '../support/repo.dart';
import 'parity_tables.dart';

// The document `parity_differences.md` cannot rot: every row of its table
// names Dart test files that exist and test names that occur in them, and its
// coverage table lists every ported TypeScript table with the Dart file and
// the row count the registry (`parity_tables.dart`) runs.

const docPath = '_docs/02_task_plans/dart-package/parity_differences.md';

/// The lines of the table that follows the first line starting with
/// [header], as cells.
List<List<String>> tableAfter(String doc, String header) {
  final lines = doc.split('\n');
  final start = lines.indexWhere((l) => l.startsWith(header));
  if (start < 0) fail('no table with the header $header');
  final rows = <List<String>>[];
  for (var i = start + 2; i < lines.length; i++) {
    final line = lines[i];
    if (!line.startsWith('|')) break;
    rows.add([
      for (final c in line.substring(1, line.length - 1).split(' | ')) c.trim(),
    ]);
  }
  return rows;
}

final List<File> dartTests = [
  for (final e in Directory(
    '${repoRoot().path}/dart/test',
  ).listSync(recursive: true))
    if (e is File && e.path.endsWith('.dart')) e,
];

/// The source of a test file with adjacent string literals joined, so a
/// test name that the formatter wrapped over two lines still occurs.
String sourceOf(File f) => f
    .readAsStringSync()
    .replaceAll(RegExp(r"'\s*\n\s*'"), '')
    .replaceAll(RegExp(r'"\s*\n\s*"'), '')
    .replaceAll("\\'", "'");

/// The Dart file a cell token names: a path from `dart/`, or a basename that
/// only one test file has.
File resolve(String token) {
  if (token.contains('/')) {
    final f = File('${repoRoot().path}/dart/$token');
    if (!f.existsSync()) fail('the test file $token does not exist');
    return f;
  }
  final found = [
    for (final f in dartTests)
      if (f.path.endsWith('/$token')) f,
  ];
  if (found.length != 1) {
    fail('$token names ${found.length} test files; write its path from dart/');
  }
  return found.single;
}

void main() {
  final doc = repoText(docPath);
  final differences = tableAfter(doc, '| row |');

  test('the document lists differences, each with five cells', () {
    // Assert
    expect(differences.length, greaterThan(40));
    for (final r in differences) {
      expect(r.length, 5, reason: 'the row ${r.first}');
    }
  });

  group('every row names its Dart tests', () {
    for (final r in differences) {
      final label = r.first.length > 70 ? r.first.substring(0, 70) : r.first;
      test(label, () {
        // Arrange
        final tokens = RegExp(r'`([^`]+)`')
            .allMatches(r.last)
            .map((m) => m.group(1)!)
            .toList();
        final files = [
          for (final t in tokens)
            if (t.endsWith('.dart')) resolve(t),
        ];
        final names = [
          for (final t in tokens)
            if (!t.endsWith('.dart')) t,
        ];

        // Act
        final sources = [for (final f in files) sourceOf(f)];

        // Assert
        expect(files, isNotEmpty, reason: 'the row names no test file');
        for (final name in names) {
          final text = name.replaceAll(RegExp(r'\.\.\.$'), '').trim();
          expect(
            sources.any((s) => s.contains(text)),
            isTrue,
            reason:
                'the test name "$text" occurs in none of '
                '${files.map((f) => f.path.split('/').last).join(', ')}',
          );
        }
      });
    }
  });

  group('the coverage table lists every ported TypeScript table', () {
    final tables = parityTables();

    test('each registered table is in the document with its row count', () {
      // Arrange
      final coverage = tableAfter(doc, '| TypeScript table |');
      final byName = {for (final r in coverage) r[0].replaceAll('`', ''): r};

      // Act and Assert
      for (final t in tables) {
        final row = byName[t.tsFile];
        expect(row, isNotNull, reason: '${t.tsFile} is not in the document');
        expect(row![2], '${t.rows}', reason: 'rows of ${t.tsFile}');
        expect(row[3].replaceAll('`', ''), 'test/parity/${t.dartFile}');
      }
      expect(coverage.length, greaterThanOrEqualTo(tables.length));
    });

    test('the TypeScript and Dart files of the table exist', () {
      // Act and Assert
      for (final t in tables) {
        expect(
          File(
            '${repoRoot().path}/typescript/tests/${t.tsFile.split(' ').first}',
          ).existsSync(),
          isTrue,
          reason: t.tsFile,
        );
        expect(
          File('${repoRoot().path}/dart/test/parity/${t.dartFile}')
              .existsSync(),
          isTrue,
          reason: t.dartFile,
        );
      }
    });
  });
}
