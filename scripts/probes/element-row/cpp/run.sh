#!/usr/bin/env bash
# C++ probe of AZ-4242 (see ../README.md). Compiles probe.cpp (it includes probe_support.hpp and
# probe_compiled.hpp from this folder) with the core sources of this checkout in a temporary
# directory and prints one line per shape. The plain shape is a list or dict bound to
# a member; a variant is printed after its shape when its outcome differs, and on stderr when it
# does not:
#   <shape>-unbound     the same list or dict without a member (`list(element)`);
#   <shape>-constexpr   the bound scheme as a constant, one translation unit per shape; a scheme the
#                       package stops the compiler at is `refused: compile error: ...`.
# For each -unbound variant the probe also unpacks the TypeScript bytes of the shape with that
# scheme and reports on stderr whether they read (the unbound form packs nothing).
# `coll-<type>`, `other-row`(-unbound) and `nested-other-row` are compiled one translation unit each;
# a shape whose first compile error is in the package's headers is `n/a: does not compile: <error>`.
# Compiler messages go to stderr. Nothing is written into the repository.
# Exit: 0 the probe ran, whatever it found; 1 a build or a run failed (the shapes that could run are
# still printed).
# CXX picks the compiler (default c++); PACKBIN_CXX_SYSROOT is honoured as in cpp/Makefile.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

# Run-time shapes, then the compile-only ones in README order.
shapes=(list-0 list-1 list-3 dict-2)
colls=(coll-std-vector coll-std-array coll-c-array coll-std-list coll-std-map coll-std-unordered-map)
shapes_after=(when times)
others=(other-row nested-other-row)
nulls=(null-member null-item)
# CORE_SRCS of cpp/Makefile.
core=(values pack unpack crypto frame)

cxx="${CXX:-c++}"
# The flags of cpp/Makefile without -Werror: the library is built the embedded way on the host too.
flags=(-std=c++17 -O2 -Wall -Wextra -fno-exceptions -fno-rtti -I "$root/cpp/include")
if [[ -n "${PACKBIN_CXX_SYSROOT:-}" ]]; then
  flags+=(-isysroot "$PACKBIN_CXX_SYSROOT" -I "$PACKBIN_CXX_SYSROOT/usr/include/c++/v1")
fi

# The define of a shape: SHAPE_<NAME>, upper case, `-` as `_`.
define_of() {
  local define
  define="SHAPE_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
  printf '%s' "${define//-/_}"
}

# The build, pack and unpack cells of a probe line, with the place of a compile error left out (two
# overloads of the same rule stop the compiler at different lines).
cells_of() {
  printf '%s\n' "$1" | cut -f 3- | sed -E 's/^(n\/a: does not compile: |refused: compile error: )[^ ]+:[0-9]+:[0-9]+: /\1/'
}

# Prints the line of a variant: on stdout when its outcome differs from the line of its shape, else
# on stderr. The outcome is the same when the cells are equal, or when the variant is the constant
# form and both schemes are refused at build.
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
    what="threw: signal $((status - 128)) ($(kill -l "$((status - 128))"))"
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

# The probe binary $1 unpacks the TypeScript bytes of shape $2 (a report on stderr). A signal there
# is reported, not a failure of the run.
read_reference() {
  local status=0
  "$1" "$2" reference </dev/null >&2 || status=$?
  if ((status != 0)); then
    printf 'probe: %s reading the TypeScript bytes ended with status %s\n' "$2" "$status" >&2
  fi
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

# A diagnostic with the checkout's path left out, on one line.
short() {
  local text="$1"
  text="${text//"$here"\//}"
  text="${text//"$root"\//}"
  printf '%s' "$text" | tr -s '[:space:]' ' '
}

# The refusal a failed build of a constant scheme reports, on one line; status 1 when the failure is
# not the package's. The package refuses a constant scheme by stopping the compiler in its own
# headers: it calls a function that is not constexpr on purpose (the stoppers of codec.hpp and
# table.hpp), or a static_assert fails. So the first error, or a note of it, must be at a line of
# cpp/include/packbin and say one of the two.
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
  short "$first"
}

