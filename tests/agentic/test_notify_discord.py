"""
Unit tests for Discord Webhook Notification formatting and safety.
"""

from __future__ import annotations

import json
import unittest
from scripts.agentic.notify_discord import (
    build_payload,
    parse_mention_map,
    sanitize_discord_content,
    send_webhook,
)

class TestNotifyDiscord(unittest.TestCase):
    def test_parse_mention_map(self):
        raw = json.dumps({"budipratama": "123456789012345678", "invaliduser": "not-numeric"})
        parsed = parse_mention_map(raw)
        self.assertEqual(parsed.get("budipratama"), "123456789012345678")
        self.assertNotIn("invaliduser", parsed)

    def test_sanitize_mass_pings(self):
        cleaned = sanitize_discord_content("Hello @everyone and @here please review!")
        self.assertNotIn("@everyone", cleaned)
        self.assertNotIn("@here", cleaned)
        self.assertIn("@\u200beveryone", cleaned)
        self.assertIn("@\u200bhere", cleaned)

    def test_sanitize_raw_mentions(self):
        cleaned = sanitize_discord_content("Injecting <@999999> into the message")
        self.assertNotIn("<@999999>", cleaned)
        self.assertIn("[mention]", cleaned)

    def test_payload_with_mapped_mention(self):
        mention_map = {"budipratama": "987654321"}
        payload, mentions = build_payload(
            event_type="issue_assigned",
            title="Implement Voice Synthesis",
            url="https://github.com/Nexa-Code-Studio/eva-ecosystem/issues/12",
            actor="budipratama",
            repo_name="Nexa-Code-Studio/eva-ecosystem",
            details="Assigned to Budi",
            mention_map=mention_map,
        )
        self.assertIn("<@987654321>", payload["content"])
        self.assertEqual(payload["allowed_mentions"]["users"], ["987654321"])
        self.assertEqual(payload["allowed_mentions"]["parse"], [])

    def test_payload_without_mapped_mention(self):
        mention_map = {"budipratama": "987654321"}
        payload, mentions = build_payload(
            event_type="issue_assigned",
            title="Implement Voice Synthesis",
            url="https://github.com/Nexa-Code-Studio/eva-ecosystem/issues/12",
            actor="unknown_dev",
            repo_name="Nexa-Code-Studio/eva-ecosystem",
            details="Assigned to unknown dev",
            mention_map=mention_map,
        )
        self.assertNotIn("<@", payload["content"])
        self.assertEqual(payload["allowed_mentions"]["users"], [])

    def test_send_webhook_mock_success(self):
        def mock_poster(url: str, data: bytes):
            return 204, b""

        payload = {"content": "Test"}
        success, msg = send_webhook("http://mock.test", payload, http_poster=mock_poster)
        self.assertTrue(success)
        self.assertIn("HTTP 204", msg)

    def test_send_webhook_mock_retry_on_429(self):
        attempts = 0

        def mock_poster_with_rate_limit(url: str, data: bytes):
            nonlocal attempts
            attempts += 1
            if attempts == 1:
                import urllib.error
                import io
                fp = io.BytesIO(b'{"retry_after": 0.01}')
                raise urllib.error.HTTPError(url, 429, "Too Many Requests", {}, fp)
            return 200, b'{"ok": true}'

        payload = {"content": "Test"}
        success, msg = send_webhook("http://mock.test", payload, max_retries=2, http_poster=mock_poster_with_rate_limit)
        self.assertTrue(success)
        self.assertEqual(attempts, 2)

if __name__ == "__main__":
    unittest.main()
