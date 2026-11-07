#!/usr/bin/env python3
"""
Doctor / Preflight Diagnostic Tool for Agentic Workflow.
Performs deterministic environment and configuration checks.
Exits 0 on success (or pending non-blocking items), 1 on fatal blockers.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List

# Ensure scripts/agentic is in sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    Status,
    find_gh_binary,
    get_identity_path,
    get_repo_root,
    is_git_ignored,
    load_identity,
    run_cmd,
    validate_identity,
)

class DiagnosticResult:
    def __init__(self, name: str, status: str, message: str, remediation: str = "", category: str = "local"):
        self.name = name
        self.status = status
        self.message = message
        self.remediation = remediation
        self.category = category

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "status": self.status,
            "category": self.category,
            "message": self.message,
            "remediation": self.remediation,
        }

def run_diagnostics(strict: bool = False) -> List[DiagnosticResult]:
    results: List[DiagnosticResult] = []
    repo_root = get_repo_root()
    id_path = get_identity_path()

    # 1. Identity File Existence
    if not id_path.is_file():
        results.append(
            DiagnosticResult(
                name="identity_file",
                status=Status.FAIL,
                message=f"Missing developer identity file at {id_path}",
                remediation="Run `python3 scripts/agentic/bootstrap.py` to initialize your local identity.",
            )
        )
        identity_data = None
    else:
        identity_data, err = load_identity()
        if err:
            results.append(
                DiagnosticResult(
                    name="identity_file",
                    status=Status.FAIL,
                    message=err,
                    remediation="Fix invalid JSON syntax in .agent/developer.local.json or re-run bootstrap.",
                )
            )
        else:
            results.append(
                DiagnosticResult(
                    name="identity_file",
                    status=Status.PASS,
                    message=f"Found developer identity at {id_path.name}",
                )
            )

    # 2. Identity Schema Validation
    if identity_data is not None:
        valid, errors = validate_identity(identity_data)
        if valid:
            results.append(
                DiagnosticResult(
                    name="identity_schema",
                    status=Status.PASS,
                    message="Developer identity conforms to schema v1",
                )
            )
        else:
            results.append(
                DiagnosticResult(
                    name="identity_schema",
                    status=Status.FAIL,
                    message="; ".join(errors),
                    remediation="Update .agent/developer.local.json to match .agent/developer.schema.json",
                )
            )

    # 3. Gitignore Check
    if id_path.is_file():
        if is_git_ignored(id_path):
            results.append(
                DiagnosticResult(
                    name="identity_gitignored",
                    status=Status.PASS,
                    message=".agent/developer.local.json is properly gitignored",
                )
            )
        else:
            results.append(
                DiagnosticResult(
                    name="identity_gitignored",
                    status=Status.FAIL,
                    message=".agent/developer.local.json is NOT ignored by git! Risk of credential/personal data leak.",
                    remediation="Add '.agent/developer.local.json' to .gitignore immediately.",
                )
            )

    # 4. Git Repository & Working Tree Health
    git_check = run_cmd(["git", "rev-parse", "--is-inside-work-tree"])
    if git_check.returncode != 0:
        results.append(
            DiagnosticResult(
                name="git_repository",
                status=Status.FAIL,
                message="Current directory is not inside a Git work tree",
                remediation="Ensure you are working inside the repository clone.",
            )
        )
    else:
        # Check detached head
        branch_res = run_cmd(["git", "symbolic-ref", "--short", "-q", "HEAD"])
        if branch_res.returncode != 0:
            results.append(
                DiagnosticResult(
                    name="git_repository",
                    status=Status.WARN,
                    message="Git is in DETACHED HEAD state. Mutations may be lost.",
                    remediation="Checkout an explicit branch before mutating code: `git checkout <branch>`.",
                )
            )
        else:
            results.append(
                DiagnosticResult(
                    name="git_repository",
                    status=Status.PASS,
                    message=f"Git repository healthy on branch '{branch_res.stdout.strip()}'",
                )
            )

    # 5. Remote Origin
    remote_res = run_cmd(["git", "remote", "get-url", "origin"])
    if remote_res.returncode != 0:
        results.append(
            DiagnosticResult(
                name="git_remote",
                status=Status.WARN,
                message="Git remote 'origin' is not configured",
                remediation="Add remote origin: `git remote add origin git@github.com:<org>/<repo>.git`",
            )
        )
    else:
        origin_url = remote_res.stdout.strip()
        results.append(
            DiagnosticResult(
                name="git_remote",
                status=Status.PASS,
                message=f"Origin remote configured: {origin_url}",
            )
        )

    # 6. GitHub CLI & Auth Status
    gh_bin = find_gh_binary()
    if not gh_bin:
        pkg_cmd = "sudo dnf install gh" if shutil.which("dnf") else ("sudo apt install gh" if shutil.which("apt") else "brew install gh or pacman -S github-cli")
        results.append(
            DiagnosticResult(
                name="gh_cli",
                status=Status.PENDING_CONFIGURATION,
                category="remote",
                message="GitHub CLI ('gh') is not installed in the current environment.",
                remediation=f"Install GitHub CLI (`{pkg_cmd}`) and run `gh auth login` for GitHub API sync.",
            )
        )
    else:
        auth_res = run_cmd([gh_bin, "auth", "status"])
        if auth_res.returncode != 0:
            results.append(
                DiagnosticResult(
                    name="gh_cli",
                    status=Status.WARN,
                    category="remote",
                    message="GitHub CLI is installed but not authenticated or session expired.",
                    remediation=f"Authenticate using `{gh_bin} auth login -s project,read:org,repo`.",
                )
            )
        else:
            # Check user login match with identity
            user_res = run_cmd([gh_bin, "api", "user", "--jq", ".login"])
            gh_user = user_res.stdout.strip() if user_res.returncode == 0 else ""
            if identity_data and identity_data.get("developer", {}).get("github_username"):
                expected_user = identity_data["developer"]["github_username"]
                if gh_user.lower() != expected_user.lower():
                    results.append(
                        DiagnosticResult(
                            name="gh_cli",
                            status=Status.FAIL,
                            category="remote",
                            message=f"Authenticated GitHub user '{gh_user}' does not match developer.local.json '{expected_user}'.",
                            remediation="Run `gh auth login` with the correct account or update identity.",
                        )
                    )
                else:
                    results.append(
                        DiagnosticResult(
                            name="gh_cli",
                            status=Status.PASS,
                            category="remote",
                            message=f"GitHub CLI authenticated as '{gh_user}' (matches local identity)",
                        )
                    )
            else:
                results.append(
                    DiagnosticResult(
                        name="gh_cli",
                        status=Status.PASS,
                        category="remote",
                        message=f"GitHub CLI authenticated as '{gh_user}'",
                    )
                )

    # 7. GitHub Project Binding
    project_bound = False
    if identity_data and identity_data.get("project", {}).get("project_number"):
        p_num = identity_data["project"]["project_number"]
        p_title = identity_data["project"].get("project_title", "GitHub Project")
        p_owner = identity_data["project"].get("project_owner")
        owner_info = f" under '{p_owner}'" if p_owner else ""
        results.append(
            DiagnosticResult(
                name="project_binding",
                status=Status.PASS,
                category="remote",
                message=f"Bound to GitHub Project #{p_num} ({p_title}){owner_info}",
            )
        )
        project_bound = True
    else:
        results.append(
            DiagnosticResult(
                name="project_binding",
                status=Status.PENDING_CONFIGURATION,
                category="remote",
                message="No GitHub Project v2 currently bound in local identity.",
                remediation="Configure 'project.project_number' in .agent/developer.local.json when project is created.",
            )
        )

    # 8. Rules & Skills Discovery
    rules_dir = repo_root / ".agents" / "rules"
    skills_dir = repo_root / ".agents" / "skills"
    if rules_dir.is_dir() and skills_dir.is_dir():
        num_rules = len(list(rules_dir.glob("*.md")))
        num_skills = len([s for s in skills_dir.iterdir() if (s / "SKILL.md").is_file()])
        results.append(
            DiagnosticResult(
                name="rules_and_skills",
                status=Status.PASS,
                message=f"Found {num_rules} architectural rules and {num_skills} active skills in .agents/",
            )
        )
    else:
        results.append(
            DiagnosticResult(
                name="rules_and_skills",
                status=Status.WARN,
                message="Rules or skills directory missing in .agents/",
                remediation="Ensure .agents/rules and .agents/skills directories exist.",
            )
        )

    # 9. Hooks Configuration
    hooks_file = repo_root / ".agents" / "hooks.json"
    if hooks_file.is_file():
        try:
            with open(hooks_file, "r", encoding="utf-8") as f:
                json.load(f)
            results.append(
                DiagnosticResult(
                    name="hooks_configuration",
                    status=Status.PASS,
                    message="Lifecycle hooks configured in .agents/hooks.json",
                )
            )
        except Exception as e:
            results.append(
                DiagnosticResult(
                    name="hooks_configuration",
                    status=Status.FAIL,
                    message=f"Invalid JSON in .agents/hooks.json: {e}",
                    remediation="Fix syntax error in .agents/hooks.json",
                )
            )
    else:
        results.append(
            DiagnosticResult(
                name="hooks_configuration",
                status=Status.PENDING_CONFIGURATION,
                message=".agents/hooks.json not found.",
                remediation="Initialize .agents/hooks.json for lifecycle hooks.",
            )
        )

    return results

def main():
    parser = argparse.ArgumentParser(description="Doctor / Preflight Diagnostic Tool")
    parser.add_argument("--json", action="store_true", help="Output diagnostics in JSON format")
    parser.add_argument("--strict", action="store_true", help="Treat WARN and PENDING as failure")
    parser.add_argument("--quiet", action="store_true", help="Only output errors")
    args = parser.parse_args()

    results = run_diagnostics(strict=args.strict)
    has_failures = any(r.status == Status.FAIL for r in results)
    has_warnings = any(r.status in (Status.WARN, Status.PENDING_CONFIGURATION) for r in results)

    local_results = [r for r in results if r.category == "local"]
    remote_results = [r for r in results if r.category == "remote"]

    local_failures = any(r.status == Status.FAIL for r in local_results)
    remote_failures = any(r.status == Status.FAIL for r in remote_results)
    remote_pending = any(r.status in (Status.WARN, Status.PENDING_CONFIGURATION) for r in remote_results)

    local_status = "LOCAL_BLOCKED" if local_failures else "LOCAL_READY"
    remote_status = "REMOTE_READY" if (not remote_failures and not remote_pending) else ("REMOTE_BLOCKED" if remote_failures else "PENDING_CONFIGURATION")

    if args.json:
        output = {
            "overall_status": Status.FAIL if has_failures else (Status.WARN if has_warnings else Status.PASS),
            "local_status": local_status,
            "remote_status": remote_status,
            "diagnostics": [r.to_dict() for r in results],
        }
        print(json.dumps(output, indent=2))
    else:
        icons = {
            Status.PASS: "✅ [PASS]",
            Status.WARN: "⚠️  [WARN]",
            Status.FAIL: "❌ [FAIL]",
            Status.PENDING_CONFIGURATION: "⏳ [PENDING_CONFIGURATION]",
        }
        print("\n=== Agentic Workflow Doctor & Preflight Diagnostic ===")
        loc_badge = "✅" if local_status == "LOCAL_READY" else "❌"
        rem_badge = "✅" if remote_status == "REMOTE_READY" else ("⏳" if remote_status == "PENDING_CONFIGURATION" else "❌")
        print(f"Local Environment:  {loc_badge} {local_status} (Offline coding & task branch capable)")
        print(f"Remote Integration: {rem_badge} {remote_status} (GitHub CLI & Project v2 sync)")
        print("\n--- Local Readiness ---")
        for r in local_results:
            if args.quiet and r.status == Status.PASS:
                continue
            badge = icons.get(r.status, r.status)
            print(f"{badge:<26} {r.name}: {r.message}")
            if r.remediation and r.status != Status.PASS:
                print(f"   ↳ Fix: {r.remediation}")
        print("\n--- Remote Integration (GitHub & Bot) ---")
        for r in remote_results:
            if args.quiet and r.status == Status.PASS:
                continue
            badge = icons.get(r.status, r.status)
            print(f"{badge:<26} {r.name}: {r.message}")
            if r.remediation and r.status != Status.PASS:
                print(f"   ↳ Fix: {r.remediation}")
        print("=======================================================\n")

    if has_failures:
        sys.exit(1)
    if args.strict and has_warnings:
        sys.exit(2)
    sys.exit(0)

if __name__ == "__main__":
    main()
