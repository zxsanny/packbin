import 'dart:io';

/// The repository root: the first directory, walking up from the current
/// one, that holds `fixtures/golden.hex`.
Directory repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}/fixtures/golden.hex').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'fixtures/golden.hex not found above ${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

/// The text of the file at [relative] under the repository root.
String repoText(String relative) =>
    File('${repoRoot().path}/$relative').readAsStringSync();

/// The golden packet of the first example, as hex without spaces.
String goldenHex() => repoText('fixtures/golden.hex').trim();
