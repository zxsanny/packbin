# Static analysis

**Date**: 2026-09-23

Searched product and workflow sources for command execution, `eval`, deserialization, SQL, HTML injection, and embedded secrets.

No matches in the six language packages. Registry tokens appear only as GitHub Actions `secrets.*` references and empty names in `.env.example`. `publish-inside.sh` writes the npm token into a temp npmrc at publish time and does not commit it. `GIT_ASKPASS` in `publish-registries.sh` keeps `$GITHUB_TOKEN` unexpanded in the helper script.

No code findings.
