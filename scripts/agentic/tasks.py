#!/usr/bin/env python3
"""
Task Context & Summary Tool.
Read-only inspection of developer tasks, active branches, and issue status.
Degrades gracefully when gh CLI is unavailable or offline.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    find_gh_binary,
    get_git_branch,
    get_repo_root,
    load_identity,
    run_cmd,
    sanitize_text,
)

def get_local_worktrees() -> List[Dict[str, str]]:
    worktrees = []
    res = run_cmd(["git", "worktree", "list", "--porcelain"])
    if res.returncode == 0:
        current_wt: Dict[str, str] = {}
        for line in res.stdout.splitlines():
            line = line.strip()
            if line.startswith("worktree "):
                current_wt["path"] = line.split(" ", 1)[1]
            elif line.startswith("branch "):
                current_wt["branch"] = line.split(" ", 1)[1].replace("refs/heads/", "")
            elif line.startswith("HEAD "):
                current_wt["head"] = line.split(" ", 1)[1]
            elif line == "":
                if current_wt:
                    worktrees.append(current_wt)
                    current_wt = {}
        if current_wt:
            worktrees.append(current_wt)
    return worktrees

def get_local_task_branches() -> List[str]:
    res = run_cmd(["git", "branch", "--list", "feat/*", "fix/*", "refactor/*", "docs/*", "test/*", "chore/*"])
    if res.returncode == 0:
        branches = []
        for line in res.stdout.splitlines():
            clean = line.replace("*", "").strip()
            if clean:
                branches.append(clean)
        return branches
    return []

def load_cached_task_states() -> Dict[str, Any]:
    state_file = get_repo_root() / ".agent" / "task-state.json"
    if state_file.is_file():
        try:
            with open(state_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def fetch_review_requests() -> List[Dict[str, Any]]:
    gh_bin = find_gh_binary()
    if not gh_bin:
        return []
    cmd = [
        gh_bin, "pr", "list",
        "--search", "review-requested:@me",
        "--state", "open",
        "--json", "number,title,url,author"
    ]
    res = run_cmd(cmd)
    if res.returncode == 0:
        try:
            return json.loads(res.stdout)
        except Exception:
            return []
    return []

def fetch_github_issues(username: str) -> Tuple[List[Dict[str, Any]], Optional[str]]:
    gh_bin = find_gh_binary()
    if not gh_bin:
        return [], "GitHub CLI ('gh') not installed. Showing local repository tasks only."

    cmd = [
        gh_bin, "issue", "list",
        "--assignee", username,
        "--state", "open",
        "--json", "number,title,state,labels,updatedAt,url"
    ]
    res = run_cmd(cmd)
    if res.returncode != 0:
        return [], f"gh CLI query error: {res.stderr.strip() or 'Offline or unauthenticated'}"

    try:
        issues = json.loads(res.stdout)
        return issues, None
    except Exception as e:
        return [], f"Failed to parse gh output: {e}"

def main():
    parser = argparse.ArgumentParser(description="Read-only Task Summary")
    parser.add_argument("--json", action="store_true", help="Output summary in JSON format")
    args = parser.parse_args()

    identity_data, _ = load_identity()
    github_user = identity_data.get("developer", {}).get("github_username") if identity_data else None

    current_branch = get_git_branch()
    local_branches = get_local_task_branches()
    worktrees = get_local_worktrees()

    cached_states = load_cached_task_states()
    review_requests = fetch_review_requests() if github_user else []

    gh_issues = []
    gh_warning = None
    if github_user:
        gh_issues, gh_warning = fetch_github_issues(github_user)
    else:
        gh_warning = "Local identity not configured or missing github_username. Run `python3 scripts/agentic/bootstrap.py`."

    summary = {
        "developer": identity_data.get("developer") if identity_data else None,
        "current_branch": current_branch,
        "local_task_branches": local_branches,
        "worktrees": worktrees,
        "cached_task_states": cached_states,
        "github_issues": gh_issues,
        "review_requests": review_requests,
        "github_status": "ONLINE" if (github_user and not gh_warning) else "OFFLINE_OR_PENDING",
        "warning": gh_warning,
    }

    if args.json:
        print(json.dumps(summary, indent=2))
        return

    print("\n=== Agentic Task Summary ===")
    if identity_data:
        dev = identity_data.get("developer", {})
        ws = identity_data.get("workspace", {})
        print(f"Developer: {dev.get('display_name')} (@{dev.get('github_username')}) | Machine: {ws.get('machine_label')}")
    else:
        print("Developer: [UNREGISTERED - run bootstrap.py]")

    print(f"Current Branch: {current_branch}")

    print("\n--- Active Local Task Branches ---")
    if local_branches:
        for b in local_branches:
            marker = " (active)" if b == current_branch else ""
            print(f"  • {b}{marker}")
    else:
        print("  (No task branches found matching {type}/{issue}-{slug})")

    print("\n--- Git Worktrees ---")
    if worktrees:
        for wt in worktrees:
            print(f"  • [{wt.get('branch', 'unknown')}] at {wt.get('path')}")
    else:
        print("  (Single worktree in use)")

    # Display Blocked Tasks if any
    blocked_tasks = {k: v for k, v in cached_states.items() if v.get("state") == "Blocked"}
    if blocked_tasks:
        print("\n--- ⚠️  Blocked Tasks & Kendala Aktif ---")
        for k, v in blocked_tasks.items():
            reason = v.get("blocker_reason", "No reason provided")
            print(f"  • Task #{k} ({v.get('branch')}): {reason}")

    # Display Review Requests if any
    if review_requests:
        print("\n--- 🔍 Pull Request Review Requests ---")
        for pr in review_requests:
            print(f"  • PR #{pr.get('number')}: {sanitize_text(pr.get('title'))} (by @{pr.get('author', {}).get('login', 'unknown')})")
            print(f"    URL: {pr.get('url')}")

    print("\n--- GitHub Issues Assigned to You ---")
    if gh_issues:
        for iss in gh_issues:
            labels = [lbl.get("name") for lbl in iss.get("labels", []) if isinstance(lbl, dict)]
            lbl_str = f" [{', '.join(labels)}]" if labels else ""
            print(f"  #{iss['number']}: {sanitize_text(iss['title'])}{lbl_str}")
            print(f"    URL: {iss.get('url')}")
    elif gh_warning:
        print(f"  ⏳ {gh_warning}")
    else:
        print("  (No open issues assigned to you)")

    print("==================================\n")

if __name__ == "__main__":
    main()
