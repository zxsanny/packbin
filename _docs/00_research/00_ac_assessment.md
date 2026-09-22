# Acceptance Criteria Assessment

Phase 1 only. No acceptance criterion or restriction file was edited.

## Acceptance Criteria

| Criterion | Our Values | Researched Values | Cost/Timeline Impact | Status |
|-----------|-----------|-------------------|---------------------|--------|
| AC-1–AC-3 golden bytes | 13-byte fixture, 0 mismatches across C# and TypeScript | Protobuf conformance compares values, not bytes, because Protobuf bytes are not canonical. A fixed layout can require 0 mismatches. Kaitai can describe that layout but writes only Java and Python. | A shared hex fixture. No extra service. | Unchanged |
| AC-4–AC-9 omission, short packet, trailing bytes | Clear bit adds 0 bytes; short or trailing input returns an error and 0 values | Python `struct.unpack` requires the buffer size to match the format. CBOR users treat trailing bytes as a correctness flag when one buffer is one message. | Fixture tests already named in the problem. | Unchanged |
| AC-10 speed | 100000 round trips ≤ 1 second on one core (10 µs each) | C# MessagePack is about 73–218 ns per small-object call. A fast Node pack of a small object is about 2 µs. The written bar is several times looser than those. | One timed loop. Tightening it would pull in allocation work that was declined. | Unchanged |
| AC-11 CI | Tests on 100% of pushes and pull requests | GitHub Actions is the documented CI for this host. | One workflow. Public GitHub repos run it without a paid plan for normal use. | Unchanged |
| AC-12–AC-15 publish | Version tag publishes one package per language in the tree; 0 packages on a golden mismatch; first tag is npm + NuGet | npm and NuGet both document publish from GitHub Actions. Trigger on a release or tag is the documented pattern. | One publish job. Registries are free for public packages. | Unchanged |
| AC-16 license | MIT, 0 other identifiers | MIT is an SPDX identifier both registries accept. | A license field in each package. | Unchanged |
| Out-of-range integer | Not written | Python `struct.pack` raises `struct.error` when an integer is outside the format range. Two languages that truncate instead of failing can still match each other and disagree with the caller. | One error fixture per width. | Proposed — not written |
| Float bit round-trip | Not written | Fixed-width IEEE floats are the usual companion to the integer formats. No numeric float check exists yet. | One finite value and the two infinities, 0 bit mismatches. NaN payloads left out. | Proposed — not written |
| Same bytes on both host endians | Not written | Python's struct docs say bytes that leave the process must name endian, because host endian differs. AC-1 already pins the sample as little-endian hex. | The outcome can be checked without a second machine. | Proposed — not written |

## Restrictions Assessment

| Restriction | Our Values | Researched Values | Cost/Timeline Impact | Status |
|-------------|-----------|-------------------|---------------------|--------|
| .NET runtime | Current .NET LTS at first publish | On 2026-09-22 that line is .NET 10, supported until 2028-11-14. .NET 8 ends 2026-11-10. Leaving the phrase unpinned stays correct at publish time. | Target the LTS that is current when the first tag is cut. | Unchanged |
| Node runtime | Current Node LTS at first publish | On 2026-09-22 that line is Node 24. Node 26 enters LTS on 2026-10-28. The unpinned phrase stays correct. | Same as .NET. | Unchanged |
| First languages | C# and TypeScript only | Matches the gap Kaitai leaves: those two cannot write from one Kaitai spec today. | Two packages. | Unchanged |
| No wire tags | Bytes are only the fields | That is why 0 mismatched bytes is testable here and is not testable for Protobuf. | No format tax. | Unchanged |
| Publish credentials | Registry credentials stay in the CI secret store | npm and NuGet now document OIDC trusted publishing from GitHub Actions, so a long-lived token is optional. | A trusted-publisher policy on each registry. No secret to rotate for the preferred path. | Proposed change — not written |
| License, deadline, no server | MIT, no date, no host | Consistent with a public library. No regulatory bar found for this shape. | Maintainer time only. | Unchanged |

## Key Findings

The written numbers are realistic. The speed floor will pass a straightforward walker. The byte-equality checks are the right done line because this format has no tags and no unknown fields.

Three outcomes are missing if the library must fail closed the way Python's struct module does: an integer that does not fit, an IEEE float round-trip, and bytes that do not depend on the host endian. They are not in the files yet.

The publish restriction still says credentials live in CI secrets. Both registries' current docs prefer a GitHub Actions trusted publisher instead.

## Sources

See `01_source_registry.md` and `02_fact_cards.md`.
