---
name: project-state-sync
description: Synchronize task and GitHub Project status based on concrete, verifiable evidence (passing tests, PR links, unblock notes).
---

# Project State Synchronization Runbook

This skill defines the evidence requirements and operational procedures for transitioning task lifecycle states.

## Overview

State transitions are **evidence-based and deterministic**:
- Mutasi lifecycle issue (tambah, edit, tutup, atau hapus) wajib melalui review dan persetujuan eksplisit developer.
- The agent must **never** infer task completion merely because code was edited.
- A passing unit test alone does **not** mark a task `Done`.
- An agent crash or process termination never triggers automated state transitions.
- All state changes are recorded idempotently in `.agent/task-state.json` and mirrored to GitHub Projects v2 when credentials allow.

## State Transition & Evidence Matrix

| State Transition | Required Verifiable Evidence | CLI Parameters |
| :--- | :--- | :--- |
| `Backlog` ➔ `Ready` | Acceptance criteria approved by human owner | `--state Ready --acceptance-criteria "<criteria>"` |
| `Ready` ➔ `In Progress` | Developer starts work; task branch checked out | `--state "In Progress"` |
| `In Progress` ➔ `Blocked` | Concrete blocker identified, explained, and referenced | `--state Blocked --blocker-reason "<reason>"` |
| `Blocked` ➔ `In Progress` | Blocker resolution verified | `--state "In Progress" --unblock-note "<resolution>"` |
| `In Progress` ➔ `In Review` | PR created + unit/integration tests verified passing | `--state "In Review" --pr-url "<url>" --test-evidence "<evidence>"` |
| `In Review` ➔ `Done` | PR merged into base branch OR human acceptance sign-off | `--state Done --pr-merged` or `--close-approval "<name>"` |

## Step-by-Step Procedure

### 1. Starting Work (`In Progress`)

When you begin working on a checked-out task branch:

```bash
python3 scripts/agentic/sync-state.py --state "In Progress"
```

The script automatically infers the issue number from the active branch name (e.g. `feat/128-user-auth` ➔ `#128`).

### 2. Flagging a Blocker (`Blocked`)

If external dependencies, missing credentials, or API issues prevent progress:

```bash
python3 scripts/agentic/sync-state.py \
  --state Blocked \
  --blocker-reason "Awaiting database migration approval from backend lead"
```

### 3. Transitioning to Review (`In Review`)

After writing code, running tests, and opening a Pull Request:

```bash
python3 scripts/agentic/sync-state.py \
  --state "In Review" \
  --pr-url "https://github.com/Nexa-Code-Studio/eva-ecosystem/pull/42" \
  --test-evidence "12 unit tests passing: python3 -m unittest discover -s tests"
```

If `--pr-url` or `--test-evidence` is missing, the validator will reject the transition.

### 4. Transitioning to Done (`Done`)

Only after the Pull Request has been merged into the default branch:

```bash
python3 scripts/agentic/sync-state.py \
  --state Done \
  --pr-merged
```

Or with explicit developer sign-off:

```bash
python3 scripts/agentic/sync-state.py \
  --state Done \
  --close-approval "Verified and approved by Lead Dev"
```

### 5. Dry-Run and Idempotency

To validate evidence without changing local state or sending API calls:

```bash
python3 scripts/agentic/sync-state.py --state "In Progress" --dry-run
```

Re-running the command with identical state produces an idempotent no-op without spamming comments or duplicate updates.
