# Autodev Loop Plan — Loop 2

loop: 2
kind: product
confirmed: true
branch: loop/2-strings-lists-dicts
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | Specs already in todo/ |
| decompose-feature | 9.5 | Decompose Feature | yes | Handed off at 13 points; AZ-1938..AZ-1941 already written |
| implement | 10 | Implement | yes | String, list, and dictionary tasks, plus flag group, sized bytes, and bit pack already in the tree |
| feature-assess | 10.5 | Feature Assessment | yes | Always after implement |
| run-tests | 11 | Run Tests | yes | Always |
| test-spec-sync | 12 | Test-Spec Sync | yes | New acceptance scenarios for the added field kinds |
| update-docs | 13 | Update Docs | yes | Public pack API gained group, sized, u2, bits, and typed object pack |
| security | 14 | Security Audit | no | security_report.md is dated 2026-09-23; no auth, secret, or network surface |
| performance | 15 | Performance Test | no | No new latency or throughput acceptance criterion |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | Deploy is not in this loop |
| migration | 16.7 | Data/Traffic Cutover | no | No data store or traffic cut |
| retrospective | 17 | Retrospective | yes | Feature complexity is above 5 |
| local-deploy | — | Local deploy + open site | yes | Always at close |
| smoke | — | Smoke acceptance | yes | Always at close |

## Implementation

### Files that change
Six language packages. String, list, and dictionary landed in each language packer. Language-pair drivers live under `.github/workflows/drivers/`.

### Order of work
Flag group, sized bytes, bit pack, UTF-8 string, counted list, and dictionary are coded. AZ-1941 hands the packed bytes from one language to the next.

### Proof
Each language suite packs and unpacks the task hex with zero mismatched bytes. `.github/workflows/language-pair.sh` runs the six user handoffs, the six nested handoffs, and the position record.

### Risks
A count that includes its own two bytes finishes inside the payload. Dict key order must be identical in every language.
