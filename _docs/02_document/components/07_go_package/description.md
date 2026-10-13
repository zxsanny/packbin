# Go package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for Go services, with the same bytes as the other six packages.

**Architectural Pattern**: stateless clear pack, plus a session the caller holds (as the TypeScript package).

**Upstream dependencies**: none inside the repo. Outside: the Go standard library and `golang.org/x/crypto` (ChaCha20 only).

**Downstream consumers**: Go services, fetched with `go get github.com/zxsanny/packbin/go@vX.Y.Z` from the `go/vX.Y.Z` tag (ADR-004).

## 2. Interfaces

Same shape as TypeScript (`components/02_typescript_package/description.md` §2): a scheme built from fields by order id (construction returns an error, never panics), `Pack(scheme, row) ([]byte, error)`, unpack with first-byte dispatch over a scheme list returning a row or an error value, `WithLimits` (`maxRounds` 65 535, `maxSlots` 1 048 576, `maxBytes` 16 777 216), and `PackSession` start/join/pack/unpack (`contracts/library/pack-session.md`).

Rows: a typed struct bound by getter/setter closures per field, or `map[string]any` (a nested-row group reads the nested map, U26 A). A nil pointer or nil slice is no value; an empty slice is a value with 0 items (G-5).

## 3. Rules

Go copies TypeScript row for row (loop 24 fit decision 4), except the documented TypeScript-only exceptions (U6), where it follows the five. A built scheme is safe for concurrent use; a session is used by one goroutine at a time.

## 4. Decisions

`_docs/02_task_plans/go-package/problem.md` G-1 to G-6 (owner, 2026-10-13); ADR-001, ADR-004.
