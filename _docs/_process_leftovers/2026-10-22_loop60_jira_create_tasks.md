# Leftover: Jira task creation of loop 60 (2026-10-22)

kind: tracker
blocked action: createJiraIssue for four tasks under epic AZ-2645 (two of loop 60, one of loop 61, one of loop 62), then transition them to "In Testing" at loop close
reason: the Atlassian connector is not available in this session (no Jira tool found by ToolSearch, retried once); no write was attempted by another path.

Replay payload (cloudId 1598226f-845f-4705-bcd1-5ed0c82d6119, project AZ, parent AZ-2645, type Task):
- "C++ dict key order test: print the Error, do not pack a refused key" — spec `_docs/02_tasks/done/AZ-PENDING_cpp_dict_key_order_error_report.md`
- "Rust nostd corpus count: kind and lowercase hex, no Vec per line" — spec `_docs/02_tasks/done/AZ-PENDING_rust_nostd_corpus_kind_hex_rule.md`
- "C++ pack side held_of: measure the flash and stack cost" (loop 61, 2 points, measured and not kept) — spec `_docs/02_tasks/done/AZ-PENDING_cpp_pack_held_of_measure.md`
- "C++ Field layout: drop the Array-only count pointer from every table entry" (loop 62, 3 points, flash 8,032 B to 7,808 B) — spec `_docs/02_tasks/done/AZ-PENDING_cpp_field_layout_shrink.md`

Search by key range before creating (a timeout can hide a create that landed). Then rename the four spec files (in `done/`) and the `Tracker:` lines to the new keys, and replay `2026-10-22_loop59_jira_in_testing.md`.
