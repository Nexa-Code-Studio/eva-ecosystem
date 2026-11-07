---
name: sync-project-state
description: Synchronize task status and GitHub Project v2 based on verifiable evidence (branches, tests, PRs, unblock notes).
---

# Sync Project State Runbook

This skill validates concrete evidence before updating a task's state in `.agent/task-state.json` and the bound GitHub Project v2.

## Status Machine

```text
Backlog ➔ Ready ➔ In Progress ➔ In Review ➔ Done (Terminal)
(Blocked is bidirectional with Backlog, Ready, In Progress, In Review)
```

## Execution

### 1. Move to In Progress
```bash
python3 scripts/agentic/sync-state.py \
  --state "In Progress" \
  --issue 128
```

### 2. Mark Blocked (Requires Reason >= 3 chars)
```bash
python3 scripts/agentic/sync-state.py \
  --state "Blocked" \
  --issue 128 \
  --blocker-reason "Waiting for API endpoint v2"
```

### 3. Move to In Review (Requires PR & Test Evidence)
```bash
python3 scripts/agentic/sync-state.py \
  --state "In Review" \
  --issue 128 \
  --pr-url "https://github.com/Nexa-Code-Studio/eva-ecosystem/pull/15" \
  --test-evidence "All 40 unit tests passing"
```

### 4. Move to Done (Requires Merged PR or Approval)
```bash
python3 scripts/agentic/sync-state.py \
  --state "Done" \
  --issue 128 \
  --pr-merged
```
