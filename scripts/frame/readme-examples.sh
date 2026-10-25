#!/usr/bin/env bash
# Checks that each frame-mode example of the README is the code between the README-BEGIN and README-END
# markers of the test that runs it (AZ-3235). Indentation is ignored. Java's block is followed by two closing lines.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 -I - "$root" <<'PY'
import re, sys, textwrap
root = sys.argv[1]
readme = open(f"{root}/README.md", encoding="utf-8").read()
sources = {
    "C#": ("csharp/tests/FrameReadmeExample.cs", ""),
    "Java": ("java/src/test/java/packbin/FrameReadmeExample.java", "    }\n}\n"),
    "Swift": ("swift/Tests/PackbinTests/FrameReadmeExampleTests.swift", ""),
}
failed = 0
for lang, (path, tail) in sources.items():
    text = open(f"{root}/{path}", encoding="utf-8").read()
    m = re.search(r"^[ \t]*// README-BEGIN\n(.*?)^[ \t]*// README-END\n", text, re.S | re.M)
    if not m:
        print(f"FAIL {lang}: no README-BEGIN/END markers in {path}")
        failed += 1
        continue
    block = textwrap.dedent(m.group(1)).rstrip("\n") + "\n"
    if tail:
        block += textwrap.dedent(tail)
    if block not in readme and block.replace("\n\n", "\n") not in readme:
        print(f"FAIL {lang}: the README does not contain the example of {path}")
        failed += 1
    else:
        print(f"PASS {lang}: the README example equals {path}")
sys.exit(1 if failed else 0)
PY
