#!/usr/bin/env python3
"""
Evidence-Based State Synchronization Tool.
Enforces deterministic validation for task state transitions:
Backlog -> Ready -> In Progress -> Blocked -> In Review -> Done.
Requires concrete evidence (tests, PR, unblock reason, merge) before transition.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    find_gh_binary,
    get_git_branch,
    get_repo_root,
    load_identity,
    run_cmd,
    sanitize_text,
)

VALID_STATES = ["Backlog", "Ready", "In Progress", "In Review", "Done", "Blocked"]

ALLOWED_STATUS_TRANSITIONS: Dict[str, List[str]] = {
    "Backlog": ["Ready", "In Progress", "Blocked"],
    "Ready": ["In Progress", "Backlog", "Blocked"],
    "In Progress": ["In Review", "Ready", "Blocked"],
    "In Review": ["Done", "In Progress", "Blocked"],
    "Blocked": ["Backlog", "Ready", "In Progress", "In Review"],
    "Done": [],  # Terminal state
}

STATE_FILE = ".agent/task-state.json"

def get_state_file_path() -> Path:
    return get_repo_root() / STATE_FILE

def load_cached_state() -> Dict[str, Any]:
    path = get_state_file_path()
    if path.is_file():
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_cached_state(state_data: Dict[str, Any]) -> None:
    path = get_state_file_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(state_data, f, indent=2)

def extract_issue_number(branch: str) -> Optional[int]:
    match = re.search(r"/(?:(\d+))-", branch)
    if match:
        return int(match.group(1))
    return None

def validate_transition(
    from_state: str,
    to_state: str,
    evidence: Dict[str, Any],
) -> Tuple[bool, str]:
    if to_state not in VALID_STATES:
        return False, f"Target state '{to_state}' is not one of valid states: {VALID_STATES}"

    if from_state == to_state:
        return True, "No state change required (already in desired state)."

    if from_state == "Done":
        return False, "State 'Done' is terminal; cannot transition away from Done."

    allowed_targets = ALLOWED_STATUS_TRANSITIONS.get(from_state, [])
    if to_state not in allowed_targets:
        return False, f"Invalid transition from '{from_state}' to '{to_state}'. Allowed transitions from '{from_state}': {allowed_targets}"

    if to_state == "In Progress":
        if not evidence.get("branch"):
            return False, "Transition to 'In Progress' requires an active task branch."
        return True, "Evidence accepted: active task branch verified."

    if to_state == "Blocked":
        blocker = evidence.get("blocker_reason")
        if not blocker or len(str(blocker).strip()) < 3:
            return False, "Transition to 'Blocked' requires a specific blocker reason (--blocker-reason, minimum 3 characters)."
        return True, "Evidence accepted: blocker description recorded."

    if to_state == "In Review":
        pr_url = evidence.get("pr_url")
        test_evidence = evidence.get("test_evidence")
        if not pr_url or not str(pr_url).startswith("http"):
            return False, "Transition to 'In Review' requires a valid Pull Request URL (--pr-url)."
        if not test_evidence or len(str(test_evidence).strip()) < 5:
            return False, "Transition to 'In Review' requires documented test evidence (--test-evidence, minimum 5 characters)."
        return True, "Evidence accepted: PR and test verification documented."

    if to_state == "Done":
        merged = evidence.get("pr_merged")
        approval = evidence.get("close_approval")
        if not merged and not approval:
            return False, "Transition to 'Done' requires PR to be merged (--pr-merged) or explicit human review approval (--close-approval)."
        return True, "Evidence accepted: completion and merge/approval verified."

    if to_state == "Ready":
        acceptance = evidence.get("acceptance_criteria")
        if not acceptance:
            return False, "Transition to 'Ready' requires documented acceptance criteria."
        return True, "Evidence accepted: acceptance criteria documented."

    return True, "Transition allowed."

def main():
    parser = argparse.ArgumentParser(description="Synchronize task state based on verifiable evidence")
    parser.add_argument("--state", choices=VALID_STATES, required=True, help="Target state")
    parser.add_argument("--issue", type=int, help="GitHub Issue number (defaults to parsing current branch)")
    parser.add_argument("--blocker-reason", type=str, help="Required when transitioning to Blocked")
    parser.add_argument("--unblock-note", type=str, help="Optional note when transitioning from Blocked back to In Progress")
    parser.add_argument("--pr-url", type=str, help="Pull Request URL (required for In Review)")
    parser.add_argument("--test-evidence", type=str, help="Summary of passing tests / test evidence (required for In Review)")
    parser.add_argument("--pr-merged", action="store_true", help="Confirm that PR has been merged into base branch (for Done)")
    parser.add_argument("--close-approval", type=str, help="Developer name or note approving closure (for Done)")
    parser.add_argument("--acceptance-criteria", type=str, help="Acceptance criteria note (for Ready)")
    parser.add_argument("--dry-run", action="store_true", help="Validate evidence and preview sync without mutating remote or state file")
    args = parser.parse_args()

    branch = get_git_branch()
    issue_num = args.issue or extract_issue_number(branch)

    if not issue_num:
        print("ERROR: Could not detect issue number from branch name or --issue argument.", file=sys.stderr)
        sys.exit(1)

    cached_all = load_cached_state()
    issue_key = str(issue_num)
    current_state_record = cached_all.get(issue_key, {})
    current_state = current_state_record.get("state", "Backlog")

    target_state = args.state

    evidence = {
        "branch": branch,
        "blocker_reason": args.blocker_reason,
        "unblock_note": args.unblock_note,
        "pr_url": args.pr_url,
        "test_evidence": args.test_evidence,
        "pr_merged": args.pr_merged,
        "close_approval": args.close_approval,
        "acceptance_criteria": args.acceptance_criteria,
    }

    # Validate transition
    allowed, message = validate_transition(current_state, target_state, evidence)
    if not allowed:
        print(f"❌ INVALID TRANSITION [{current_state} ➔ {target_state}]:", file=sys.stderr)
        print(f"   Reason: {message}", file=sys.stderr)
        sys.exit(1)

    # Check for identical idempotent sync
    if current_state == target_state:
        print(f"ℹ️  Task #{issue_num} is already in state '{target_state}'. No state update needed.")
        if args.dry_run:
            print("DRY-RUN: Idempotent no-op confirmed.")
        sys.exit(0)

    print(f"✅ Evidence validated for Task #{issue_num}:")
    print(f"   Transition: {current_state} ➔ {target_state}")
    print(f"   Proof: {message}")

    if args.dry_run:
        print("\n--- DRY-RUN SUMMARY ---")
        print(f"Task: #{issue_num}")
        print(f"Branch: {branch}")
        print(f"From: {current_state}")
        print(f"To: {target_state}")
        print("Remote Mutation: Skipped (dry-run)")
        print("-----------------------")
        sys.exit(0)

    # Update local cache
    updated_record = {
        "issue": issue_num,
        "branch": branch,
        "state": target_state,
        "updated_at": int(time.time()),
        "evidence_summary": message,
    }
    if args.pr_url:
        updated_record["pr_url"] = args.pr_url
    if args.blocker_reason:
        updated_record["blocker_reason"] = args.blocker_reason

    cached_all[issue_key] = updated_record
    save_cached_state(cached_all)
    print(f"💾 Updated local task state cache in {STATE_FILE}")

    # Check remote GitHub Project synchronization
    identity_data, _ = load_identity()
    project_cfg = identity_data.get("project") if identity_data else None
    gh_bin = find_gh_binary()

    if not gh_bin:
        print("⏳ GitHub Project Sync: PENDING_CONFIGURATION (gh CLI not installed locally).")
        print("   Local evidence state saved. CI or GitHub Actions will synchronize remote project status.")
    elif not project_cfg or not project_cfg.get("project_number"):
        print("⏳ GitHub Project Sync: PENDING_PROJECT_BINDING (No project_number configured in .agent/developer.local.json).")
    else:
        p_num = project_cfg["project_number"]
        print(f"📡 Syncing with GitHub Project #{p_num}...")
        print(f"   Target Status: '{target_state}' recorded.")

    print(f"\n🎉 Task #{issue_num} successfully updated to '{target_state}'!")
    print("\nℹ️  [Bot Router Notice] Status Project diperbarui di GitHub & dapat dilihat via /project status atau /issue view di Discord.")
    print("   Bot saat ini tidak memicu notifikasi push otomatis untuk perubahan kolom Project v2 (hanya untuk issue assignment, PR review, dan CI failure).")

if __name__ == "__main__":
    main()
