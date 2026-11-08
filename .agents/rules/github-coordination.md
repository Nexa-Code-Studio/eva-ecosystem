---
trigger: model_decision
description: Architectural rules and coordination standards between local AI coding workflow, GitHub Projects v2, and the existing Discord Management Bot.
---

# GitHub & Discord Bot Coordination Rules

This document establishes the collaboration contract between local AI development sessions (Antigravity), GitHub Objects, and the team's Discord Project Management Bot (`ekyaaa/dc-bot-project-management`).

---

## 1. Single Canonical Source of Truth

- **GitHub is Primary**: All issues, task acceptance criteria, Project v2 statuses, pull requests, and CI results live strictly on GitHub.
- **Discord is Communication & Monitoring UI**: Discord serves as the human communication layer, query interface, and alert channel. Discord is **never** a shadow database for tasks.
- **Single Production Notification Sender**:
  - The existing Discord Bot (`dc-bot-project-management`) is the **sole production sender** of notifications to Discord, driven by GitHub App webhook events.
  - No secondary webhook scripts, Actions workflows, or direct Discord API callers should be enabled by default.

---

## 2. Identity & Account Linking

- **Local Workstation Identity**: Developers configure `.agent/developer.local.json` per machine (strictly gitignored). It contains only non-secret identifiers (`display_name`, `github_username`, `machine_label`).
- **Discord ↔ GitHub Linking**: Developers link their accounts once through the bot's slash command `/account connect` (using OAuth 2.0 PKCE).
- **No Shadow Mapping**: Do not hardcode Discord user IDs or maintain username-to-Discord mappings in repository source code or secrets.

---

## 3. Status Transition Rules

Follow the canonical status vocabulary and state machine matching the bot's `StatusTransitionPolicy`:

```text
Backlog  ───>  Ready  ───>  In Progress  ───>  In Review  ───>  Done (Terminal)
   │             │              │                 │
   └─────────────┴──────────────┴─────────────────┘
                         ▲
                         │ (bidirectional)
                         ▼
                      Blocked (Requires >= 3 chars reason)
```

- **Human-Owned Tasks**: Every task has a single human developer owner. AI agents code only on the task selected by the developer and must never auto-claim or auto-assign tasks.
- **Developer Review Gate for Issue Lifecycle**: Adding, editing, closing, or deleting GitHub issues requires prior review and explicit confirmation by the human developer. The AI agent must present the draft/dry-run and await approval before modifying GitHub state.
- **Evidence-Based Progress Updates**: Task transitions require concrete evidence:
  - `Ready ➔ In Progress`: Active task branch matching `{type}/{issue}-{slug}`.
  - `In Progress ➔ Blocked`: Explicit blocker reason (minimum 3 characters).
  - `Blocked ➔ In Progress`: Documented unblock note.
  - `In Progress ➔ In Review`: Open PR URL and passing test evidence.
  - `In Review ➔ Done`: PR merged into base branch or documented developer sign-off. Passing tests alone do not mark a task Done.
  - `Done`: Terminal state. Cannot transition out of Done.

---

## 4. Bot Webhook Router Notice

The Discord Bot currently routes:
- `issues`: `opened`, `assigned`, `reopened`, `closed`
- `pull_request`: `review_requested`, `ready_for_review`, `closed`
- `workflow_run` / `check_suite`: `completed` (failures/timed out)

Project v2 column transitions and issue progress comments update GitHub Project state and are queryable via bot commands (`/project status`, `/project issues`, `/issue view`), but do **not** dispatch automated push notifications to Discord channels.
