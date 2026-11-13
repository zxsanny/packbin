---
title: "Build the embedded image with docker buildx build --allow network.host --network host, not compose network: host"
applies_when: "changing the embedded image build in cpp/embedded/run.sh, or a CI-only Docker build failure"
source: "loop 106 (AZ-4191, two red pushes)"
---

BuildKit refuses a host-network image build unless it is told so: `network: host` in compose, even with `COMPOSE_BAKE=false`, fails on the CI runner with `additional privileges requested: pass "--allow=network.host"` (loop 106, AZ-4191, two red pushes). The Mac's Compose 2.24 has no Bake and accepts it, so the Mac cannot show the failure.

The embedded image is built by `docker buildx build --allow network.host --network host` in `cpp/embedded/run.sh`; read a CI-only Docker failure with `gh api --allow-escape-sequences repos/zxsanny/packbin/actions/jobs/<id>/logs` while the run is still in progress (`gh run view --log-failed` waits for the whole run).
