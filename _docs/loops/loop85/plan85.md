# Autodev Loop Plan — Loop 85

loop: 85
kind: product
confirmed: true
branch: dev
ship: false

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` done (AZ-3412, AZ-3413) |
| decompose-feature | 9.5 | Decompose Feature | no | 2 points in total |
| implement | 10 | Implement | yes | always |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario of the product changed |
| update-docs | 13 | Update Docs | no | no public contract changed |
| security | 14 | Security Audit | no | no auth, secret or exposure touched |
| performance | 15 | Performance Test | no | no perf NFR |
| deploy | 16 | Deploy | no | ship false |
| release | 16.5 | Release | no | deploy not included |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | 2 points, no incident, retro of loop 84 is the last |
| local-deploy | — | Local deploy + open site | yes | always at close |
| smoke | — | Smoke acceptance | yes | always at close |
