#!/usr/bin/env python3
"""
Unit tests for check_mobile_backend_contract.py.
"""

import sys
import unittest
from pathlib import Path

# Add scripts/agentic to path
scripts_dir = Path(__file__).resolve().parent.parent.parent / "scripts" / "agentic"
sys.path.insert(0, str(scripts_dir))

from check_mobile_backend_contract import (
    get_repo_root,
    normalize_path,
    run_parity_audit,
)


class TestMobileBackendContractChecker(unittest.TestCase):
    def setUp(self):
        self.repo_root = get_repo_root()

    def test_normalize_path(self):
        self.assertEqual(normalize_path("/api/v1/auth/login"), "/auth/login")
        self.assertEqual(normalize_path("/users/emergency-contacts/$id"), "/users/emergency-contacts/{*}")
        self.assertEqual(normalize_path("/diaries/{diary_id}"), "/diaries/{*}")
        self.assertEqual(normalize_path("/conversations/$conversationId/messages"), "/conversations/{*}/messages")

    def test_parity_audit_execution(self):
        results = run_parity_audit(self.repo_root)
        self.assertIn("summary", results)
        self.assertIn("connected", results)
        self.assertIn("missing_in_backend", results)
        self.assertIn("local_only_features", results)

        summary = results["summary"]
        self.assertGreater(summary["total_mobile_endpoints_called"], 0)
        self.assertGreater(summary["connected_endpoints_count"], 0)
        self.assertTrue(summary["websocket_connected"])

        # Verify core endpoints are recognized as connected
        connected_paths = [c["mobile_path"] for c in results["connected"]]
        self.assertIn("/auth/login", connected_paths)
        self.assertIn("/dass/today", connected_paths)
        self.assertIn("/recommendations/today", connected_paths)

        # Verify care endpoints are recognized as missing in backend
        missing_paths = [m["mobile_path"] for m in results["missing_in_backend"]]
        self.assertIn("/care/psychologists", missing_paths)
        self.assertIn("/care/book", missing_paths)


if __name__ == "__main__":
    unittest.main()
