---
name: developer-onboarding
description: Onboard a new developer or workstation machine into the project, configure gitignored developer identity, and run preflight diagnostics using doctor.py.
---

# Developer Onboarding Runbook

This skill guides you through setting up or validating developer identity on a new machine or worktree environment.

## Overview

The Supervised Autonomous Development Coordination model requires each developer workstation to have a local identity file at `.agent/developer.local.json`. This configuration is **strictly gitignored** and stores non-sensitive operational metadata (display name, GitHub username, machine label, and optional GitHub Project binding).

## When to Use

- When starting work on a new workstation or newly cloned workspace.
- When `doctor.py` or preflight hooks report missing developer identity (`FAIL: identity_file`).
- When switching between worktrees or developer profiles.
- When verifying that local environment satisfies all operational prerequisites.

## Step-by-Step Procedure

### 1. Run Preflight Doctor Check

First check if an identity is already present and valid:

```bash
python3 scripts/agentic/doctor.py
```

- If all items report `[PASS]` or `[PENDING_CONFIGURATION]`, onboarding is already complete!
- If `identity_file` reports `[FAIL]`, proceed to Step 2.

### 2. Run Interactive Onboarding

On an interactive terminal:

```bash
python3 scripts/agentic/bootstrap.py
```

The script will prompt for:
1. **Full Display Name**: Your human name (defaults to `git config user.name`).
2. **GitHub Username**: Your GitHub handle (must match your `gh` CLI account).
3. **Machine Label**: A friendly identifier for this device (e.g. `laptop-fedora`, `devbox-01`).

### 3. Non-Interactive / Scripted Onboarding

If running in CI, container, or automated script:

```bash
python3 scripts/agentic/bootstrap.py \
  --display-name "Alex Morgan" \
  --github-username "alexmorgan" \
  --machine-label "dev-laptop" \
  --non-interactive
```

To bind a GitHub Project v2 during bootstrap:

```bash
python3 scripts/agentic/bootstrap.py \
  --display-name "Alex Morgan" \
  --github-username "alexmorgan" \
  --machine-label "dev-laptop" \
  --project-number 1 \
  --project-title "Eva AI Board" \
  --non-interactive
```

### 4. Verify Identity and Security

Ensure the generated identity is valid and properly gitignored:

```bash
# Verify schema and presence
python3 scripts/agentic/bootstrap.py --check-only

# Verify git ignores the file
git check-ignore -v .agent/developer.local.json
```

Output should confirm `.agent/developer.local.json` is matched by `.gitignore`.

### 5. Multi-Worktree Behavior

When creating Git worktrees on the same machine, the agentic tooling automatically looks up the parent clone's `.agent/developer.local.json`. You do not need to duplicate identity files across worktrees on the same workstation.
