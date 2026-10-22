# Leftover: Jira transitions of loop 59 (2026-10-22)

kind: tracker
blocked action: transitionJiraIssue AZ-3163 and AZ-3164 to "In Testing"
reason: first call returned "This tool has been disabled in your connector settings."; the Atlassian MCP server then left the session. No transition was written; no other path was tried.

Replay payload (cloudId 1598226f-845f-4705-bcd1-5ed0c82d6119):
- transitionJiraIssue AZ-3163, transitionName "In Testing"
- transitionJiraIssue AZ-3164, transitionName "In Testing"
Read each back with getJiraIssue. Both are children of epic AZ-2645 and were created in this loop (AZ-3163 at 17:57, AZ-3164 at 18:00, Europe/Paris), status To Do.