# Compiles probe.cpp with the extra flags $3... into the binary $1 (its log $1.log); status 1 when
# the compile failed, 2 when the link failed.
build_unit() {
  local bin="$1" label="$2"
  shift 2
  if ! "$cxx" "${flags[@]}" "$@" -c -o "$bin.o" "$here/probe.cpp" 2>"$bin.log"; then
    return 1
  fi
  cat "$bin.log" >&2
  if ! "$cxx" "${flags[@]}" -o "$bin" "$bin.o" "${objects[@]}" >&2; then
    printf 'run.sh: the link of %s failed\n' "$label" >&2
    return 2
  fi
}

# The line of one shape built as a constant; status 1 when that build or its run failed.
constexpr_line() {
  local shape="$1" label="$1-constexpr" bin refusal status=0
  bin="$out/$label"
  build_unit "$bin" "$label" -DPROBE_CONSTEXPR "-D$(define_of "$shape")" || status=$?
  if ((status == 0)); then
    run_shape "$bin" "$shape" "$label" || return 1
    return 0
  fi
  if ((status == 2)); then
    return 1
  fi
  cat "$bin.log" >&2
  if ! refusal="$(package_refusal "$bin.log")"; then
    printf 'run.sh: the build of %s failed and it is not the package that stopped the compiler\n' \
      "$label" >&2
    return 1
  fi
  printf 'cpp\t%s\trefused: compile error: %s\t-\t-\n' "$label" "$refusal"
}

# The line of a compile-only shape; status 1 when its build failed outside the package's headers or
# its run failed.
compiled_line() {
  local shape="$1" bin first status=0
  bin="$out/$shape"
  build_unit "$bin" "$shape" -DPROBE_ONLY "-D$(define_of "$shape")" || status=$?
  if ((status == 0)); then
    run_shape "$bin" "$shape" || return 1
    return 0
  fi
  if ((status == 2)); then
    return 1
  fi
  cat "$bin.log" >&2
  first="$(first_error_of "$bin.log" | head -n 1)"
  if [[ "$first" != "$root/cpp/include/packbin/"* ]]; then
    printf 'run.sh: the build of %s failed outside the package headers\n' "$shape" >&2
    return 1
  fi
  printf 'cpp\t%s\tn/a: does not compile: %s\t-\t-\n' "$shape" "$(short "$first")"
}

objects=()
for name in "${core[@]}"; do
  "$cxx" "${flags[@]}" -c -o "$out/$name.o" "$root/cpp/src/core/$name.cpp" >&2
  objects+=("$out/$name.o")
done
"$cxx" "${flags[@]}" -o "$out/probe" "$here/probe.cpp" "${objects[@]}" >&2

failed=0

# A run-time shape, its -unbound variant and its constant form.
runtime_shape() {
  local shape="$1" line other
  if ! line="$(run_shape "$out/probe" "$shape")"; then
    failed=1
    return
  fi
  printf '%s\n' "$line"
  if other="$(run_shape "$out/probe" "$shape-unbound")"; then
    print_variant "$line" "$other"
    read_reference "$out/probe" "$shape-unbound"
  else
    failed=1
  fi
  if other="$(constexpr_line "$shape")"; then
    print_variant "$line" "$other"
  else
    failed=1
  fi
}

# A compile-only shape; other-row has an -unbound variant.
compiled_shape() {
  local shape="$1" line other
  if ! line="$(compiled_line "$shape")"; then
    failed=1
    return
  fi
  printf '%s\n' "$line"
  if [[ "$shape" == other-row ]]; then
    if other="$(compiled_line "$shape-unbound")"; then
      print_variant "$line" "$other"
    else
      failed=1
    fi
  fi
}

for shape in "${shapes[@]}"; do
  runtime_shape "$shape"
done
for shape in "${colls[@]}"; do
  compiled_shape "$shape"
done
for shape in "${shapes_after[@]}"; do
  runtime_shape "$shape"
done
for shape in "${others[@]}"; do
  compiled_shape "$shape"
done
for shape in "${nulls[@]}"; do
  if line="$(run_shape "$out/probe" "$shape")"; then
    printf '%s\n' "$line"
  else
    failed=1
  fi
done
exit "$failed"
