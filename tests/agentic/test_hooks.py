"""
Unit tests for Antigravity Lifecycle Hook Preflight Handler.
"""

from __future__ import annotations

import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path

from scripts.agentic.common import SCHEMA_VERSION
from scripts.agentic.hook_preflight import run_hook

class TestHooks(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.original_env = os.environ.get("AGENTIC_DEV_CONFIG")

    def tearDown(self):
        shutil.rmtree(self.test_dir, ignore_errors=True)
        if self.original_env:
            os.environ["AGENTIC_DEV_CONFIG"] = self.original_env
        else:
            os.environ.pop("AGENTIC_DEV_CONFIG", None)

    def test_session_start_without_identity(self):
        non_existent = Path(self.test_dir) / "empty.json"
        os.environ["AGENTIC_DEV_CONFIG"] = str(non_existent)

        res = run_hook("SessionStart")
        self.assertIn("injectSteps", res)
        self.assertGreater(len(res["injectSteps"]), 0)
        self.assertIn("systemMessage", res["injectSteps"][0])
        msg = res["injectSteps"][0]["systemMessage"]["systemMessage"]
        self.assertIn("Local developer identity is NOT configured", msg)

    def test_session_start_with_valid_identity(self):
        valid_file = Path(self.test_dir) / "valid.json"
        data = {
            "schema_version": SCHEMA_VERSION,
            "developer": {"display_name": "Hook Tester", "github_username": "hook-user"},
            "workspace": {"machine_label": "hook-machine"},
        }
        with open(valid_file, "w") as f:
            json.dump(data, f)
        os.environ["AGENTIC_DEV_CONFIG"] = str(valid_file)

        res = run_hook("SessionStart")
        self.assertIn("injectSteps", res)
        self.assertGreater(len(res["injectSteps"]), 0)
        msg = res["injectSteps"][0]["systemMessage"]["systemMessage"]
        self.assertIn("Hook Tester", msg)
        self.assertIn("@hook-user", msg)
        self.assertIn("hook-machine", msg)

    def test_pre_invocation_with_valid_identity(self):
        valid_file = Path(self.test_dir) / "valid.json"
        data = {
            "schema_version": SCHEMA_VERSION,
            "developer": {"display_name": "Hook Tester", "github_username": "hook-user"},
            "workspace": {"machine_label": "hook-machine"},
        }
        with open(valid_file, "w") as f:
            json.dump(data, f)
        os.environ["AGENTIC_DEV_CONFIG"] = str(valid_file)

        res = run_hook("PreInvocation")
        self.assertIn("injectSteps", res)
        self.assertGreater(len(res["injectSteps"]), 0)
        self.assertIn("ephemeralMessage", res["injectSteps"][0])
        self.assertIn("@hook-user", res["injectSteps"][0]["ephemeralMessage"])

if __name__ == "__main__":
    unittest.main()
