#!/usr/bin/env bash
# Runs the scheme-depth probes of AZ-4291 (see README.md): one tab-separated line per package, shape and
# depth on stdout, build messages on stderr. Usage: run.sh [package ...]; no argument runs all nine.
# Exit: 0 every probe ran (whatever it found), 1 a probe could not be built or run, 2 usage.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

all="typescript java go swift rust python cpp csharp dart"

if [ "$#" -eq 0 ]; then
  # shellcheck disable=SC2086  # the nine names, split on purpose
  set -- $all
fi

for package in "$@"; do
  case " $all " in
    *" $package "*) ;;
    *)
      echo "run.sh: no probe for '$package' ($all)" >&2
      exit 2
      ;;
  esac
done

failed=0
for package in "$@"; do
  if ! bash "$here/$package/run.sh" </dev/null; then
    echo "run.sh: the $package probe did not run" >&2
    failed=1
  fi
done
exit "$failed"
