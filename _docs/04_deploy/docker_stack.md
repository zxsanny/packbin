# Docker stack

Production compose is not used. `docker-compose.test.yml` is the test stack. `docker-compose.publish.yml` is a second file that only the publish scripts pass after it (`publish_container` in `.github/workflows/publish-lib.sh`); it mounts the repo read-only in the golden-gate and build containers. Never pass it to the test suites.
