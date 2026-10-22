# Leftover: Jira task creation of loop 60 (2026-10-22)

kind: tracker
blocked action: createJiraIssue for two tasks under epic AZ-2645, then transition them to "In Testing" at loop close
reason: the Atlassian connector is not available in this session (no Jira tool found by ToolSearch, retried once); no write was attempted by another path.

Replay payload (cloudId 1598226f-845f-4705-bcd1-5ed0c82d6119, project AZ, parent AZ-2645, type Task):
- "C++ dict key order test: print the Error, do not pack a refused key" — spec `_docs/02_tasks/todo/AZ-PENDING_cpp_dict_key_order_error_report.md`
- "Rust nostd corpus count: kind and lowercase hex, no Vec per line" — spec `_docs/02_tasks/todo/AZ-PENDING_rust_nostd_corpus_kind_hex_rule.md`
Search by key range before creating (a timeout can hide a create that landed). Then rename the spec files and the `Tracker:` lines to the new keys, and replay `2026-10-22_loop59_jira_in_testing.md`.
