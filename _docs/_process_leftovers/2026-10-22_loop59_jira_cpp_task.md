# Leftover: Jira create of the loop 59 C++ task (2026-10-22)

kind: tracker
blocked action: createJiraIssue, then getJiraIssue AZ-3164 (both timed out, twice for the read)
reason: Atlassian MCP "Tool call timed out waiting for server response" after AZ-3163 was created; the create of the second task is unconfirmed (AZ-3164 may or may not exist).

Replay payload (check `project = AZ AND key > AZ-3163` first; create only when absent):
- cloudId 1598226f-845f-4705-bcd1-5ed0c82d6119, projectKey AZ, issueType Task, parent AZ-2645
- summary: C++ dict key order test: guard put_key length, name each refusal
- description: Test-only (cpp/tests/core/dict_order_host_tests.cpp). put_key copies n bytes into Text<4> unchecked; packs_in_order reports every refusal with one message. Guard n against the key capacity and return the Error so each pair asserts its own message. Loop 59, 2 points.

After the key is known: rename `_docs/02_tasks/todo/AZ-PENDING_cpp_dict_key_order_checks.md` to that key, and fix the key in the plan, dependencies table and commit subjects.
