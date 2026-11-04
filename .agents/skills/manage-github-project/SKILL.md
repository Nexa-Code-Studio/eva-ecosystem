---
name: manage-github-project
description: Automate creation, management, linking, and status updates of GitHub Issues and Project v2 items natively using the host GitHub CLI.
---

# Manage GitHub Project & Issues Runbook

This skill automates all interactions with GitHub Issues and GitHub Project #2 (`https://github.com/orgs/Nexa-Code-Studio/projects/2`) using native `gh` commands without manual web UI interaction.

## When to Use

- When the user asks to create an issue, task, bug, or feature without manual UI steps.
- When linking `eva-ecosystem` to Project #2.
- When querying the current items and board columns on Project #2.
- When updating status or priority on the project board.

## Execution Procedures

### 1. Create Issue and Automatically Add to Project #2

```bash
python3 scripts/agentic/gh_project.py create-issue \
  --title "Implement Voice Activity Detection" \
  --type feat \
  --status Ready \
  --priority High \
  --assignee ekyaaa \
  --body "## Summary
Voice activity detection to reduce latency.

## Acceptance Criteria
- [ ] VAD threshold configurable
- [ ] Passing unit tests

## Definition of Done
- Code reviewed and tests passing"
```

### 2. Link Repository `eva-ecosystem` to Project #2

```bash
python3 scripts/agentic/gh_project.py link-repo \
  --owner Nexa-Code-Studio \
  --repo eva-ecosystem \
  --project 2
```

### 3. View Project #2 Items and Statuses

```bash
python3 scripts/agentic/gh_project.py view-project \
  --owner Nexa-Code-Studio \
  --project 2
```
