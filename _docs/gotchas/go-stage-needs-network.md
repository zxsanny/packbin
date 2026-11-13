---
title: "The compose go stage needs outbound network from the container; check proxy.golang.org first"
applies_when: "running scripts/loop-tests.sh (the go stage) on a hotspot or a restricted network"
source: "loop 58 (iPhone hotspot, connection refused)"
---

The compose `go` service has no module cache, so `scripts/loop-tests.sh` needs outbound network from the container on every run (loop 58): on an iPhone hotspot containers got `connection refused` to every host (DNS worked, the Mac itself reached named sites; `ifconfig en0` said `constrained`) and restarting Docker Desktop did not help.

Join a normal network, check that this prints 200:

```
docker run --rm golang:1.27 curl -4 -sS -m 10 -o /dev/null -w '%{http_code}' https://proxy.golang.org
```

then `scripts/loop-tests.sh --only go`. Never count the cached-volume `docker run` of the Go suite as the compose stage.
