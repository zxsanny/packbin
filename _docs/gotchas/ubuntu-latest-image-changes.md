---
title: "ubuntu-latest changes under the workflow: compare runner image versions first when a push that changed no workflow goes red"
applies_when: "a CI job fails on a push that changed no workflow, or a toolchain check fails on the runner"
source: "loop 113 (image 20261111 brought .NET 11.0.100, the ring job failed its toolchain check)"
---

`ubuntu-latest` is `ubuntu-26.04` and its image changes under the workflow (loop 113: image `20261101` green at 10:46 UTC, image `20261111` red at 16:25 UTC): the new image has a .NET 11.0.100 SDK that `dotnet --version` returns first, so the `ring` job failed its toolchain check (`toolchain dotnet: found 11.0.100, the suites use 10.0`) although `setup-dotnet` had installed 10.0.404.

The SDK is pinned by the root `global.json` (`10.0.100`, `rollForward: latestFeature`: any 10.0 SDK, never 11); a CI failure on a push that changed no workflow starts with the runner image version at the top of the job log (`gh api repos/zxsanny/packbin/actions/jobs/<id>/logs`, the `Image:` and `Version:` lines) and the last green run's.
