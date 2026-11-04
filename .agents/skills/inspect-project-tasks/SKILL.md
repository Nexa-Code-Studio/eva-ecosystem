---
name: inspect-project-tasks
description: Inspect assigned developer tasks, recommendations, blockers, and Pull Request review requests with graceful offline degradation.
---

# Inspect Project Tasks Runbook

This skill allows the developer or AI coding agent to inspect open tasks, active task branches, worktrees, and issues assigned to the active developer account.

## When to Use

- At the beginning of a working session to reconcile local and remote context.
- Before choosing a new issue to work on.
- When checking if you have outstanding PR review requests from team members.
- When operating offline or without GitHub CLI to view local active branches and worktrees.

## Execution

### 1. View Formatted Task Summary
```bash
python3 scripts/agentic/tasks.py
```

### 2. View Machine-Readable JSON Output
```bash
python3 scripts/agentic/tasks.py --json
```

## Behavior

- **Offline / No GitHub CLI**: Displays active local Git branches matching `{type}/{issue}-{slug}`, existing worktrees under `.agent/worktrees/`, and cached task states from `.agent/task-state.json`.
- **Online with Authenticated `gh`**: Queries GitHub API for open issues assigned to the developer's registered username and active review requests.
