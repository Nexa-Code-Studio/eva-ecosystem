"""
Unit tests for Pull Request Preparation.
"""

from __future__ import annotations

import unittest
from scripts.agentic.prepare_pr import extract_issue_and_type

class TestPreparePR(unittest.TestCase):
    def test_extract_issue_and_type_valid(self):
        t, i, s = extract_issue_and_type("feat/128-user-authentication")
        self.assertEqual(t, "feat")
        self.assertEqual(i, 128)
        self.assertEqual(s, "user-authentication")

        t, i, s = extract_issue_and_type("fix/130-login-glitch")
        self.assertEqual(t, "fix")
        self.assertEqual(i, 130)
        self.assertEqual(s, "login-glitch")

    def test_extract_issue_and_type_invalid(self):
        t, i, s = extract_issue_and_type("main")
        self.assertIsNone(t)
        self.assertIsNone(i)

        t, i, s = extract_issue_and_type("dev/my-branch")
        self.assertIsNone(t)

        t, i, s = extract_issue_and_type("feat/no-number-auth")
        self.assertIsNone(t)

if __name__ == "__main__":
    unittest.main()
