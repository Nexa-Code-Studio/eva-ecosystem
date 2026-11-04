---
name: task-startup
description: Review open tasks, verify doctor preflight, and initialize a task branch or isolated git worktree following repository naming conventions.
---

# Task Startup Runbook

This skill outlines how to inspect assigned tasks, select an issue, and create a cleanly isolated branch or Git worktree for development.

## Overview

All implementation in this repository is strictly **task-based**:
- Every task corresponds to a GitHub Issue.
- Branches follow the format: `{type}/{issue-number}-{short-kebab-case-slug}`.
- Allowed prefixes: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.
- Personal long-lived branches (e.g. `dev/{name}`) are prohibited.

## Step-by-Step Procedure

### 1. Review Current Tasks and Context

Inspect active local branches, worktrees, and issues assigned to your GitHub account:

```bash
python3 scripts/agentic/tasks.py
```

For JSON format:
```bash
python3 scripts/agentic/tasks.py --json
```

### 2. Verify Preflight Health

Ensure your workstation passes all operational gates before mutating git state:

```bash
python3 scripts/agentic/doctor.py
```

If fatal failures occur, resolve them (or run `python3 scripts/agentic/bootstrap.py`) before proceeding.

### 3. Dry-Run Branch Creation

Preview the branch creation parameters without modifying git refs:

```bash
python3 scripts/agentic/start-task.py \
  --type feat \
  --issue 128 \
  --slug user-authentication \
  --dry-run
```

### 4. Create Standard Task Branch

To create and checkout a new task branch from the default branch:

```bash
python3 scripts/agentic/start-task.py \
  --type feat \
  --issue 128 \
  --slug user-authentication
```

### 5. Create Isolated Git Worktree (Recommended for Parallel Tasks)

When working on multiple concurrent tasks without disturbing your primary working directory:

```bash
python3 scripts/agentic/start-task.py \
  --type fix \
  --issue 130 \
  --slug login-validation \
  --worktree
```

This creates an isolated worktree at `.agent/worktrees/130-login-validation`. To begin coding in that worktree:

```bash
cd .agent/worktrees/130-login-validation
```

Worktrees in `.agent/worktrees/` are automatically gitignored and inherit your machine's developer identity.

### 6. Verification

Verify that the active branch matches the convention:

```bash
git branch --show-current
# Expected output: feat/128-user-authentication
```
