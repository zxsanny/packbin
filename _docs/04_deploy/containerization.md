# Containerization

The product is a library. It has no runtime container. `docker-compose.test.yml` runs the six language suites and the two C++ embedded services (`cpp-embedded`, `cpp-embedded-esp`). No port is published. No database. No GPU. The publish golden gate and build containers use the same services with `docker-compose.publish.yml` added, which mounts the repo read-only (`ci_cd_pipeline.md`).

Canonical write-up: `_docs/02_document/deployment/containerization.md`.
