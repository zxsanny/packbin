# Expected results — loop 82

Source of the HEAD figures: `.github/workflows/*.sh` at commit 5a78fb8, read on 2026-10-29 on a host without Ruby; HEAD verdicts of the precheck are the rows of `publish-precheck.test.sh`. Run counts of the other scripts at HEAD are not measured on this host (no Ruby) and are listed in the task's probe (labels counted from source) before the port starts.

## P: `publish-precheck.sh` (stub `curl`, `PACKBIN_SHA` 2cade74a9c111422f864e59c5175aac09c6e0bad)

| Input (change to a green push run of `test.yml`) | Expected `$GITHUB_OUTPUT` | Exit |
|---|---|---|
| none (a green push run) | `green=true` | 0 |
| no run at all (`workflow_runs: []`) | `green=false` | 0 |
| `conclusion` failure / cancelled | `green=false` | 0 |
| `status` in_progress | `green=false` | 0 |
| `event` pull_request | `green=false` | 0 |
| `head_sha` another commit | `green=false` | 0 |
| `path` `.github/workflows/publish.yml` | `green=false` | 0 |
| `head_repository.full_name` `someone/packbin` | `green=false` | 0 |
| `path` `.github/workflows/test.yml@refs/heads/dev` | `green=true` | 0 |
| curl exits 22 | `green=false`, stdout names `runs API call failed` | 0 |
| answer `not json` | `green=false` | 0 |
| answer `{}` | `green=false` | 0 |
| `PACKBIN_SHA` empty / `abc` / upper case hex; `PACKBIN_REPO` `not a repo` | nothing written | 2 |

The request holds `workflows/test.yml/runs`, `head_sha=<sha>`, `event=push`, `status=success` and `Authorization: Bearer <token>`; the token is in neither stdout nor the output file.

## E: `if:` evaluator

| Input | Expected |
|---|---|
| each `if:` of `publish.yml` and `test.yml` that HEAD evaluates | the same boolean for the same context as at HEAD |
| an `if:` with a term outside the supported set | refused with a message naming the term |
| an `if:` that does not evaluate (unbalanced paren) | refused with a message |
| an `if:` with `'`, `;`, a backtick or `$(` | refused before evaluation |

## Y: `on:` quirk

| Workflow text | Triggers read |
|---|---|
| `on: [push]` (PyYAML loads the key `True`) | `push` |
| `"on": [push]` (quoted key) | `push` |

## S: run without Ruby (this host: no `ruby`, no `java`, python 3.14.4, PyYAML 6.0.3)

| Script | Expected |
|---|---|
| the 10 scripts of the problem table | exit 0, no `ruby` in the output, no check dropped |
| each script on one deliberate mutation | exit non-zero, the failed check named |
| `grep -rIi ruby .github/workflows` | 0 matches |
