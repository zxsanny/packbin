# Loop 88 smoke — proposed checks

LOCAL_URL: none (docs-only loop, no deploy, no UI)
Branch: dev

## Perform these checks by reading `_docs/04_deploy/release_notes_0.4.0.md`

- [ ] The body between the two rules reads as a release body in the shape of the 0.3.0 release (summary, New, Breaking changes, Build and CI, Install).
- [ ] Breaking changes names all three: the stream session (`PackSession`) removed, strings written differently (peers must upgrade together), dictionary keys must be strictly ascending.
- [ ] The New list matches what you shipped: compact text, message ECC, frame session in eight languages, Rust `nostd`, nRF54L15 target, compiled npm package. Nothing is missing that you want announced.
- [ ] The Install table has the right version (0.4.0) and registries.
- [ ] The publisher section is accurate: version comes from the tag, CS-D5 before the tag, no tag ruleset (F44).
- [ ] Nothing was tagged, published or uploaded: `git tag` still ends at `v0.3.0`.

## Notes
Figures come from `fixtures/text/tables.report.md` and the contract headers (`compact-text` 1.0.0, `message-ecc` 1.0.1, `pack-session` 3.0.0). No credentials involved.
