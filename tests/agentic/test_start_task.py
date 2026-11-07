"""
Unit tests for Task Startup & Branch Convention Validation.
"""

from __future__ import annotations

import unittest
from scripts.agentic.start_task import format_slug, validate_branch_name

class TestStartTask(unittest.TestCase):
    def test_format_slug_sanitization(self):
        self.assertEqual(format_slug("User Authentication!"), "user-authentication")
        self.assertEqual(format_slug("fix___multiple---dashes"), "fix-multiple-dashes")
        self.assertEqual(format_slug("Hello World 123"), "hello-world-123")
        self.assertEqual(format_slug("   trailing spaces   "), "trailing-spaces")

    def test_validate_valid_branch_names(self):
        valid_branches = [
            "feat/128-user-authentication",
            "fix/130-login-validation",
            "refactor/45-clean-architecture",
            "docs/10-onboarding-guide",
            "test/99-e2e-pipeline",
            "chore/1-update-deps",
        ]
        for b in valid_branches:
            self.assertTrue(validate_branch_name(b), f"Branch '{b}' should be valid")

    def test_validate_invalid_branch_names(self):
        invalid_branches = [
            "feat/login",                  # Missing issue number
            "fix-130-login",               # Missing slash
            "random/128-something",        # Disallowed type prefix
            "dev/budipratama",             # Prohibited personal branch
            "feat/128-Upper_Case_Slug",    # Non-kebab slug
            "feat/abc-invalid-issue-num",  # Non-numeric issue
        ]
        for b in invalid_branches:
            self.assertFalse(validate_branch_name(b), f"Branch '{b}' should be invalid")

if __name__ == "__main__":
    unittest.main()
