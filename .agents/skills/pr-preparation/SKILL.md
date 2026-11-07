---
name: pr-preparation
description: Validate branch naming, clean working directory, execute local tests, and generate a standardized Pull Request description matching repository templates.
---

# Pull Request Preparation Runbook

This skill outlines how to audit local changes, run tests, and format a compliant Pull Request prior to code review.

## Overview

Opening a Pull Request requires:
- A branch adhering to `{type}/{issue}-{slug}`.
- A clean working directory with no stray untracked files or leftover secrets.
- Verifiable test execution evidence.
- A standardized PR description following `.github/PULL_REQUEST_TEMPLATE.md`.

## Step-by-Step Procedure

### 1. Verify Git Status & Clean Tree

Ensure there are no uncommitted changes or accidental credential files:

```bash
git status --short
```

Commit any pending work before proceeding:

```bash
git commit -m "feat(auth): complete user login validation"
```

### 2. Prepare PR with Test Verification

Execute `prepare-pr.py`, optionally providing a test command to execute and record evidence:

```bash
python3 scripts/agentic/prepare-pr.py --test-cmd "python3 -m unittest discover -s tests/agentic"
```

The script will:
1. Verify branch convention compliance.
2. Confirm working tree cleanliness.
3. Run the specified test suite.
4. Collect commit messages and diff statistics.
5. Format the PR title and Markdown description.

### 3. Dry-Run Preview

To inspect the generated PR markdown without running external commands:

```bash
python3 scripts/agentic/prepare-pr.py --dry-run
```

### 4. Submitting the Pull Request

If GitHub CLI (`gh`) is installed:

```bash
gh pr create \
  --title "feat: resolve #128 (user authentication)" \
  --base main \
  --body-file pr-draft.md
```

If `gh` is unavailable:
Copy the formatted PR description output directly into the GitHub web interface when opening the Pull Request.

### 5. Post-PR State Synchronization

Once the Pull Request URL is generated, synchronize the task state:

```bash
python3 scripts/agentic/sync-state.py \
  --state "In Review" \
  --pr-url "https://github.com/Nexa-Code-Studio/eva-ecosystem/pull/42" \
  --test-evidence "All 18 unit tests passed via python3 -m unittest"
```
