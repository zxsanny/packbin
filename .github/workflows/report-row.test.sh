#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

for lang in csharp typescript python rust cpp java; do
  grep -q "^  ${lang}:" docker-compose.test.yml
done
if grep -q 'ports:' docker-compose.test.yml; then
  echo "compose publishes a port" >&2
  exit 1
fi
if grep -E 'npmjs|nuget.org|pypi.org|crates.io|central.sonatype.com|github.com' \
  .github/workflows/run-suite.sh .github/workflows/report-row.sh; then
  echo "suite runner names a registry" >&2
  exit 1
fi

tmp="$(mktemp -d)"
TEST_RESULTS="$tmp" bash .github/workflows/report-row.sh csharp "csharp suite" 10 PASS ""
head -n 1 "$tmp/report.csv" | grep -qx 'Test ID,Test Name,Execution Time (ms),Result,Error Message'
grep -qx 'csharp,csharp suite,10,PASS,' "$tmp/report.csv"
echo "report row tests passed"
