#!/usr/bin/env python3
"""
Antigravity CLI Lifecycle Hook: Session Preflight.
Executes on SessionStart and PreInvocation hooks configured in .agents/hooks.json.
Reads hook context from stdin, validates developer identity, and emits
JSON injectSteps on stdout conforming to Antigravity hooks specification.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    get_git_branch,
    get_identity_path,
    load_identity,
    validate_identity,
)

def run_hook(event: str, raw_input: str = "") -> dict:
    hook_data = {}
    if raw_input.strip():
        try:
            hook_data = json.loads(raw_input)
        except Exception:
            pass

    identity_data, err = load_identity()
    branch = get_git_branch()

    inject_steps = []

    if err or not identity_data:
        msg = (
            "⚠️ [Agentic Workflow Preflight Notice] Local developer identity is NOT configured.\n"
            "Please run `python3 scripts/agentic/bootstrap.py` to register your local developer identity "
            "before modifying code or task state."
        )
        if event == "SessionStart":
            inject_steps.append({"systemMessage": {"systemMessage": msg}})
        else:
            inject_steps.append({"ephemeralMessage": msg})
    else:
        valid, _ = validate_identity(identity_data)
        dev = identity_data.get("developer", {})
        ws = identity_data.get("workspace", {})
        name = dev.get("display_name", "Developer")
        user = dev.get("github_username", "unknown")
        machine = ws.get("machine_label", "workstation")

        if event == "SessionStart":
            msg = (
                f"🛡️ [Agentic Workflow Active] Developer: {name} (@{user}) | Machine: {machine} | Branch: {branch or 'main'}.\n"
                "Supervised Autonomous Development Coordination is active. Follow task conventions and verify evidence."
            )
            inject_steps.append({"systemMessage": {"systemMessage": msg}})
        else:
            msg = f"Task: {branch} | Developer: @{user}"
            inject_steps.append({"ephemeralMessage": msg})

    return {
        "injectSteps": inject_steps,
        "terminationBehavior": "",
    }

def main():
    parser = argparse.ArgumentParser(description="Lifecycle hook preflight handler")
    parser.add_argument("--event", choices=["SessionStart", "PreInvocation"], default="SessionStart")
    args = parser.parse_args()

    raw_input = ""
    try:
        if not sys.stdin.isatty():
            raw_input = sys.stdin.read()
    except Exception:
        pass

    output = run_hook(args.event, raw_input)
    print(json.dumps(output))
    sys.exit(0)

if __name__ == "__main__":
    main()
