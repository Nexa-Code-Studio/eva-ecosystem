"""
Unit tests for Doctor Diagnostic & Preflight Tool.
"""

from __future__ import annotations

import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

import scripts.agentic.doctor as doctor
from scripts.agentic.common import SCHEMA_VERSION, Status

class TestDoctor(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.original_env = os.environ.get("AGENTIC_DEV_CONFIG")

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)
        if self.original_env:
            os.environ["AGENTIC_DEV_CONFIG"] = self.original_env
        else:
            os.environ.pop("AGENTIC_DEV_CONFIG", None)

    def test_missing_identity_fails(self):
        non_existent = Path(self.test_dir) / "does_not_exist.json"
        os.environ["AGENTIC_DEV_CONFIG"] = str(non_existent)

        results = doctor.run_diagnostics()
        id_result = next((r for r in results if r.name == "identity_file"), None)
        self.assertIsNotNone(id_result)
        self.assertEqual(id_result.status, Status.FAIL)

    def test_corrupted_json_fails(self):
        corrupt_file = Path(self.test_dir) / "corrupt.json"
        with open(corrupt_file, "w") as f:
            f.write("{ invalid json")
        os.environ["AGENTIC_DEV_CONFIG"] = str(corrupt_file)

        results = doctor.run_diagnostics()
        id_result = next((r for r in results if r.name == "identity_file"), None)
        self.assertIsNotNone(id_result)
        self.assertEqual(id_result.status, Status.FAIL)

    def test_valid_identity_passes_schema(self):
        valid_file = Path(self.test_dir) / "valid.json"
        data = {
            "schema_version": SCHEMA_VERSION,
            "developer": {"display_name": "Doctor Tester", "github_username": "doc-tester"},
            "workspace": {"machine_label": "doc-box"},
        }
        with open(valid_file, "w") as f:
            json.dump(data, f)
        os.environ["AGENTIC_DEV_CONFIG"] = str(valid_file)

        results = doctor.run_diagnostics()
        schema_result = next((r for r in results if r.name == "identity_schema"), None)
        self.assertIsNotNone(schema_result)
        self.assertEqual(schema_result.status, Status.PASS)

    def test_hooks_discovery(self):
        results = doctor.run_diagnostics()
        hook_res = next((r for r in results if r.name == "hooks_configuration"), None)
        self.assertIsNotNone(hook_res)
        self.assertEqual(hook_res.status, Status.PASS)

    def test_rules_and_skills_discovery(self):
        results = doctor.run_diagnostics()
        rs_res = next((r for r in results if r.name == "rules_and_skills"), None)
        self.assertIsNotNone(rs_res)
        self.assertEqual(rs_res.status, Status.PASS)

    def test_local_vs_remote_classification(self):
        valid_file = Path(self.test_dir) / "valid.json"
        data = {
            "schema_version": SCHEMA_VERSION,
            "developer": {"display_name": "Doctor Tester", "github_username": "doc-tester"},
            "workspace": {"machine_label": "doc-box"},
        }
        with open(valid_file, "w") as f:
            json.dump(data, f)
        os.environ["AGENTIC_DEV_CONFIG"] = str(valid_file)

        results = doctor.run_diagnostics()
        local_results = [r for r in results if r.category == "local"]
        remote_results = [r for r in results if r.category == "remote"]

        self.assertTrue(len(local_results) > 0)
        self.assertTrue(len(remote_results) > 0)
        # Check specific items
        id_res = next(r for r in local_results if r.name == "identity_file")
        self.assertEqual(id_res.status, Status.PASS)
        gh_res = next(r for r in remote_results if r.name == "gh_cli")
        self.assertIn(gh_res.status, (Status.PASS, Status.WARN, Status.PENDING_CONFIGURATION))

if __name__ == "__main__":
    unittest.main()
