#!/usr/bin/env bash
# C++ probe of AZ-4206 (see ../README.md). Compiles probe.cpp with the core sources of this checkout
# in a temporary directory and prints one line per shape. A variant (a second way to write a shape)
# is printed after its shape when its outcome differs, and on stderr when it does not:
#   <shape>-unbound     the list or dict of b and c without a member (`list(element)`);
#   <shape>-constexpr   the scheme as a constant (`constexpr auto s = ...`), one translation unit per
#                       shape; a scheme the package stops the compiler at is
#                       `refused: compile error: ...`.
# Compiler messages go to stderr. Nothing is written into the repository.
# Exit: 0 the probe ran, whatever it found (a scheme that the package refuses as a constant is a
# finding); 1 a build or a run failed (the shapes that could run are still printed).
# CXX picks the compiler (default c++); PACKBIN_CXX_SYSROOT is honoured as in cpp/Makefile.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

shapes=(control a b c d e-when e-flags f)
# CORE_SRCS of cpp/Makefile.
core=(values pack unpack crypto frame)

cxx="${CXX:-c++}"
# The flags of cpp/Makefile without -Werror: the library is built the embedded way on the host too.
flags=(-std=c++17 -O2 -Wall -Wextra -fno-exceptions -fno-rtti -I "$root/cpp/include")
if [[ -n "${PACKBIN_CXX_SYSROOT:-}" ]]; then
  flags+=(-isysroot "$PACKBIN_CXX_SYSROOT" -I "$PACKBIN_CXX_SYSROOT/usr/include/c++/v1")
fi

# The variants of a shape that the run-time build of the probe holds.
variants_of() {
  if [[ "$1" == "b" || "$1" == "c" ]]; then
    printf '%s\n' "$1-unbound"
  fi
}

# The build, pack and unpack cells of a probe line.
cells_of() {
  printf '%s\n' "$1" | cut -f 3-
}

# Prints the line of a variant: on stdout when its outcome differs from the line of its shape, else
# on stderr. The outcome is the same when the cells are equal, or when the variant is the constant
# form and both schemes are refused at build (a scheme built at run time and a constant one word
# that refusal differently). Two run-time forms refused at different fields are refused by
# different rules (a bound list refuses its row element, an unbound one the repeat inside it), so
# both lines are printed.
print_variant() {
  local line="$1" other="$2" cells others shape
  cells="$(cells_of "$line")"
  others="$(cells_of "$other")"
  shape="$(printf '%s\n' "$other" | cut -f 2)"
  if [[ "$others" == "$cells" ||
    ("$shape" == *-constexpr && "$others" == refused:* && "$cells" == refused:*) ]]; then
    printf 'run.sh: same outcome as its shape, not printed: %s\n' "$other" >&2
  else
    printf '%s\n' "$other"
  fi
}

# One shape of the probe binary $1 in a process of its own; $3 is the shape as that binary prints it
# (default: the shape). The probe writes each cell as it gets it, so when it dies inside a call (a
# signal) the cells so far are kept and the call that died is a `threw:` cell. Any other failure of
# the process is a failure of the run: nothing is printed and the status is 1.
run_shape() {
  local bin="$1" shape="$2" label="${3:-$2}" line status=0 tabs what
  line="$("$bin" "$shape" </dev/null)" || status=$?
  if ((status != 0)); then
    if ((status < 128)); then
      printf 'run.sh: the probe ended with status %s for shape %s\n' "$status" "$label" >&2
      return 1
    fi
    what="threw: the probe ended with signal $(kill -l "$((status - 128))")"
    tabs="$(printf '%s' "$line" | tr -cd '\t' | wc -c | tr -d ' ')"
    if ((tabs == 4)); then
      line+="$what"
    elif ((tabs == 3)); then
      line+="$what"$'\t-'
    elif ((tabs == 2)); then
      line+="$what"$'\t-\t-'
    else
      line="cpp"$'\t'"$label"$'\t'"$what"$'\t-\t-'
    fi
  fi
  printf '%s\n' "$line"
}

