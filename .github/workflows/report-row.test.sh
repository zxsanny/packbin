#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

langs="csharp typescript python rust cpp java go swift"
for lang in $langs; do
  grep -q "^  ${lang}:" docker-compose.test.yml
  grep -q "^  ${lang}:" docker-compose.publish.yml
done
# The suites job is a matrix with an entry for each of the eight services (Swift as two parts, AZ-2600).
matrix="$(ruby -ryaml -e 'puts YAML.safe_load(File.read(ARGV[0]))["jobs"]["suites"]["strategy"]["matrix"]["include"].map { |e| e["lang"] }.uniq.join(" ")' .github/workflows/test.yml)"
[ "$matrix" = "$langs" ] || { echo "suites matrix runs [$matrix], not [$langs]" >&2; exit 1; }
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
trap 'rm -rf "$tmp"' EXIT
TEST_RESULTS="$tmp" bash .github/workflows/report-row.sh csharp "csharp suite" 10 PASS ""
head -n 1 "$tmp/report.csv" | grep -qx 'Test ID,Test Name,Execution Time (ms),Result,Error Message'
grep -qx 'csharp,csharp suite,10,PASS,' "$tmp/report.csv"
TEST_RESULTS="$tmp" bash .github/workflows/report-row.sh go "go suite" 20 FAIL "suite failed"
grep -qx 'go,go suite,20,FAIL,suite failed' "$tmp/report.csv"
TEST_RESULTS="$tmp" bash .github/workflows/report-row.sh swift "swift suite" 30 FAIL "swift dependency resolve failed"
grep -qx 'swift,swift suite,30,FAIL,swift dependency resolve failed' "$tmp/report.csv"
[ "$(grep -c 'Test ID' "$tmp/report.csv")" -eq 1 ]
echo "report row tests passed"
