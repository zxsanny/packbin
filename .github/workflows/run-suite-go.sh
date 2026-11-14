#!/usr/bin/env bash
# The go helpers of run-suite.sh (AZ-4288), sourced from its `go` case so that file stays under 500 lines,
# as run-suite-dart.sh is. The caller runs each step through `run`; every step works in the module directory $1.
# shellcheck disable=SC2154

# Go (golang:1.27): every step runs in the module directory $1 through `go -C`.
go_fmt() {
  local unformatted
  unformatted="$(cd "$1" && gofmt -l .)" || return 1
  if [ -n "$unformatted" ]; then
    printf 'run-suite: gofmt -l lists files that are not gofmt-formatted:\n%s\n' "$unformatted" >&2
    return 1
  fi
}

# The 60 s fuzz run of the package that has the FuzzUnpack target (AZ-2444). Until that target
# exists the step says it is skipped; the line goes away by itself once the target is there.
go_fuzz() {
  local listed pkg
  listed="$(go -C "$1" test -list '^FuzzUnpack$' ./...)" || return 1
  pkg="$(printf '%s\n' "$listed" | awk '$0 == "FuzzUnpack" { found = 1; next } /^ok[ \t]/ { if (found) { print $2; exit } }')"
  if [ -z "$pkg" ]; then
    echo "run-suite: go fuzz step skipped: the package has no FuzzUnpack target yet"
    return 0
  fi
  # -fuzzminimizetime=0: the default minimises every new input for up to 60 s, which left 121k execs in a 60 s run
  # (1.4M without it, AZ-2444 report).
  go -C "$1" test -run='^$' -fuzz='^FuzzUnpack$' -fuzztime=60s -fuzzminimizetime=0 "$pkg"
}

# One dependency at most (GO-11, G-3): go.mod's direct requirements and the modules of every package
# the package and its tests build are the main module and golang.org/x/crypto. `go list -m all` alone
# cannot be the check: it always lists x/crypto's own requirements (x/sys, x/net, x/term, x/text).
go_deps() {
  local main direct built extra
  main="$(go -C "$1" list -m)" || return 1
  direct="$(go -C "$1" list -m -f '{{if not (or .Main .Indirect)}}{{.Path}}{{end}}' all)" || return 1
  built="$(go -C "$1" list -deps -test -f '{{with .Module}}{{.Path}}{{end}}' ./...)" || return 1
  extra="$(printf '%s\n%s\n' "$direct" "$built" | grep -vxF -e '' -e "$main" -e 'golang.org/x/crypto' | sort -u)"
  if [ -n "$extra" ]; then
    printf 'run-suite: go depends on modules other than golang.org/x/crypto:\n%s\n' "$extra" >&2
    return 1
  fi
}
