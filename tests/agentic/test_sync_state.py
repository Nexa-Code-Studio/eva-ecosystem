"""
Unit tests for Evidence-Based State Synchronization.
"""

from __future__ import annotations

import unittest
from scripts.agentic.sync_state import VALID_STATES, extract_issue_number, validate_transition

class TestSyncState(unittest.TestCase):
    def test_extract_issue_number(self):
        self.assertEqual(extract_issue_number("feat/128-user-auth"), 128)
        self.assertEqual(extract_issue_number("fix/42-fix-glitch"), 42)
        self.assertIsNone(extract_issue_number("main"))
        self.assertIsNone(extract_issue_number("feat/no-number-auth"))

    def test_transition_to_in_progress_requires_branch(self):
        allowed, msg = validate_transition("Ready", "In Progress", {"branch": ""})
        self.assertFalse(allowed)
        self.assertIn("active task branch", msg)

        allowed, msg = validate_transition("Ready", "In Progress", {"branch": "feat/128-user-auth"})
        self.assertTrue(allowed)

    def test_transition_to_blocked_requires_reason(self):
        allowed, msg = validate_transition("In Progress", "Blocked", {"blocker_reason": ""})
        self.assertFalse(allowed)
        self.assertIn("blocker reason", msg)

        allowed, msg = validate_transition("In Progress", "Blocked", {"blocker_reason": "Waiting for API endpoint v2"})
        self.assertTrue(allowed)

    def test_transition_to_in_review_requires_pr_and_tests(self):
        # Missing PR
        allowed, _ = validate_transition("In Progress", "In Review", {
            "pr_url": "",
            "test_evidence": "10 tests passed",
        })
        self.assertFalse(allowed)

        # Missing test evidence
        allowed, _ = validate_transition("In Progress", "In Review", {
            "pr_url": "https://github.com/org/repo/pull/1",
            "test_evidence": "",
        })
        self.assertFalse(allowed)

        # Valid evidence
        allowed, _ = validate_transition("In Progress", "In Review", {
            "pr_url": "https://github.com/org/repo/pull/1",
            "test_evidence": "12 tests passing with 98% coverage",
        })
        self.assertTrue(allowed)

    def test_transition_to_done_requires_merge_or_approval(self):
        allowed, _ = validate_transition("In Review", "Done", {})
        self.assertFalse(allowed)

        # PR merged
        allowed, _ = validate_transition("In Review", "Done", {"pr_merged": True})
        self.assertTrue(allowed)

        # Close approval
        allowed, _ = validate_transition("In Review", "Done", {"close_approval": "Approved by Tech Lead"})
        self.assertTrue(allowed)

    def test_invalid_target_state(self):
        allowed, msg = validate_transition("Backlog", "SuperDone", {})
        self.assertFalse(allowed)
        self.assertIn("not one of valid states", msg)

    def test_state_machine_invalid_transition(self):
        # Backlog -> In Review is not allowed by state machine
        allowed, msg = validate_transition("Backlog", "In Review", {
            "pr_url": "https://github.com/org/repo/pull/1",
            "test_evidence": "All tests pass",
        })
        self.assertFalse(allowed)
        self.assertIn("Invalid transition from 'Backlog' to 'In Review'", msg)

    def test_terminal_state_done(self):
        # Done is terminal
        allowed, msg = validate_transition("Done", "In Progress", {"branch": "feat/123-slug"})
        self.assertFalse(allowed)
        self.assertIn("terminal", msg)

    def test_unblock_transition_to_in_progress(self):
        allowed, msg = validate_transition("Blocked", "In Progress", {"branch": "feat/128-auth"})
        self.assertTrue(allowed)
        self.assertIn("active task branch verified", msg)

    def test_idempotent_no_op(self):
        allowed, msg = validate_transition("In Progress", "In Progress", {})
        self.assertTrue(allowed)
        self.assertIn("No state change required", msg)

if __name__ == "__main__":
    unittest.main()
