import 'dart:async';
import 'dart:io';

import '../support/repo.dart';

/// One ```dart block of a README: the code, the output block that follows it
/// and where it stands.
final class ReadmeExample {
  const ReadmeExample(this.line, this.section, this.code, this.expected);

  /// The 1-based line of the opening fence.
  final int line;

  /// The text of the `##` heading above the block.
  final String section;

  /// The code between the fences.
  final String code;

  /// The text of the plain block directly under the code (only blank lines
  /// between), or null when there is none.
  final String? expected;
}

final _fence = RegExp(r'^```(\w*)\s*$');
final _main = RegExp(r'^\s*(?:Future<void>|void)\s+main\s*\(', multiLine: true);

/// Every ```dart block of [readme], with the plain block under it as its
/// expected output.
List<ReadmeExample> extractExamples(String readme) {
  final lines = readme.split('\n');
  final blocks = <(int, String, String, String)>[];
  var section = '';
  for (var i = 0; i < lines.length; i++) {
    final heading = RegExp(r'^##\s+(.*)$').firstMatch(lines[i]);
    if (heading != null) section = heading.group(1)!;
    final open = _fence.firstMatch(lines[i]);
    if (open == null) continue;
    var end = i + 1;
    while (end < lines.length && lines[end].trimRight() != '```') {
      end++;
    }
    blocks.add((
      i + 1,
      section,
      open.group(1)!,
      lines.sublist(i + 1, end).join('\n'),
    ));
    i = end;
  }
  return [
    for (var k = 0; k < blocks.length; k++)
      if (blocks[k].$3 == 'dart')
        ReadmeExample(
          blocks[k].$1,
          blocks[k].$2,
          blocks[k].$4,
          k + 1 < blocks.length &&
                  blocks[k + 1].$3.isEmpty &&
                  _blankBetween(lines, blocks[k], blocks[k + 1])
              ? blocks[k + 1].$4
              : null,
        ),
  ];
}

bool _blankBetween(
  List<String> lines,
  (int, String, String, String) block,
  (int, String, String, String) next,
) {
  final closing = block.$1 + block.$4.split('\n').length + 1;
  for (var i = closing; i < next.$1 - 1; i++) {
    if (lines[i].trim().isNotEmpty) return false;
  }
  return true;
}

/// A complete program for [code]: a block with a `main` as it is, any other
/// block as the body of `main` with its `import` lines hoisted.
String programOf(String code) {
  if (_main.hasMatch(code)) return code;
  final imports = <String>[], body = <String>[];
  for (final line in code.split('\n')) {
    (line.startsWith('import ') ? imports : body).add(line);
  }
  return '${imports.join('\n')}\n\nvoid main() {\n${body.join('\n')}\n}\n';
}

/// The package root, `dart/`: the folder above `test/readme`.
Directory packageRoot() => Directory('${repoRoot().path}/dart');

/// Compiles and runs [program] against this package, as its own program in a
/// temporary folder, and gives what it printed. Throws for a compile error, a
/// non-zero exit or a program that runs past two minutes.
Future<String> runProgram(String program, Directory work, String name) async {
  final config = File('${work.path}/$name.package_config.json')
    ..writeAsStringSync(
      '{"configVersion":2,"packages":[{"name":"packbin",'
      '"rootUri":"${packageRoot().uri}","packageUri":"lib/",'
      '"languageVersion":"3.13"}]}',
    );
  final file = File('${work.path}/$name.dart')..writeAsStringSync(program);
  final result = await Process.run(Platform.resolvedExecutable, [
    '--packages=${config.path}',
    file.path,
  ]).timeout(const Duration(minutes: 2));
  if (result.exitCode != 0) {
    throw StateError('$name exited ${result.exitCode}: ${result.stderr}');
  }
  return result.stdout as String;
}

String _trimmed(String text) => text
    .replaceAll('\r', '')
    .split('\n')
    .map((l) => l.trimRight())
    .join('\n')
    .trim();

/// Runs every example of [readme] and gives one message for each whose
/// output differs from the block under it or that does not run. An empty list
/// means every example prints what the README shows.
Future<List<String>> verifyExamples(
  List<ReadmeExample> examples,
  Directory work,
) async {
  final failures = await Future.wait([
    for (final e in examples) _verify(e, work),
  ]);
  return [for (final f in failures) ?f];
}

Future<String?> _verify(ReadmeExample example, Directory work) async {
  final where = 'README line ${example.line} (${example.section})';
  final expected = example.expected;
  if (expected == null) return '$where: no output block under the code';
  try {
    final printed = await runProgram(
      programOf(example.code),
      work,
      'example_${example.line}',
    );
    return _trimmed(printed) == _trimmed(expected)
        ? null
        : '$where: printed\n${_trimmed(printed)}\nbut the README shows\n'
              '${_trimmed(expected)}';
  } on Object catch (error) {
    return '$where: $error';
  }
}
