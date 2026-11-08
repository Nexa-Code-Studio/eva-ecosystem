#!/usr/bin/env python3
"""
GitHub CLI Native Project & Issue Manager.
Automates issue creation, Project v2 item linking, and status/priority updates
directly through native `gh` commands on this workstation.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    find_gh_binary,
    get_repo_root,
    load_identity,
    run_cmd,
    sanitize_text,
)

DEFAULT_ORG = "Nexa-Code-Studio"
DEFAULT_REPO = "eva-ecosystem"
DEFAULT_PROJECT_NUMBER = 2
DEFAULT_ASSIGNEE = "ekyaaa"

CANONICAL_STATUSES = ["Backlog", "Ready", "In Progress", "In Review", "Done", "Blocked"]
CANONICAL_PRIORITIES = ["Urgent", "High", "Medium", "Low"]

PROJECT_2_METADATA = {
    "projectId": "PVT_kwDODwEVH84BqIcs",
    "statusFieldId": "PVTSSF_lADODwEVH84BqIcszhog5RI",
    "statusOptions": {
        "Backlog": "96cc9c4f",
        "Ready": "f32e3135",
        "In Progress": "acefad91",
        "In Review": "b9d986bb",
        "Blocked": "41acbbf9",
        "Done": "d75ccbf6",
    },
    "priorityFieldId": "PVTSSF_lADODwEVH84BqIcszhoiuQE",
    "priorityOptions": {
        "Urgent": "b420fc90",
        "High": "b10292f6",
        "Medium": "bce35cee",
        "Low": "559dad1d",
    },
}

def set_project_item_single_select(project_id: str, item_id: str, field_id: str, option_id: str) -> bool:
    """Updates a single-select field on a Project v2 item via GraphQL."""
    mutation = f"""
    mutation {{
      updateProjectV2ItemFieldValue(input: {{
        projectId: "{project_id}",
        itemId: "{item_id}",
        fieldId: "{field_id}",
        value: {{ singleSelectOptionId: "{option_id}" }}
      }}) {{
        projectV2Item {{ id }}
      }}
    }}
    """
    res = exec_gh(["api", "graphql", "-f", f"query={mutation}"])
    return res.returncode == 0

def get_gh_env() -> Dict[str, str]:
    """Ensure gh uses user host config directory if present."""
    env = dict(os.environ)
    user_config = Path("/home/mashupsoat/.config/gh")
    if user_config.is_dir() and (user_config / "hosts.yml").is_file():
        env["GH_CONFIG_DIR"] = str(user_config)
    return env

def exec_gh(args: List[str], check: bool = False) -> subprocess.CompletedProcess:
    """Execute gh command with native binary and config environment."""
    gh_bin = find_gh_binary() or "gh"
    cmd = [gh_bin] + args
    return subprocess.run(
        cmd,
        cwd=str(get_repo_root()),
        capture_output=True,
        text=True,
        env=get_gh_env(),
        check=check,
    )

def create_issue(
    title: str,
    body: str,
    issue_type: str = "task",
    priority: str = "Medium",
    status: str = "Backlog",
    assignee: Optional[str] = DEFAULT_ASSIGNEE,
    repo: str = f"{DEFAULT_ORG}/{DEFAULT_REPO}",
    project_number: int = DEFAULT_PROJECT_NUMBER,
    project_owner: str = DEFAULT_ORG,
    dry_run: bool = False,
) -> Dict[str, Any]:
    """
    Creates an issue and automatically binds it to Project v2 with status and priority.
    """
    clean_title = sanitize_text(title, max_len=256)
    formatted_body = body.strip()

    labels = []
    if issue_type:
        labels.append(issue_type.lower())

    if dry_run:
        print("\n--- DRY-RUN: GitHub Issue & Project v2 Creation ---")
        print(f"Repository:     {repo}")
        print(f"Title:          {clean_title}")
        print(f"Type / Label:   {', '.join(labels) if labels else 'none'}")
        print(f"Assignee:       {assignee}")
        print(f"Target Project: #{project_number} (Owner: {project_owner})")
        print(f"Target Status:  {status}")
        print(f"Target Priority:{priority}")
        print(f"Body:\n{formatted_body}\n")
        print("---------------------------------------------------")
        return {"status": "dry_run", "title": clean_title}

    # 1. Create GitHub Issue
    cmd = ["issue", "create", "--repo", repo, "--title", clean_title, "--body", formatted_body]
    if assignee:
        cmd.extend(["--assignee", assignee])
    for lbl in labels:
        cmd.extend(["--label", lbl])

    print(f"🚀 Creating issue in {repo}...")
    res = exec_gh(cmd)
    if res.returncode != 0:
        raise RuntimeError(f"Failed to create issue: {res.stderr.strip() or res.stdout.strip()}")

    issue_url = res.stdout.strip()
    match = re.search(r"/issues/(\d+)", issue_url)
    issue_num = int(match.group(1)) if match else None

    print(f"✅ Issue #{issue_num} created: {issue_url}")

    # 2. Add to Project v2
    item_id = None
    if project_number:
        print(f"📋 Adding to Project #{project_number} ({project_owner})...")
        proj_cmd = [
            "project", "item-add", str(project_number),
            "--owner", project_owner,
            "--url", issue_url,
            "--format", "json"
        ]
        p_res = exec_gh(proj_cmd)
        if p_res.returncode == 0:
            try:
                data = json.loads(p_res.stdout)
                item_id = data.get("id")
                print(f"✅ Added to Project v2 as Item ID: {item_id}")
            except Exception:
                print(f"✅ Added to Project v2: {p_res.stdout.strip()}")
        else:
            print(f"⚠️ Warning: Could not add issue to Project #{project_number}: {p_res.stderr.strip()}")

    # 3. Update Status and Priority on Project v2 item
    if item_id and project_number == 2:
        meta = PROJECT_2_METADATA
        p_id = meta["projectId"]

        # Set Status
        status_opt_id = meta["statusOptions"].get(status)
        if status_opt_id:
            ok = set_project_item_single_select(p_id, item_id, meta["statusFieldId"], status_opt_id)
            if ok:
                print(f"✅ Set Project #{project_number} Status ➔ '{status}'")

        # Set Priority
        priority_opt_id = meta["priorityOptions"].get(priority)
        if priority_opt_id:
            ok = set_project_item_single_select(p_id, item_id, meta["priorityFieldId"], priority_opt_id)
            if ok:
                print(f"✅ Set Project #{project_number} Priority ➔ '{priority}'")

    return {
        "status": "success",
        "issue_number": issue_num,
        "issue_url": issue_url,
        "item_id": item_id,
        "project_number": project_number,
        "project_owner": project_owner,
        "target_status": status,
        "target_priority": priority,
    }

def link_repository_to_project(
    repo_name: str = DEFAULT_REPO,
    project_number: int = DEFAULT_PROJECT_NUMBER,
    owner: str = DEFAULT_ORG,
) -> bool:
    """Links repository to organization Project v2."""
    cmd = ["project", "link", str(project_number), "--owner", owner, "--repo", repo_name]
    print(f"🔗 Linking {owner}/{repo_name} to Project #{project_number}...")
    res = exec_gh(cmd)
    if res.returncode == 0:
        print(f"✅ Successfully linked {owner}/{repo_name} to Project #{project_number}!")
        return True
    else:
        print(f"❌ Failed to link repository: {res.stderr.strip() or res.stdout.strip()}", file=sys.stderr)
        return False

def view_project(project_number: int = DEFAULT_PROJECT_NUMBER, owner: str = DEFAULT_ORG) -> None:
    """Views Project v2 items."""
    cmd = ["project", "view", str(project_number), "--owner", owner]
    res = exec_gh(cmd)
    if res.returncode == 0:
        print(res.stdout)
    else:
        print(f"Error viewing project #{project_number}: {res.stderr.strip()}", file=sys.stderr)

def edit_issue(
    issue_number: int,
    title: Optional[str] = None,
    body: Optional[str] = None,
    add_labels: Optional[List[str]] = None,
    remove_labels: Optional[List[str]] = None,
    add_assignees: Optional[List[str]] = None,
    remove_assignees: Optional[List[str]] = None,
    repo: str = f"{DEFAULT_ORG}/{DEFAULT_REPO}",
    dry_run: bool = False,
) -> Dict[str, Any]:
    """Edits an existing GitHub issue."""
    if dry_run:
        print(f"\n--- DRY-RUN: GitHub Issue #{issue_number} Edit ---")
        print(f"Repository:       {repo}")
        print(f"Issue Number:     #{issue_number}")
        if title:
            print(f"New Title:        {title}")
        if body:
            print(f"New Body:\n{body}\n")
        if add_labels:
            print(f"Add Labels:       {', '.join(add_labels)}")
        if remove_labels:
            print(f"Remove Labels:    {', '.join(remove_labels)}")
        if add_assignees:
            print(f"Add Assignees:    {', '.join(add_assignees)}")
        if remove_assignees:
            print(f"Remove Assignees: {', '.join(remove_assignees)}")
        print("--------------------------------------------------")
        return {"status": "dry_run", "issue_number": issue_number}

    cmd = ["issue", "edit", str(issue_number), "--repo", repo]
    if title:
        cmd.extend(["--title", sanitize_text(title, max_len=256)])
    if body:
        cmd.extend(["--body", body.strip()])
    if add_labels:
        for lbl in add_labels:
            cmd.extend(["--add-label", lbl])
    if remove_labels:
        for lbl in remove_labels:
            cmd.extend(["--remove-label", lbl])
    if add_assignees:
        for a in add_assignees:
            cmd.extend(["--add-assignee", a])
    if remove_assignees:
        for a in remove_assignees:
            cmd.extend(["--remove-assignee", a])

    print(f"✏️ Editing issue #{issue_number} in {repo}...")
    res = exec_gh(cmd)
    if res.returncode != 0:
        raise RuntimeError(f"Failed to edit issue #{issue_number}: {res.stderr.strip() or res.stdout.strip()}")

    print(f"✅ Issue #{issue_number} edited successfully.")
    return {"status": "success", "issue_number": issue_number}

def close_issue(
    issue_number: int,
    comment: Optional[str] = None,
    reason: str = "completed",
    repo: str = f"{DEFAULT_ORG}/{DEFAULT_REPO}",
    dry_run: bool = False,
) -> Dict[str, Any]:
    """Closes an existing GitHub issue."""
    if dry_run:
        print(f"\n--- DRY-RUN: GitHub Issue #{issue_number} Close ---")
        print(f"Repository:   {repo}")
        print(f"Issue Number: #{issue_number}")
        print(f"Reason:       {reason}")
        if comment:
            print(f"Comment:      {comment}")
        print("---------------------------------------------------")
        return {"status": "dry_run", "issue_number": issue_number}

    cmd = ["issue", "close", str(issue_number), "--repo", repo, "--reason", reason]
    if comment:
        cmd.extend(["--comment", comment.strip()])

    print(f"🔒 Closing issue #{issue_number} in {repo}...")
    res = exec_gh(cmd)
    if res.returncode != 0:
        raise RuntimeError(f"Failed to close issue #{issue_number}: {res.stderr.strip() or res.stdout.strip()}")

    print(f"✅ Issue #{issue_number} closed successfully.")
    return {"status": "success", "issue_number": issue_number}

def delete_issue(
    issue_number: int,
    repo: str = f"{DEFAULT_ORG}/{DEFAULT_REPO}",
    dry_run: bool = False,
) -> Dict[str, Any]:
    """Deletes an existing GitHub issue."""
    if dry_run:
        print(f"\n--- DRY-RUN: GitHub Issue #{issue_number} Delete ---")
        print(f"Repository:   {repo}")
        print(f"Issue Number: #{issue_number}")
        print("---------------------------------------------------")
        return {"status": "dry_run", "issue_number": issue_number}

    cmd = ["issue", "delete", str(issue_number), "--repo", repo, "--yes"]
    print(f"🗑️ Deleting issue #{issue_number} in {repo}...")
    res = exec_gh(cmd)
    if res.returncode != 0:
        raise RuntimeError(f"Failed to delete issue #{issue_number}: {res.stderr.strip() or res.stdout.strip()}")

    print(f"✅ Issue #{issue_number} deleted successfully.")
    return {"status": "success", "issue_number": issue_number}

def main():
    parser = argparse.ArgumentParser(description="Native GitHub CLI Project & Issue Management Automation")
    subparsers = parser.add_subparsers(dest="command", help="Command to execute")

    # Command: create-issue
    p_create = subparsers.add_parser("create-issue", help="Create issue and bind to Project v2")
    p_create.add_argument("--title", type=str, required=True, help="Issue title")
    p_create.add_argument("--body", type=str, default="## Summary\nImplementation task.\n\n## Acceptance Criteria\n- [ ] Criteria 1\n", help="Issue body markdown")
    p_create.add_argument("--type", choices=["feat", "fix", "refactor", "docs", "test", "chore", "task"], default="task", help="Issue type / label")
    p_create.add_argument("--status", choices=CANONICAL_STATUSES, default="Ready", help="Initial Project v2 status")
    p_create.add_argument("--priority", choices=CANONICAL_PRIORITIES, default="Medium", help="Project v2 priority")
    p_create.add_argument("--assignee", type=str, default=DEFAULT_ASSIGNEE, help="Assignee GitHub login")
    p_create.add_argument("--project", type=int, default=DEFAULT_PROJECT_NUMBER, help="Project number")
    p_create.add_argument("--owner", type=str, default=DEFAULT_ORG, help="Project / Repo owner")
    p_create.add_argument("--repo", type=str, default=f"{DEFAULT_ORG}/{DEFAULT_REPO}", help="Target repo")
    p_create.add_argument("--dry-run", action="store_true", help="Preview without creating")

    # Command: link-repo
    p_link = subparsers.add_parser("link-repo", help="Link repository to Project v2")
    p_link.add_argument("--project", type=int, default=DEFAULT_PROJECT_NUMBER, help="Project number")
    p_link.add_argument("--owner", type=str, default=DEFAULT_ORG, help="Org owner")
    p_link.add_argument("--repo", type=str, default=DEFAULT_REPO, help="Repo name")

    # Command: view-project
    p_view = subparsers.add_parser("view-project", help="View Project v2 items")
    p_view.add_argument("--project", type=int, default=DEFAULT_PROJECT_NUMBER, help="Project number")
    p_view.add_argument("--owner", type=str, default=DEFAULT_ORG, help="Org owner")

    # Command: edit-issue
    p_edit = subparsers.add_parser("edit-issue", help="Edit existing issue")
    p_edit.add_argument("--issue", type=int, required=True, help="Issue number to edit")
    p_edit.add_argument("--title", type=str, help="New issue title")
    p_edit.add_argument("--body", type=str, help="New issue body")
    p_edit.add_argument("--add-label", action="append", help="Label to add (repeatable)")
    p_edit.add_argument("--remove-label", action="append", help="Label to remove (repeatable)")
    p_edit.add_argument("--add-assignee", action="append", help="Assignee to add (repeatable)")
    p_edit.add_argument("--remove-assignee", action="append", help="Assignee to remove (repeatable)")
    p_edit.add_argument("--repo", type=str, default=f"{DEFAULT_ORG}/{DEFAULT_REPO}", help="Target repo")
    p_edit.add_argument("--dry-run", action="store_true", help="Preview without editing")

    # Command: close-issue
    p_close = subparsers.add_parser("close-issue", help="Close existing issue")
    p_close.add_argument("--issue", type=int, required=True, help="Issue number to close")
    p_close.add_argument("--comment", type=str, help="Closing comment")
    p_close.add_argument("--reason", choices=["completed", "not planned"], default="completed", help="Close reason")
    p_close.add_argument("--repo", type=str, default=f"{DEFAULT_ORG}/{DEFAULT_REPO}", help="Target repo")
    p_close.add_argument("--dry-run", action="store_true", help="Preview without closing")

    # Command: delete-issue
    p_del = subparsers.add_parser("delete-issue", help="Delete existing issue")
    p_del.add_argument("--issue", type=int, required=True, help="Issue number to delete")
    p_del.add_argument("--repo", type=str, default=f"{DEFAULT_ORG}/{DEFAULT_REPO}", help="Target repo")
    p_del.add_argument("--dry-run", action="store_true", help="Preview without deleting")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    try:
        if args.command == "create-issue":
            create_issue(
                title=args.title,
                body=args.body,
                issue_type=args.type,
                priority=args.priority,
                status=args.status,
                assignee=args.assignee,
                repo=args.repo,
                project_number=args.project,
                project_owner=args.owner,
                dry_run=args.dry_run,
            )
        elif args.command == "edit-issue":
            edit_issue(
                issue_number=args.issue,
                title=args.title,
                body=args.body,
                add_labels=args.add_label,
                remove_labels=args.remove_label,
                add_assignees=args.add_assignee,
                remove_assignees=args.remove_assignee,
                repo=args.repo,
                dry_run=args.dry_run,
            )
        elif args.command == "close-issue":
            close_issue(
                issue_number=args.issue,
                comment=args.comment,
                reason=args.reason,
                repo=args.repo,
                dry_run=args.dry_run,
            )
        elif args.command == "delete-issue":
            delete_issue(
                issue_number=args.issue,
                repo=args.repo,
                dry_run=args.dry_run,
            )
        elif args.command == "link-repo":
            success = link_repository_to_project(
                repo_name=args.repo,
                project_number=args.project,
                owner=args.owner,
            )
            sys.exit(0 if success else 1)
        elif args.command == "view-project":
            view_project(project_number=args.project, owner=args.owner)
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
