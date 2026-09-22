# CI/CD pipeline

Host: GitHub Actions on `https://github.com/zxsanny/packbin`.

| Stage | When | Gate |
|-------|------|------|
| Test | every push and every pull request | a failing test fails the check |
| Publish | a version tag, after the golden bytes match | mismatch count greater than 0 publishes 0 packages |

The first tag publishes npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin`, and vcpkg `packbin` from the same commit. A language that is not in the tree is not published. Registry tokens come from GitHub Actions secrets. The test job does not need them.

Lint and the byte tests run in the test stage. There is no separate security scanner stage in this plan. The publish stage is the deploy.