# The first error of a compiler log and the notes that belong to it (up to the next error), as the
# compiler printed them, one per line. A diagnostic starts its line with its place; the source lines
# the compiler quotes under it start with a space.
first_error_of() {
  awk '
    /^[^[:space:]].*: (fatal )?error: / { if (seen) exit; seen = 1 }
    seen && /^[^[:space:]].*: ((fatal )?error|note): / { print }
  ' "$1"
}

# The refusal a failed build of a constant scheme reports, on one line; status 1 when the failure is
# not the package's. The package refuses a constant scheme by stopping the compiler in its own
# headers: it calls a function that is not constexpr on purpose (the stoppers of codec.hpp and
# table.hpp, named after the rule), or a static_assert fails. So the first error, or a note of it,
# must be at a line of cpp/include/packbin and say one of the two: Clang names the stopper in a
# note, GCC in the error. Any other failed build (a fault of the probe or the toolchain, also one
# whose notes only show a declaration of the package) is no refusal.
package_refusal() {
  local log="$1" first="" at="" diagnostic
  local stop="non-'?constexpr'? function|static assertion failed|static_assert failed"
  while IFS= read -r diagnostic; do
    if [[ -z "$first" ]]; then
      first="$diagnostic"
    fi
    if [[ "$diagnostic" == "$root/cpp/include/packbin/"* && "$diagnostic" =~ $stop ]]; then
      at="$diagnostic"
      break
    fi
  done < <(first_error_of "$log")
  if [[ -z "$at" ]]; then
    return 1
  fi
  if [[ "$at" != "$first" ]]; then
    first+="; ${at#*note: }"
  fi
  first="${first#"$here"/}"
  first="${first#"$root"/}"
  printf '%s' "$first" | tr -s '[:space:]' ' '
}

# The line of one shape built as a constant; status 1 when that build or its run failed.
constexpr_line() {
  local shape="$1" label="$1-constexpr" define obj log refusal
  define="SHAPE_$(printf '%s' "$shape" | tr '[:lower:]' '[:upper:]')"
  define="${define//-/_}"
  obj="$out/$label.o"
  log="$out/$label.log"
  if "$cxx" "${flags[@]}" -DPROBE_CONSTEXPR "-D$define" -c -o "$obj" "$here/probe.cpp" 2>"$log"; then
    cat "$log" >&2
    "$cxx" "${flags[@]}" -o "$out/$label" "$obj" "${objects[@]}" >&2 || {
      printf 'run.sh: the link of %s failed\n' "$label" >&2
      return 1
    }
    run_shape "$out/$label" "$shape" "$label" || return 1
    return 0
  fi
  cat "$log" >&2
  if ! refusal="$(package_refusal "$log")"; then
    printf 'run.sh: the build of %s failed and it is not the package that stopped the compiler\n' \
      "$label" >&2
    return 1
  fi
  printf 'cpp\t%s\trefused: compile error: %s\t-\t-\n' "$label" "$refusal"
}

objects=()
for name in "${core[@]}"; do
  "$cxx" "${flags[@]}" -c -o "$out/$name.o" "$root/cpp/src/core/$name.cpp" >&2
  objects+=("$out/$name.o")
done
"$cxx" "${flags[@]}" -o "$out/probe" "$here/probe.cpp" "${objects[@]}" >&2

# A shape or a variant that could not run is reported on stderr; the ones after it still print.
failed=0
for shape in "${shapes[@]}"; do
  if ! line="$(run_shape "$out/probe" "$shape")"; then
    failed=1
    continue
  fi
  printf '%s\n' "$line"
  while IFS= read -r variant; do
    if other="$(run_shape "$out/probe" "$variant")"; then
      print_variant "$line" "$other"
    else
      failed=1
    fi
  done < <(variants_of "$shape")
  if other="$(constexpr_line "$shape")"; then
    print_variant "$line" "$other"
  else
    failed=1
  fi
done
exit "$failed"
