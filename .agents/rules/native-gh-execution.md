---
trigger: model_decision
description: Instructions for native GitHub CLI execution, Project #2 automation, and zero-manual-effort issue management on this workstation.
---

# Native GitHub CLI & Project #2 Automation Rules

This rule defines how Antigravity natively executes GitHub CLI (`gh`) operations and manages GitHub Project #2 (`Nexa-Code-Studio/projects/2`) directly without requiring manual user intervention in the web browser.

---

## 1. Workstation Binary & Environment Paths

On this machine:
- **`gh` Binary Path**: `/home/mashupsoat/.local/bin/gh`
- **User Config Directory**: `/home/mashupsoat/.config/gh`
- **Execution Mode**: `gh` commands interacting with remote GitHub APIs (issues, projects, auth) require network access. Run them with `BypassSandbox: true`.

---

## 2. Project & Repository Canonical Binding

Always use these targets unless explicitly overridden by the user:
- **Repository**: `Nexa-Code-Studio/eva-ecosystem`
- **Organization**: `Nexa-Code-Studio`
- **Project v2**: `https://github.com/orgs/Nexa-Code-Studio/projects/2` (Project `#2`)
- **Default Assignee**: `ekyaaa`

---

## 3. Issue & Project Management Policy (Mandatory Developer Review Gate)

When the user asks to create an issue, start a feature/bugfix, or add/edit/delete a task:
1. **Never ask the user to open the browser or create/edit the issue manually.**
2. Formulate a structured GitHub Issue title and body matching repository standards:
   - `## Summary`
   - `## Scope / Out of Scope`
   - `## Acceptance Criteria`
   - `## Definition of Done`
3. **MANDATORY REVIEW GATE**: Before executing actual creation, editing, closing, or deletion on GitHub:
   - Present the structured proposal / diff / impact to the developer.
   - Run `--dry-run` to preview the command payload:
     ```bash
     python3 scripts/agentic/gh_project.py create-issue \
       --title "<Title>" \
       --body "<Structured Body>" \
       --type <feat|fix|refactor|docs|test|chore> \
       --status <Backlog|Ready|In Progress> \
       --priority <Urgent|High|Medium|Low> \
       --assignee ekyaaa \
       --dry-run
     ```
   - **Ask the developer for explicit review and confirmation.**
4. **Execute Only After Explicit Developer Approval**:
   - Run the script without `--dry-run` once the developer approves.
5. If starting work immediately on that approved issue:
   - Create the task branch using `start-task.py`:
     ```bash
     python3 scripts/agentic/start-task.py --type <type> --issue <number> --slug <slug>
     ```
   - Update project status to `In Progress` using `sync-state.py`.

---

## 4. Canonical Vocabulary for Status & Priority

- **Status**: `Backlog` | `Ready` | `In Progress` | `In Review` | `Blocked` | `Done`
- **Priority**: `Urgent` | `High` | `Medium` | `Low`
