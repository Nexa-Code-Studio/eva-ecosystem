#!/usr/bin/env python3
"""
Discord Webhook Notification Dispatcher (Legacy Fallback / Testing Tool).
NOTE: The primary production notification sender is the existing Discord Bot
(ekyaaa/dc-bot-project-management) receiving GitHub App webhook events directly.
This script is preserved for dry-run testing and legacy fallback when configured.
Uses GitHub Secrets (DISCORD_WEBHOOK_URL, DISCORD_MENTION_MAP) strictly from environment.
Never logs secrets or leaks raw mappings.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import sanitize_text

def sanitize_discord_content(text: str) -> str:
    """Strip mass ping attempts (@everyone, @here) and control characters."""
    if not text:
        return ""
    cleaned = re.sub(r"@(everyone|here)", lambda m: "@\u200b" + m.group(1), text)
    cleaned = re.sub(r"<@&?\d+>", "[mention]", cleaned)
    return sanitize_text(cleaned, max_len=1000)

def parse_mention_map(raw_json: Optional[str]) -> Dict[str, str]:
    if not raw_json:
        return {}
    try:
        data = json.loads(raw_json)
        if isinstance(data, dict):
            return {str(k).lower(): str(v).strip() for k, v in data.items() if str(v).strip().isdigit()}
    except Exception:
        pass
    return {}

def build_payload(
    event_type: str,
    title: str,
    url: str,
    actor: str,
    repo_name: str,
    details: str,
    mention_map: Dict[str, str],
) -> Tuple[Dict[str, Any], List[str]]:
    actor_clean = sanitize_text(actor.lower())
    discord_user_id = mention_map.get(actor_clean)

    mentioned_users: List[str] = []
    content_prefix = ""

    if discord_user_id:
        content_prefix = f"<@{discord_user_id}> "
        mentioned_users.append(discord_user_id)

    color_map = {
        "issue_assigned": 0x3498DB,  # Blue
        "issue_opened": 0x2ECC71,    # Green
        "pr_ready": 0x9B59B6,        # Purple
        "review_requested": 0xE67E22,# Orange
        "ci_failure": 0xE74C3C,      # Red
        "state_sync": 0x1ABC9C,      # Turquoise
    }
    embed_color = color_map.get(event_type, 0x95A5A6)

    event_labels = {
        "issue_assigned": "📌 Issue Assigned",
        "issue_opened": "🆕 Issue Opened",
        "pr_ready": "🚀 Pull Request Ready",
        "review_requested": "👀 Review Requested",
        "ci_failure": "❌ CI Workflow Failed",
        "state_sync": "🔄 Task State Synchronized",
    }
    event_label = event_labels.get(event_type, f"Event: {event_type}")

    embed = {
        "title": f"[{repo_name}] {event_label}",
        "description": f"**{sanitize_discord_content(title)}**\n\n{sanitize_discord_content(details)}",
        "url": url if url.startswith("https://github.com/") else None,
        "color": embed_color,
        "fields": [
            {"name": "Actor", "value": f"@{actor}", "inline": True},
            {"name": "Repository", "value": repo_name, "inline": True},
        ],
        "footer": {
            "text": "Eva AI Supervised Development Coordination",
        },
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    allowed_mentions = {
        "parse": [],
        "users": mentioned_users,
    }

    payload = {
        "content": f"{content_prefix}{event_label} in `{repo_name}`",
        "embeds": [embed],
        "allowed_mentions": allowed_mentions,
    }

    return payload, mentioned_users

def send_webhook(
    url: str,
    payload: Dict[str, Any],
    max_retries: int = 3,
    http_poster: Optional[Callable[[str, bytes], Tuple[int, bytes]]] = None,
) -> Tuple[bool, str]:
    data_bytes = json.dumps(payload).encode("utf-8")

    def default_poster(target_url: str, post_data: bytes) -> Tuple[int, bytes]:
        req = urllib.request.Request(
            target_url,
            data=post_data,
            headers={
                "Content-Type": "application/json",
                "User-Agent": "Eva-Agentic-Workflow/1.0",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            return response.getcode(), response.read()

    poster = http_poster or default_poster

    for attempt in range(max_retries):
        try:
            status_code, body = poster(url, data_bytes)
            if 200 <= status_code < 300 or status_code == 204:
                return True, f"Notification delivered (HTTP {status_code})"
            return False, f"Unexpected HTTP status {status_code}"
        except urllib.error.HTTPError as e:
            if e.code == 429:
                retry_after = 2
                try:
                    res_json = json.loads(e.read().decode())
                    retry_after = float(res_json.get("retry_after", 2))
                except Exception:
                    pass
                time.sleep(min(retry_after, 5.0))
                continue
            elif 500 <= e.code < 600:
                time.sleep(1.0 * (attempt + 1))
                continue
            else:
                return False, f"HTTP error {e.code}"
        except Exception as e:
            return False, f"Network error: {type(e).__name__}"

    return False, "Exceeded maximum retry attempts"

def main():
    parser = argparse.ArgumentParser(description="Send Discord notification for GitHub events")
    parser.add_argument("--event", choices=["issue_assigned", "issue_opened", "pr_ready", "review_requested", "ci_failure", "state_sync"], required=True)
    parser.add_argument("--title", type=str, required=True, help="Title of the issue, PR, or workflow")
    parser.add_argument("--url", type=str, default="", help="GitHub Web URL")
    parser.add_argument("--actor", type=str, required=True, help="GitHub login of relevant user")
    parser.add_argument("--repo", type=str, default="Nexa-Code-Studio/eva-ecosystem", help="Repository slug")
    parser.add_argument("--details", type=str, default="", help="Additional sanitized details")
    parser.add_argument("--dry-run", action="store_true", help="Print payload without sending")
    args = parser.parse_args()

    enabled = os.environ.get("DISCORD_NOTIFICATIONS_ENABLED", "false").lower()
    if enabled not in ("true", "1", "yes") and not args.dry_run:
        print("DISCORD_NOTIFICATIONS_ENABLED is false or not set. Skipping notification.")
        sys.exit(0)

    event_var_map = {
        "issue_assigned": "DISCORD_NOTIFY_ASSIGNMENT",
        "issue_opened": "DISCORD_NOTIFY_ISSUES",
        "pr_ready": "DISCORD_NOTIFY_PR",
        "review_requested": "DISCORD_NOTIFY_PR",
        "ci_failure": "DISCORD_NOTIFY_CI_FAILURE",
        "state_sync": "DISCORD_NOTIFY_HANDOFF",
    }
    var_name = event_var_map.get(args.event)
    if var_name:
        event_setting = os.environ.get(var_name, "true").lower()
        if event_setting in ("false", "0", "no") and not args.dry_run:
            print(f"{var_name} is false. Skipping notification for event '{args.event}'.")
            sys.exit(0)

    mention_map_raw = os.environ.get("DISCORD_MENTION_MAP", "")
    mention_map = parse_mention_map(mention_map_raw)

    payload, mentions = build_payload(
        event_type=args.event,
        title=args.title,
        url=args.url,
        actor=args.actor,
        repo_name=args.repo,
        details=args.details,
        mention_map=mention_map,
    )

    if args.dry_run:
        print("=== DRY RUN DISCORD NOTIFICATION ===")
        print("Payload:")
        print(json.dumps(payload, indent=2))
        print(f"Target mentions: {mentions}")
        print("====================================")
        sys.exit(0)

    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL", "").strip()
    if not webhook_url:
        print("DISCORD_WEBHOOK_URL secret not configured in environment. Skipping safely.", file=sys.stderr)
        sys.exit(0)

    success, msg = send_webhook(webhook_url, payload)
    if success:
        print(f"✅ Discord notification sent: {msg}")
        sys.exit(0)
    else:
        print(f"⚠️  Discord notification failed: {msg}", file=sys.stderr)
        sys.exit(0)

if __name__ == "__main__":
    main()
