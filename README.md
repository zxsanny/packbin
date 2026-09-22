# packbin

This repository owns packing, unpacking, and the data schema shared by C#, Vue, and Android. It is in implementation.

Declarative pack and unpack for a binary layout you already chose. The schema stays off the wire, so a packet stays the size you described.

C# and TypeScript are the first packages. Vue and React use the TypeScript package. Python, Rust, and Kotlin follow the same field rules when those runtimes need the bytes.

| Doc | What it settles |
|-----|-----------------|
| [`_docs/00_problem/problem.md`](_docs/00_problem/problem.md) | Who hurts, and what packbin refuses to do |
| [`_docs/01_solution/solution.md`](_docs/01_solution/solution.md) | Walker, packages, and what was rejected |
| [`_docs/01_solution/schema.md`](_docs/01_solution/schema.md) | How a packet is declared in C# and TypeScript |
| [`_docs/01_solution/languages.md`](_docs/01_solution/languages.md) | Which languages, in which order |
| [`_docs/04_deploy/packages.md`](_docs/04_deploy/packages.md) | GitHub plus npm and NuGet |
