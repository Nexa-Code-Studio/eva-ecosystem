"""
Unit tests for Antigravity Skills, Rules, and Hooks Discovery.
"""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path

from scripts.agentic.common import get_repo_root

class TestSkillsAndRules(unittest.TestCase):
    def setUp(self):
        self.repo_root = get_repo_root()

    def test_required_skills_exist_and_have_frontmatter(self):
        required_skills = [
            "developer-onboarding",
            "task-startup",
            "project-state-sync",
            "pr-preparation",
            "inspect-project-tasks",
            "start-task",
            "sync-project-state",
            "prepare-pr",
            "manage-github-project",
        ]
        skills_dir = self.repo_root / ".agents" / "skills"
        self.assertTrue(skills_dir.is_dir(), ".agents/skills must be a directory")

        for skill_name in required_skills:
            skill_path = skills_dir / skill_name / "SKILL.md"
            self.assertTrue(skill_path.is_file(), f"SKILL.md missing for {skill_name}")

            content = skill_path.read_text(encoding="utf-8")
            self.assertTrue(content.startswith("---"), f"{skill_name}/SKILL.md must start with YAML frontmatter")

            # Check name field
            name_match = re.search(r"^name:\s*([\w\-]+)", content, re.MULTILINE)
            self.assertIsNotNone(name_match, f"{skill_name} missing 'name:' in frontmatter")
            self.assertEqual(name_match.group(1), skill_name)

            # Check description field
            desc_match = re.search(r"^description:\s*(.+)", content, re.MULTILINE)
            self.assertIsNotNone(desc_match, f"{skill_name} missing 'description:' in frontmatter")

    def test_rules_frontmatter(self):
        rules_dir = self.repo_root / ".agents" / "rules"
        self.assertTrue(rules_dir.is_dir(), ".agents/rules must be a directory")

        workflow_rule = rules_dir / "agentic-workflow-constraints.md"
        self.assertTrue(workflow_rule.is_file(), "agentic-workflow-constraints.md must exist")

        github_coordination_rule = rules_dir / "github-coordination.md"
        self.assertTrue(github_coordination_rule.is_file(), "github-coordination.md must exist")

        native_gh_rule = rules_dir / "native-gh-execution.md"
        self.assertTrue(native_gh_rule.is_file(), "native-gh-execution.md must exist")

        content = workflow_rule.read_text(encoding="utf-8")
        self.assertTrue(content.startswith("---"), "Rule must start with YAML frontmatter")
        self.assertIn("trigger:", content)
        self.assertIn("description:", content)

        gh_content = github_coordination_rule.read_text(encoding="utf-8")
        self.assertTrue(gh_content.startswith("---"), "github-coordination.md must start with YAML frontmatter")
        self.assertIn("trigger:", gh_content)
        self.assertIn("description:", gh_content)

        native_content = native_gh_rule.read_text(encoding="utf-8")
        self.assertTrue(native_content.startswith("---"), "native-gh-execution.md must start with YAML frontmatter")
        self.assertIn("trigger:", native_content)
        self.assertIn("description:", native_content)

    def test_hooks_json_validity(self):
        hooks_file = self.repo_root / ".agents" / "hooks.json"
        self.assertTrue(hooks_file.is_file(), ".agents/hooks.json must exist")

        with open(hooks_file, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertIn("session-preflight", data)
        hook_spec = data["session-preflight"]
        self.assertTrue(hook_spec.get("enabled", True))
        self.assertIn("SessionStart", hook_spec)
        self.assertIn("PreInvocation", hook_spec)

    def test_agents_markdown_policies(self):
        agents_file = self.repo_root / "AGENTS.md"
        self.assertTrue(agents_file.is_file(), "Root AGENTS.md must exist")
        content = agents_file.read_text(encoding="utf-8")
        self.assertIn("Supervised Autonomous Development Coordination Policies", content)
        self.assertIn("developer-onboarding", content)
        self.assertIn("task-startup", content)
        self.assertIn("project-state-sync", content)
        self.assertIn("pr-preparation", content)

    def test_developer_schema_and_example(self):
        schema_path = self.repo_root / ".agent" / "developer.schema.json"
        example_path = self.repo_root / ".agent" / "developer.example.json"

        self.assertTrue(schema_path.is_file())
        self.assertTrue(example_path.is_file())

        with open(schema_path, "r", encoding="utf-8") as f:
            schema = json.load(f)
        self.assertEqual(schema.get("title"), "AgenticDeveloperIdentity")

        with open(example_path, "r", encoding="utf-8") as f:
            example = json.load(f)
        self.assertEqual(example.get("schema_version"), 1)
        self.assertIn("developer", example)
        self.assertIn("workspace", example)

if __name__ == "__main__":
    unittest.main()
