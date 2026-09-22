# Source registry — Phase 1

| # | Tier | Source | What it settles |
|---|------|--------|-----------------|
| 1 | L1 | https://dotnet.microsoft.com/en-us/platform/support/policy | .NET 10 is the active LTS through 2028-11-14. .NET 8 LTS ends 2026-11-10. |
| 2 | L1 | https://learn.microsoft.com/en-us/dotnet/core/releases-and-support | Same support window, second official page. |
| 3 | L1 | https://github.com/nodejs/release | Node 24 is Active LTS. Node 26 enters LTS on 2026-10-28. |
| 4 | L1 | https://nodejs.org/en/about/previous-releases | Node production guidance is Active or Maintenance LTS. |
| 5 | L2 | https://github.com/MessagePack-CSharp/MessagePack-CSharp/blob/master/README.md | C# MessagePack serializes a 9-field object in about 73–218 ns. |
| 6 | L3 | https://github.com/kriszyp/msgpackr/blob/master/benchmark.md | Node msgpackr packs a small object at roughly 1.7–2 µs (Node 14, older CPU). |
| 7 | L1 | https://protobuf.dev/programming-guides/serialization-not-canonical/ | Protobuf does not promise identical bytes across languages. |
| 8 | L1 | https://github.com/protocolbuffers/protobuf/tree/main/conformance | Protobuf conformance compares decoded messages. Exact wire bytes are a separate flag. |
| 9 | L1 | https://doc.kaitai.io/serialization.html | Kaitai write support is Java and Python. Other targets parse only. |
| 10 | L1 | https://kaitai.io/news/2025/09/07/kaitai-struct-v0.11-released.html | 0.11 release repeats that write support is Java and Python. |
| 11 | L1 | https://docs.python.org/3/library/struct.html | `struct.unpack` requires the buffer size to match. An integer outside the format range raises `struct.error`. Network exchange must name endian explicitly. |
| 12 | L1 | https://docs.npmjs.com/trusted-publishers/ | npm publishes from GitHub Actions with OIDC. No long-lived npm token required. |
| 13 | L1 | https://learn.microsoft.com/en-us/nuget/nuget-org/trusted-publishing | NuGet publishes from GitHub Actions with a short-lived key from OIDC. |
| 14 | L1 | https://docs.github.com/en/actions/tutorials/publish-packages/publish-nodejs-packages | GitHub documents publish on a release event after CI. |
| 15 | L1 | https://learn.microsoft.com/en-us/dotnet/api/system.buffers.binary.binaryprimitives.writeint32littleendian | Writes exactly 4 little-endian bytes. No tag. |
| 16 | L1 | https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView/setInt32 | `littleEndian` selects the byte order. No tag. |
| 17 | MVE | `_docs/00_research/raw/mve/position.mjs` and `_docs/00_research/raw/mve/cs/Program.cs` | Both runs printed the 13-byte fixture. Node 17.4 ms, .NET 1.8 ms, for 100000 round trips. |
