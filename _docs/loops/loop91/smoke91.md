# Loop 91 smoke — proposed checks

LOCAL_URL: none (docs only, no app)
Branch: dev

## Perform these checks (read the F44 bullet in `_docs/04_deploy/release_notes_0.4.0.md`, publisher section)

- [ ] The bullet gives the UI settings and one `gh api` command; the JSON is valid and targets `refs/tags/v*` with `update`, `deletion`, `non_fast_forward`.
- [ ] It says no bypass actor and what that costs (a mistaken tag stays until the ruleset is disabled).
- [ ] It says `go/v0.4.0` is outside the pattern and why the publish run is not blocked (`publish-go.sh` creates it; no script touches a `v*` tag).
- [ ] The check is the public rulesets listing; it does not tell you to push a test tag.
- [ ] `git diff HEAD~1 --stat` shows one docs file; nothing was applied to GitHub.
