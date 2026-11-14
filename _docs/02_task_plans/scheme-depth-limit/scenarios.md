# Scenarios — scheme-depth-limit

| id | actor / trigger / state | behavior | status | AC |
|----|------------------------|----------|--------|----|
| S1 | a developer builds a scheme of 256 nested containers | builds; pack and unpack give the same bytes as before | confirmed | per-package AC-2 |
| S2 | a scheme of 257 nested `when`s or groups | refused at build with the package's scheme error and the shared text; nothing is packed | confirmed | per-package AC-1 |
| S3 | a scheme of 50,000 levels (a hostile or generated scheme) | refused at build quickly (under 5 s), no stack error, no crash | confirmed | per-package AC-4 |
| S4 | existing schemes (a handful of levels) | unchanged | confirmed | per-package AC-5 |
| S5 | a list or dict element row chain, a repeat or times round body at 256 | builds, packs and unpacks (where the package has the form) | confirmed | per-package AC-2 |
| S6 | Rust heap-free API at 257 levels | refused by the new depth check; at 50,000 its own `MAX_FIELDS` refusal still applies | confirmed | AZ-4302 AC-1 |
| S7 | the C++ `constexpr` form at 257 levels | refused at compile time | confirmed | AZ-4303 AC-1 |
| S8 | a package that cannot run 256 levels of a kind at the default stack | blocker, reported; the limit is not lowered by the agent | confirmed | AZ-4297 AC-2 |
