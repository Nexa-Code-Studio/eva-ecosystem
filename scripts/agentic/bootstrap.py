#!/usr/bin/env python3
"""
Developer Onboarding / Bootstrap Tool.
Initializes and validates local developer identity in .agent/developer.local.json.
Safe, non-destructive, and strictly gitignored.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import socket
import sys
from pathlib import Path

# Ensure scripts/agentic is in sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    SCHEMA_VERSION,
    get_identity_path,
    get_repo_root,
    is_git_ignored,
    load_identity,
    run_cmd,
    validate_identity,
)
import doctor

def detect_defaults() -> dict:
    git_name = ""
    try:
        res = run_cmd(["git", "config", "user.name"])
        if res.returncode == 0:
            git_name = res.stdout.strip()
    except Exception:
        pass

    try:
        host = socket.gethostname().split(".")[0]
    except Exception:
        host = platform.node() or "workstation"

    return {
        "display_name": git_name or os.environ.get("USER", "Developer"),
        "machine_label": host or "local-workstation",
    }

def main():
    parser = argparse.ArgumentParser(description="Developer Identity Bootstrap / Onboarding")
    parser.add_argument("--display-name", type=str, help="Developer display name")
    parser.add_argument("--github-username", type=str, help="Developer GitHub login username")
    parser.add_argument("--machine-label", type=str, help="Unique label for this machine")
    parser.add_argument("--email", type=str, help="Developer contact email (optional)")
    parser.add_argument("--project-number", type=int, help="GitHub Project v2 number (optional)")
    parser.add_argument("--project-owner", type=str, help="GitHub Project owner (organization or user login, optional)")
    parser.add_argument("--project-title", type=str, help="GitHub Project title (optional)")
    parser.add_argument("--priority-field", type=str, help="Priority field name (default: Priority)")
    parser.add_argument("--force", action="store_true", help="Overwrite existing identity")
    parser.add_argument("--check-only", action="store_true", help="Check existing identity and exit")
    parser.add_argument("--dry-run", action="store_true", help="Preview output without writing")
    parser.add_argument("--non-interactive", action="store_true", help="Fail if required parameters are missing instead of prompting")
    parser.add_argument("--no-doctor", action="store_true", help="Do not run doctor after setup")
    args = parser.parse_args()

    id_path = get_identity_path()

    if args.check_only:
        data, err = load_identity()
        if err or data is None:
            print(f"FAILED: {err}", file=sys.stderr)
            sys.exit(1)
        valid, errors = validate_identity(data)
        if not valid:
            print(f"FAILED: Schema validation failed: {'; '.join(errors)}", file=sys.stderr)
            sys.exit(1)
        print(f"OK: Developer identity is valid at {id_path}")
        sys.exit(0)

    if id_path.is_file() and not args.force:
        data, err = load_identity()
        if not err and data:
            valid, _ = validate_identity(data)
            if valid:
                dev_name = data["developer"]["display_name"]
                dev_user = data["developer"]["github_username"]
                print(f"Developer identity already exists for '{dev_name}' (@{dev_user}) at {id_path}.")
                print("Use --force to overwrite if you wish to re-configure.")
                if not args.no_doctor:
                    print("\nRunning doctor verification...")
                    results = doctor.run_diagnostics()
                    sys.exit(0 if not any(r.status == doctor.Status.FAIL for r in results) else 1)
                sys.exit(0)

    defaults = detect_defaults()

    display_name = args.display_name
    github_username = args.github_username
    machine_label = args.machine_label

    is_interactive = sys.stdin.isatty() and not args.non_interactive

    if is_interactive:
        print("=== Developer Onboarding Setup ===")
        if not display_name:
            val = input(f"Enter your Full Display Name [{defaults['display_name']}]: ").strip()
            display_name = val or defaults["display_name"]
        if not github_username:
            val = input("Enter your GitHub Username: ").strip()
            github_username = val
        if not machine_label:
            val = input(f"Enter your Machine / Workstation Label [{defaults['machine_label']}]: ").strip()
            machine_label = val or defaults["machine_label"]
    else:
        # Non-interactive mode
        if not display_name:
            display_name = defaults["display_name"]
        if not machine_label:
            machine_label = defaults["machine_label"]
        if not github_username:
            print("ERROR: --github-username is required in non-interactive mode.", file=sys.stderr)
            sys.exit(1)

    payload = {
        "schema_version": SCHEMA_VERSION,
        "developer": {
            "display_name": display_name,
            "github_username": github_username,
        },
        "workspace": {
            "machine_label": machine_label,
        },
    }

    if args.email:
        payload["developer"]["email"] = args.email

    if args.project_number:
        p_data = {
            "project_number": args.project_number,
            "project_title": args.project_title or f"Project #{args.project_number}",
            "status_field": "Status",
            "priority_field": args.priority_field or "Priority",
        }
        if args.project_owner:
            p_data["project_owner"] = args.project_owner
        payload["project"] = p_data

    valid, errors = validate_identity(payload)
    if not valid:
        print(f"ERROR: Generated configuration is invalid: {'; '.join(errors)}", file=sys.stderr)
        sys.exit(1)

    json_text = json.dumps(payload, indent=2) + "\n"

    if args.dry_run:
        print("DRY-RUN: Would write the following to:", id_path)
        print(json_text)
        sys.exit(0)

    id_path.parent.mkdir(parents=True, exist_ok=True)
    with open(id_path, "w", encoding="utf-8") as f:
        f.write(json_text)

    print(f"✅ Developer identity created successfully at {id_path}")

    # Ensure gitignore status
    if not is_git_ignored(id_path):
        print(f"⚠️  WARNING: {id_path} is NOT ignored by git! Please ensure .gitignore includes .agent/developer.local.json", file=sys.stderr)

    if not args.no_doctor:
        print("\nRunning post-bootstrap doctor check...")
        results = doctor.run_diagnostics()
        for r in results:
            print(f"  [{r.status}] {r.name}: {r.message}")
        if any(r.status == doctor.Status.FAIL for r in results):
            print("\n❌ Bootstrap completed but some diagnostic checks failed. Review errors above.", file=sys.stderr)
            sys.exit(1)

    sys.exit(0)

if __name__ == "__main__":
    main()
