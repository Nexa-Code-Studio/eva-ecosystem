#!/usr/bin/env python3
"""
Comprehensive CI/CD Workflow & Automation Test Suite
Validates GitHub Actions workflows, trigger path isolation, Docker Compose production
integrity, and credential hygiene across the repository.
"""

import os
import re
import unittest
from pathlib import Path
import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS_DIR = REPO_ROOT / ".github" / "workflows"
DOCKER_COMPOSE_PROD = REPO_ROOT / "docker-compose.prod.yml"


def load_workflow_yaml(path: Path) -> dict:
    """Load workflow YAML normalizing PyYAML's boolean interpretation of 'on'."""
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if isinstance(data, dict) and True in data and "on" not in data:
        data["on"] = data.pop(True)
    return data


class TestCICDWorkflows(unittest.TestCase):
    """Test suite validating all CI/CD pipelines and production configurations."""

    def setUp(self):
        self.assertTrue(WORKFLOWS_DIR.exists(), f"Workflows directory missing: {WORKFLOWS_DIR}")
        self.workflow_files = list(WORKFLOWS_DIR.glob("*.yml")) + list(WORKFLOWS_DIR.glob("*.yaml"))
        self.assertGreater(len(self.workflow_files), 0, "No workflow YAML files found.")

    def test_workflow_yaml_syntax_and_schema(self):
        """Ensure all workflow files in .github/workflows are valid YAML and have required top-level keys."""
        for wf_path in self.workflow_files:
            with self.subTest(workflow=wf_path.name):
                try:
                    content = load_workflow_yaml(wf_path)
                except yaml.YAMLError as exc:
                    self.fail(f"YAML parsing error in {wf_path.name}: {exc}")

                self.assertIsInstance(content, dict, f"{wf_path.name} root must be a dict.")
                self.assertIn("name", content, f"{wf_path.name} must have a 'name' field.")
                self.assertIn("on", content, f"{wf_path.name} must have an 'on' field.")
                self.assertIn("jobs", content, f"{wf_path.name} must have a 'jobs' field.")
                self.assertIsInstance(content["jobs"], dict, f"{wf_path.name} 'jobs' must be a dict.")

    def test_mobile_release_workflow_spec(self):
        """Verify Issue #46 requirements in build-mobile.yml."""
        build_mobile = WORKFLOWS_DIR / "build-mobile.yml"
        self.assertTrue(build_mobile.exists(), "build-mobile.yml must exist.")

        data = load_workflow_yaml(build_mobile)

        # Check triggers
        on_trigger = data.get("on", {})
        self.assertIn("push", on_trigger, "build-mobile.yml must trigger on push.")
        push_spec = on_trigger["push"]
        self.assertIn("main", push_spec.get("branches", []), "Push must trigger on 'main' branch.")
        self.assertIn("apps/eva_mobile/**", push_spec.get("paths", []), "Push must filter on apps/eva_mobile/**.")

        # Check jobs
        jobs = data.get("jobs", {})
        self.assertIn("build-android", jobs, "Must have build-android job.")
        self.assertIn("publish-release", jobs, "Must have publish-release job.")

        # Check that eva-mobile-release.apk is created
        raw_text = build_mobile.read_text(encoding="utf-8")
        self.assertIn("eva-mobile-release.apk", raw_text, "Workflow must produce 'eva-mobile-release.apk'.")
        self.assertIn("softprops/action-gh-release", raw_text, "Workflow must publish release assets.")

    def test_deploy_backend_vps_spec(self):
        """Verify deploy-backend-vps.yml specification and GHCR integration."""
        deploy_vps = WORKFLOWS_DIR / "deploy-backend-vps.yml"
        self.assertTrue(deploy_vps.exists(), "deploy-backend-vps.yml must exist.")

        data = load_workflow_yaml(deploy_vps)

        # Trigger isolation
        on_trigger = data.get("on", {})
        self.assertIn("push", on_trigger, "deploy-backend-vps.yml must trigger on push.")
        push_paths = on_trigger["push"].get("paths", [])
        self.assertIn("apps/backend/**", push_paths, "Must trigger on apps/backend/**.")
        self.assertIn("packages/**", push_paths, "Must trigger on packages/**.")
        self.assertIn("docker-compose.prod.yml", push_paths, "Must trigger on docker-compose.prod.yml.")

        # Permissions: packages: write for GHCR
        permissions = data.get("permissions", {})
        self.assertEqual(permissions.get("packages"), "write", "Workflow requires 'packages: write' for GHCR.")

        # Jobs
        jobs = data.get("jobs", {})
        self.assertIn("build-and-push", jobs, "Must have build-and-push job.")
        self.assertIn("deploy-to-vps", jobs, "Must have deploy-to-vps job.")

        raw_text = deploy_vps.read_text(encoding="utf-8")
        self.assertIn("ghcr.io", raw_text, "Workflow must reference ghcr.io.")
        self.assertIn("appleboy/ssh-action", raw_text, "Workflow must use SSH action for VPS deployment.")
        self.assertIn("/root/vps-blueprints/runbooks/deploy-eva-backend.sh", raw_text, "Workflow must call deployment runbook.")

    def test_deploy_mobile_vercel_spec(self):
        """Verify deploy-mobile-vercel.yml auto-triggers on push to main."""
        vercel_wf = WORKFLOWS_DIR / "deploy-mobile-vercel.yml"
        self.assertTrue(vercel_wf.exists(), "deploy-mobile-vercel.yml must exist.")

        data = load_workflow_yaml(vercel_wf)

        on_trigger = data.get("on", {})
        self.assertIn("push", on_trigger, "deploy-mobile-vercel.yml must trigger on push.")
        self.assertIn("main", on_trigger["push"].get("branches", []), "Push must trigger on 'main'.")
        self.assertIn("apps/eva_mobile/**", on_trigger["push"].get("paths", []), "Push must filter on apps/eva_mobile/**.")

    def test_trigger_path_isolation(self):
        """Verify mobile and backend workflows have mutually isolated path filters."""
        mobile_data = load_workflow_yaml(WORKFLOWS_DIR / "build-mobile.yml")
        backend_data = load_workflow_yaml(WORKFLOWS_DIR / "deploy-backend-vps.yml")

        mobile_paths = set(mobile_data["on"]["push"].get("paths", []))
        backend_paths = set(backend_data["on"]["push"].get("paths", []))

        overlap = mobile_paths.intersection(backend_paths)
        self.assertEqual(len(overlap), 0, f"Path overlap detected between mobile and backend workflows: {overlap}")

    def test_docker_compose_prod_structure(self):
        """Verify docker-compose.prod.yml has GHCR image references and healthy services."""
        self.assertTrue(DOCKER_COMPOSE_PROD.exists(), "docker-compose.prod.yml must exist.")

        with open(DOCKER_COMPOSE_PROD, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f)

        services = data.get("services", {})
        for svc_name in ["api", "mcp", "worker", "postgres", "redis", "qdrant"]:
            self.assertIn(svc_name, services, f"Required service '{svc_name}' missing in docker-compose.prod.yml.")

        # api, mcp, worker must have pre-built ghcr image references
        for svc_name in ["api", "mcp", "worker"]:
            image = services[svc_name].get("image", "")
            self.assertTrue(image.startswith("ghcr.io/nexa-code-studio/eva-"),
                            f"Service '{svc_name}' image should reference GHCR, found: {image}")

    def test_no_hardcoded_secrets_in_repo_configs(self):
        """Verify no sensitive API keys, private tokens, or SSH keys are hardcoded in YAML/compose configs."""
        suspicious_patterns = [
            (re.compile(r"sk-[a-zA-Z0-9]{32,}", re.IGNORECASE), "DeepSeek / OpenAI secret key"),
            (re.compile(r"sk_[a-zA-Z0-9]{32,}", re.IGNORECASE), "ElevenLabs / Stripe secret key"),
            (re.compile(r"-----BEGIN (OPENSSH|RSA) PRIVATE KEY-----"), "Raw SSH Private Key"),
            (re.compile(r"ghp_[a-zA-Z0-9]{36}"), "GitHub Personal Access Token"),
        ]

        files_to_check = list(self.workflow_files) + [DOCKER_COMPOSE_PROD]

        for filepath in files_to_check:
            text = filepath.read_text(encoding="utf-8")
            for pattern, desc in suspicious_patterns:
                match = pattern.search(text)
                self.assertIsNone(match, f"Found hardcoded {desc} in {filepath.name}!")


if __name__ == "__main__":
    unittest.main()
