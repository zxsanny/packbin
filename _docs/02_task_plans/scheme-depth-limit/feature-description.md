# Feature: a scheme is nested at most 256 levels deep (loop 126)

Owner decision D18 (2026-11-14, "Shared limit (256)"): every package refuses, when the scheme is built, a scheme nested deeper than 256 levels, with its own scheme error and one shared text. Evidence: `_docs/06_metrics/scheme-depth-probe_2026-11-14.md` (nine packages, none had a limit). The rule is the contract `_docs/02_document/contracts/library/scheme-depth.md` (1.0.0).

Tasks: AZ-4294 shared (cases, README, contract text), then AZ-4295 TypeScript, AZ-4296 C#, AZ-4297 Python, AZ-4298 Java, AZ-4299 Go, AZ-4300 Swift, AZ-4301 Dart, AZ-4302 Rust, AZ-4303 C++, one loop. Done when `scripts/probes/scheme-depth/run.sh` prints `refused` at depths 1,000, 5,000 and 50,000 in every package (Rust nostd: its own `MAX_FIELDS` refusal at 50,000 stays), no `threw`, `crashed` or timeout line, and 256 levels still build, pack and unpack in each package.

## Scenarios

See `scenarios.md`.

## Fit decisions

- Limit 256 (owner). Python stops working between 400 and 500 levels of a `when` / group chain; 256 levels of every container kind must still run there at the default recursion limit: AC of AZ-4297; if it does not, report and stop (the limit is the owner's).
- The depth is measured iteratively and first: no package may add a recursive walk before it.
