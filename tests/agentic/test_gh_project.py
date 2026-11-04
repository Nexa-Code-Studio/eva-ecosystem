"""
Unit tests for Native GitHub CLI Project & Issue Manager.
"""

from __future__ import annotations

import unittest
from unittest.mock import patch, MagicMock
from scripts.agentic.gh_project import (
    create_issue,
    link_repository_to_project,
    get_gh_env,
    DEFAULT_ORG,
    DEFAULT_REPO,
    DEFAULT_PROJECT_NUMBER,
)

class TestGhProject(unittest.TestCase):
    def test_get_gh_env(self):
        env = get_gh_env()
        self.assertIsInstance(env, dict)

    def test_create_issue_dry_run(self):
        result = create_issue(
            title="Automated Test Issue",
            body="## Summary\nTest body",
            issue_type="feat",
            priority="High",
            status="Ready",
            assignee="ekyaaa",
            dry_run=True,
        )
        self.assertEqual(result.get("status"), "dry_run")
        self.assertEqual(result.get("title"), "Automated Test Issue")

    @patch("scripts.agentic.gh_project.exec_gh")
    def test_link_repo_success(self, mock_exec):
        mock_res = MagicMock()
        mock_res.returncode = 0
        mock_res.stdout = "Linked repository"
        mock_exec.return_value = mock_res

        success = link_repository_to_project(
            repo_name=DEFAULT_REPO,
            project_number=DEFAULT_PROJECT_NUMBER,
            owner=DEFAULT_ORG,
        )
        self.assertTrue(success)
        mock_exec.assert_called_once()
        args = mock_exec.call_args[0][0]
        self.assertIn("link", args)
        self.assertIn(str(DEFAULT_PROJECT_NUMBER), args)

    @patch("scripts.agentic.gh_project.exec_gh")
    def test_create_issue_success(self, mock_exec):
        # 1st call: issue create returns URL
        mock_create = MagicMock()
        mock_create.returncode = 0
        mock_create.stdout = "https://github.com/Nexa-Code-Studio/eva-ecosystem/issues/100"

        # 2nd call: project item-add returns JSON
        mock_add = MagicMock()
        mock_add.returncode = 0
        mock_add.stdout = '{"id": "PVTI_lADOAA"}'

        # 3rd & 4th calls: update status & priority
        mock_field = MagicMock()
        mock_field.returncode = 0
        mock_field.stdout = '{"data": {}}'

        mock_exec.side_effect = [mock_create, mock_add, mock_field, mock_field]

        result = create_issue(
            title="Real Issue",
            body="Task content",
            issue_type="feat",
            dry_run=False,
        )
        self.assertEqual(result.get("status"), "success")
        self.assertEqual(result.get("issue_number"), 100)
        self.assertEqual(result.get("item_id"), "PVTI_lADOAA")

if __name__ == "__main__":
    unittest.main()
