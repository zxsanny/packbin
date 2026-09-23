# CI/CD pipeline

## Loop-end channel (ordinary product loops)

loop_end_merge: stage

## Pipeline

GitHub Actions. `test.yml` runs on every push and pull request. `publish.yml` runs on a `v*` tag.

## Post-deploy polling (agent configuration)

enabled: no

There is no deploy host to probe. The test and publish results are the GitHub Actions checks.
