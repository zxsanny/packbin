---
title: "Call Jira through the connector that reaches denyspopov.atlassian.net and pass its cloud id; atlassian-bellator is another site"
applies_when: "calling Jira (project AZ)"
source: "loop 114"
---

Jira for this project (project AZ, `denyspopov.atlassian.net`, `_docs/02_document/epics.md`) is the Atlassian connector whose `getAccessibleAtlassianResources` returns that site (cloud id `1598226f-845f-4705-bcd1-5ed0c82d6119`); the `atlassian-bellator` connector reaches `bellator80.atlassian.net`, another site (loop 114). Call the matching connector and pass that cloud id.

The tracker fields (host, cloud id, project, MCP server) are in `_docs/00_problem/tracker.md`.
