"""
Unit tests for Developer Identity Bootstrap & Schema Validation.
"""

from __future__ import annotations

import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

import scripts.agentic.common as common
from scripts.agentic.common import SCHEMA_VERSION, validate_identity

class TestBootstrapIdentity(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.original_env = os.environ.get("AGENTIC_DEV_CONFIG")

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)
        if self.original_env:
            os.environ["AGENTIC_DEV_CONFIG"] = self.original_env
        else:
            os.environ.pop("AGENTIC_DEV_CONFIG", None)

    def test_valid_identity_schema(self):
        valid_data = {
            "schema_version": SCHEMA_VERSION,
            "developer": {
                "display_name": "Alice Dev",
                "github_username": "alice-dev",
            },
            "workspace": {
                "machine_label": "laptop-01",
            },
        }
        valid, errors = validate_identity(valid_data)
        self.assertTrue(valid, f"Expected valid, got errors: {errors}")
        self.assertEqual(len(errors), 0)

    def test_invalid_schema_version(self):
        invalid_data = {
            "schema_version": 999,
            "developer": {"display_name": "Bob", "github_username": "bob"},
            "workspace": {"machine_label": "box"},
        }
        valid, errors = validate_identity(invalid_data)
        self.assertFalse(valid)
        self.assertTrue(any("schema_version" in e for e in errors))

    def test_missing_developer_fields(self):
        invalid_data = {
            "schema_version": SCHEMA_VERSION,
            "developer": {"display_name": ""},
            "workspace": {"machine_label": "box"},
        }
        valid, errors = validate_identity(invalid_data)
        self.assertFalse(valid)
        self.assertTrue(any("github_username" in e for e in errors))
        self.assertTrue(any("display_name" in e for e in errors))

    def test_invalid_github_username_characters(self):
        invalid_data = {
            "schema_version": SCHEMA_VERSION,
            "developer": {
                "display_name": "Charlie",
                "github_username": "charlie@invalidsymbols!",
            },
            "workspace": {"machine_label": "box"},
        }
        valid, errors = validate_identity(invalid_data)
        self.assertFalse(valid)
        self.assertTrue(any("valid GitHub username format" in e for e in errors))

    def test_load_identity_from_custom_env(self):
        temp_file = Path(self.test_dir) / "custom.local.json"
        data = {
            "schema_version": SCHEMA_VERSION,
            "developer": {"display_name": "Env Tester", "github_username": "envtester"},
            "workspace": {"machine_label": "test-env"},
        }
        with open(temp_file, "w") as f:
            json.dump(data, f)

        os.environ["AGENTIC_DEV_CONFIG"] = str(temp_file)
        loaded, err = common.load_identity()
        self.assertIsNone(err)
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded["developer"]["github_username"], "envtester")

    def test_project_binding_validation(self):
        valid_with_project = {
            "schema_version": SCHEMA_VERSION,
            "developer": {"display_name": "Dev", "github_username": "valid-dev"},
            "workspace": {"machine_label": "box"},
            "project": {
                "project_number": 42,
                "project_owner": "Nexa-Code-Studio",
                "project_title": "Sprint Board",
            },
        }
        valid, errors = validate_identity(valid_with_project)
        self.assertTrue(valid)

        invalid_project = {
            "schema_version": SCHEMA_VERSION,
            "developer": {"display_name": "Dev", "github_username": "valid-dev"},
            "workspace": {"machine_label": "box"},
            "project": {"project_number": -5},
        }
        valid, errors = validate_identity(invalid_project)
        self.assertFalse(valid)
        self.assertTrue(any("positive integer" in e for e in errors))

if __name__ == "__main__":
    unittest.main()
