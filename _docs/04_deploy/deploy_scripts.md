# Deploy scripts

No `scripts/deploy.sh`. The publisher is `.github/workflows/publish.yml`, which runs on a `v*` tag after `publish-gate.sh`. A local script that uploads the same registries would be a second publisher.
