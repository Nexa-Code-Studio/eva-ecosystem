#!/usr/bin/env python3
"""
Common utilities for agentic workflow scripts.
Standard library only: zero external dependencies.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

SCHEMA_VERSION = 1

class Status:
    PASS = "PASS"
    WARN = "WARN"
    FAIL = "FAIL"
    PENDING_CONFIGURATION = "PENDING_CONFIGURATION"

def get_repo_root() -> Path:
    """Find the Git repository root directory."""
    try:
        res = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            check=True
        )
        return Path(res.stdout.strip())
    except Exception:
        # Fallback to parent of scripts/agentic/
        return Path(__file__).resolve().parent.parent.parent

def get_identity_path() -> Path:
    """
    Locate the developer local configuration file.
    Supports worktrees by checking root .agent/ first,
    or looking up to the main worktree git directory.
    """
    env_path = os.environ.get("AGENTIC_DEV_CONFIG")
    if env_path:
        return Path(env_path)

    repo_root = get_repo_root()
    direct_path = repo_root / ".agent" / "developer.local.json"
    if direct_path.is_file():
        return direct_path

    # If running inside a git worktree, check the main worktree repository root
    try:
        common_git = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            capture_output=True,
            text=True
        )
        if common_git.returncode == 0 and common_git.stdout.strip():
            main_git = Path(common_git.stdout.strip()).resolve()
            if main_git.name == ".git":
                main_root = main_git.parent
                main_config = main_root / ".agent" / "developer.local.json"
                if main_config.is_file():
                    return main_config
    except Exception:
        pass

    return direct_path

def get_schema_path() -> Path:
    return get_repo_root() / ".agent" / "developer.schema.json"

def get_example_path() -> Path:
    return get_repo_root() / ".agent" / "developer.example.json"

def load_identity() -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    """
    Load developer identity JSON.
    Returns (data, error_message).
    """
    config_file = get_identity_path()
    if not config_file.is_file():
        return None, f"Developer configuration not found at {config_file}"

    try:
        with open(config_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data, None
    except json.JSONDecodeError as e:
        return None, f"Invalid JSON in {config_file}: {e}"
    except Exception as e:
        return None, f"Error reading {config_file}: {e}"

def validate_identity(data: Dict[str, Any]) -> Tuple[bool, List[str]]:
    """
    Validate identity against requirements without external jsonschema dependency.
    """
    errors: List[str] = []
    if not isinstance(data, dict):
        return False, ["Root structure must be a JSON object"]

    if data.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")

    dev = data.get("developer")
    if not isinstance(dev, dict):
        errors.append("'developer' object is required")
    else:
        name = dev.get("display_name")
        if not name or not isinstance(name, str) or not name.strip():
            errors.append("developer.display_name must be a non-empty string")
        
        username = dev.get("github_username")
        if not username or not isinstance(username, str):
            errors.append("developer.github_username must be a string")
        elif not re.match(r"^[a-zA-Z0-9](?:[a-zA-Z0-9]|-(?=[a-zA-Z0-9])){0,38}$", username):
            errors.append(f"developer.github_username '{username}' is not a valid GitHub username format")

    ws = data.get("workspace")
    if not isinstance(ws, dict):
        errors.append("'workspace' object is required")
    else:
        machine = ws.get("machine_label")
        if not machine or not isinstance(machine, str) or not machine.strip():
            errors.append("workspace.machine_label must be a non-empty string")

    proj = data.get("project")
    if proj is not None:
        if not isinstance(proj, dict):
            errors.append("'project' must be an object if present")
        else:
            p_num = proj.get("project_number")
            if p_num is not None and (not isinstance(p_num, int) or p_num < 1):
                errors.append("project.project_number must be a positive integer")

    return (len(errors) == 0), errors

def run_cmd(args: List[str], cwd: Optional[Path] = None, check: bool = False) -> subprocess.CompletedProcess:
    """Run shell command and return CompletedProcess."""
    return subprocess.run(
        args,
        cwd=str(cwd) if cwd else str(get_repo_root()),
        capture_output=True,
        text=True,
        check=check
    )

def is_git_ignored(path: Path) -> bool:
    """Check if a path is ignored by git."""
    repo_root = get_repo_root()
    try:
        rel_path = path.resolve().relative_to(repo_root.resolve())
    except ValueError:
        return False
    res = subprocess.run(
        ["git", "check-ignore", "-q", str(rel_path)],
        cwd=str(repo_root),
        capture_output=True,
    )
    return res.returncode == 0

def get_git_branch() -> str:
    res = run_cmd(["git", "branch", "--show-current"])
    return res.stdout.strip() if res.returncode == 0 else ""

def get_git_remote_url() -> str:
    res = run_cmd(["git", "remote", "get-url", "origin"])
    return res.stdout.strip() if res.returncode == 0 else ""

def get_default_branch() -> str:
    # Try symbolic ref origin/HEAD
    res = run_cmd(["git", "symbolic-ref", "refs/remotes/origin/HEAD"])
    if res.returncode == 0:
        return res.stdout.strip().replace("refs/remotes/origin/", "")
    # Default fallback
    return "main"

def find_gh_binary() -> Optional[str]:
    """Locate gh binary from PATH or common user local directories."""
    direct = shutil.which("gh")
    if direct:
        return direct
    candidates = [
        Path.home() / ".local" / "bin" / "gh",
        Path("/home/mashupsoat/.local/bin/gh"),
        Path("/usr/local/bin/gh"),
        Path("/usr/bin/gh"),
    ]
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK):
            return str(c)
    return None

def get_gh_active_user() -> Tuple[Optional[str], Optional[str]]:
    """
    Returns (github_login, error_message).
    """
    gh_bin = find_gh_binary() or "gh"
    res = run_cmd([gh_bin, "api", "user", "--jq", ".login"])
    if res.returncode != 0:
        return None, res.stderr.strip() or "gh CLI not authenticated or not available"
    return res.stdout.strip(), None

def sanitize_text(text: str, max_len: int = 256) -> str:
    """Sanitize strings: strip unwanted control characters and limit length."""
    if not text:
        return ""
    clean = re.sub(r"[\x00-\x1f\x7f-\x9f]", " ", text)
    clean = " ".join(clean.split())
    if len(clean) > max_len:
        return clean[: max_len - 3] + "..."
    return clean

def mask_secret(value: str) -> str:
    if not value or len(value) <= 6:
        return "******"
    return f"{value[:3]}...{value[-3:]}"
