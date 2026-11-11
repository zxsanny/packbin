# Four-package differential (loop 103, AC-6)

TypeScript is the reference. `gen.ts` writes 5,000 seeded dictionaries (keys of 0 to 3 units over a, b, `?`, the four surrogate halves, U+FFFD, U+FFFF, U+10000, an emoji, `~` and the empty text) and TypeScript's result for each (the hex of the packet, or `REFUSED`). Each runner packs the same dictionaries and compares. Result on 2026-11-11 (HEAD of the loop 103 batch): C#, Java and Dart each 5,000 same, 0 different, 225 refused.

Cases file: one line per dictionary, tab-separated: the keys as UTF-16 code units in hex (4 digits a unit, `-` for the empty key, `,` between keys), the values, the expected result.

| package | file | run |
|---------|------|-----|
| TypeScript (generator) | `gen.ts` | `node gen.ts CASES.txt` (from `typescript/`) |
| C# | `csharp/Diff.csproj`, `Program.cs` (links `csharp/*.cs` by absolute path) | `env MSBUILDDISABLENODEREUSE=1 dotnet build -c Release -o OUT -p:BaseIntermediateOutputPath=OBJ/`, then `dotnet OUT/Diff.dll CASES.txt` |
| Java | `java/Diff103.java` (package `packbin`) | `javac -d OUT` over `java/src/main/java/**/*.java` plus this file, then `java -cp OUT packbin.Diff103 CASES.txt` |
| Dart | `dart/diff.dart` | in a scratch package with `packbin: {path: .../dart}`: `dart run diff.dart CASES.txt` |
