#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

langs="csharp typescript python rust cpp java go swift"
for lang in $langs; do
  grep -q "^  ${lang}:" docker-compose.test.yml
  grep -q "^  ${lang}:" docker-compose.publish.yml
done
# The suites job is a matrix whose entries name the eight services (Swift as three parts, AZ-2600, AZ-2607; short suites
# share an entry, AZ-2627). The entries are listed longest first (AZ-2625), so the languages are compared as a set.
matrix="$(ruby -ryaml -e 'puts YAML.safe_load(File.read(ARGV[0]))["jobs"]["suites"]["strategy"]["matrix"]["include"].flat_map { |e| e["lang"].to_s.split }.uniq.sort.join(" ")' .github/workflows/test.yml)"
sorted_langs="$(tr ' ' '\n' <<< "$langs" | sort | paste -sd ' ' -)"
[ "$matrix" = "$sorted_langs" ] || { echo "suites matrix runs [$matrix], not [$sorted_langs]" >&2; exit 1; }
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
