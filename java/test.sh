#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$root/.." && pwd)"

if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/javac" ]; then
  export PATH="$JAVA_HOME/bin:$PATH"
elif [ -x /usr/libexec/java_home ]; then
  if JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null)"; then
    export JAVA_HOME
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
fi
if ! command -v javac >/dev/null 2>&1; then
  for candidate in /Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home \
                   /Library/Java/JavaVirtualMachines/jdk-11.jdk/Contents/Home \
                   /opt/homebrew/opt/openjdk@21 \
                   /opt/homebrew/opt/openjdk@17 \
                   /opt/homebrew/opt/openjdk@11; do
    if [ -x "$candidate/bin/javac" ]; then
      export JAVA_HOME="$candidate"
      export PATH="$JAVA_HOME/bin:$PATH"
      break
    fi
  done
fi
command -v javac >/dev/null 2>&1 || { echo "javac not found" >&2; exit 1; }
command -v java >/dev/null 2>&1 || { echo "java not found" >&2; exit 1; }
main_out="$root/out/main"
test_out="$root/out/test"

rm -rf "$root/out"
mkdir -p "$main_out" "$test_out"

main_sources=()
while IFS= read -r -d '' f; do
  main_sources+=("$f")
done < <(find "$root/src/main/java" -name '*.java' -print0 | sort -z)

test_sources=()
while IFS= read -r -d '' f; do
  test_sources+=("$f")
done < <(find "$root/src/test/java" -name '*.java' -print0 | sort -z)

javac -encoding UTF-8 -d "$main_out" "${main_sources[@]}"
javac -encoding UTF-8 -cp "$main_out" -d "$test_out" "${test_sources[@]}"

cd "$repo"
java -cp "$main_out:$test_out" packbin.PackbinTest
java -cp "$main_out:$test_out" packbin.SchemeTest
java -cp "$main_out:$test_out" packbin.FieldIdBindingTest
