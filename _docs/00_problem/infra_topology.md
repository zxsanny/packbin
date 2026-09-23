# Infrastructure Topology

## Push targets (VCS redundancy)

| Remote | URL | Role | Host kind |
|--------|-----|------|-----------|
| origin | https://github.com/zxsanny/packbin | primary | github |

## Host roles

| Role | Host | Notes |
|------|------|-------|
| dev | (local workstation) | |
| ci | github.com | Tests on every push and pull request. A version tag publishes. |

## Platform inventory

| Component | Host | Type / URL | Status | Notes |
|-----------|------|------------|--------|-------|
| git | github.com | https://github.com/zxsanny/packbin | present | local checkout on `dev` |
| builder | github.com | GitHub Actions | intended | tests on push and pull request |
| registry | npmjs.org | npm `packbin` | intended | first version tag |
| registry | nuget.org | NuGet `Packbin` | intended | first version tag, same commit as npm |
| registry | pypi.org | `packbin` | intended | first version tag, Python |
| registry | crates.io | `packbin` | intended | first version tag, Rust |
| registry | Maven Central | `packbin` | intended | first version tag, Java |
| registry | vcpkg | `packbin` | intended | first version tag, C++ |
| deploy | — | — | N/A | no server; a registry publish is the release |
