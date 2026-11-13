---
title: "Never type a TypeScript class member with a symbol that needs a newer lib: define it at runtime"
applies_when: "adding a TypeScript member keyed by a newer-lib symbol (Symbol.dispose), or reading a publish-timing.selftest.sh failure at high load"
source: "loop 75 (publish gate AZ-2103 AC-2)"
---

A TypeScript class member typed with a symbol that needs a newer `lib` (`[Symbol.dispose]`, `/// <reference lib="esnext.disposable" />`) lands in the emitted `.d.ts` and breaks every consumer on lib ES2022 (loop 75, publish gate AZ-2103 AC-2): define such a property at runtime through `Object.defineProperty` with the symbol read from `Symbol as unknown as {...}`, and check `grep -rn dispose <outDir>/*.d.ts` after `tsc -p tsconfig.build.json --outDir <tmp>`.

`publish-timing.selftest.sh` printed `printf: write error: Broken pipe` and failed once at host load near 100 (its `printf | grep -q` pipes under `pipefail`); it passed alone at load 12.
