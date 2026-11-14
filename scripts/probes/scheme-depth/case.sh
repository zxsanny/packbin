#!/usr/bin/env bash
# Runs one probe case in its own process (AZ-4291): case.sh <package> <shape> <time-limit-seconds> <command...>.
# The command prints the five tab-separated fields' line itself. When it exits non-zero, is killed by a
# signal or runs past the limit, this prints `<package> <shape> crashed: <why> - -` instead (tab separated),
# so one dying case never ends the run. stdin is /dev/null; the command's stderr goes to stderr.
set -uo pipefail

package="$1"
shape="$2"
limit="$3"
shift 3

out="$(perl -e 'alarm shift; exec @ARGV' -- "$limit" "$@" </dev/null)"
status=$?

if [ "$status" -eq 0 ] && [ -n "$out" ]; then
  printf '%s\n' "$out"
  exit 0
fi

if [ "$status" -eq 142 ]; then
  why="timeout"
elif [ "$status" -gt 128 ]; then
  why="signal $((status - 128))"
elif [ "$status" -eq 0 ]; then
  why="no output"
else
  why="exit $status"
fi
printf '%s\t%s\tcrashed: %s\t-\t-\n' "$package" "$shape" "$why"
