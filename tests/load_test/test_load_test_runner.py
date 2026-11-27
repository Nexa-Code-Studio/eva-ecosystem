"""Unit tests for the multi-instance stress test runner configuration and metrics."""

from __future__ import annotations

import array
import json
import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import patch

from tests.load_test.audio_utils import (
    TARGET_SAMPLE_RATE,
    build_pcm_for_duration,
    iter_pcm_chunks,
    load_pcm_pool,
    load_wav_as_pcm16k,
)
from tests.load_test.config import StressConfig, distribute_users, parse_args
from tests.load_test.metrics import (
    RequestSample,
    WorkerResult,
    WsEventSample,
    percentile,
    render_markdown_report,
    summarize_results,
    write_reports,
)
from tests.load_test.run_stress_test import run_multi_instance


class StressTestConfigTests(unittest.TestCase):
    def test_url_properties_normalize_http_and_https(self) -> None:
        http_cfg = StressConfig(target_url="http://127.0.0.1:8888/")
        self.assertEqual(http_cfg.api_base_url, "http://127.0.0.1:8888/api/v1")
        self.assertEqual(http_cfg.ws_base_url, "ws://127.0.0.1:8888/api/v1")

        https_cfg = StressConfig(target_url="https://api.eva.id/api/v1")
        self.assertEqual(https_cfg.api_base_url, "https://api.eva.id/api/v1")
        self.assertEqual(https_cfg.ws_base_url, "wss://api.eva.id/api/v1")

    def test_distribute_users_across_instances(self) -> None:
        buckets = distribute_users(10, 4)
        self.assertEqual(len(buckets), 4)
        flattened = sorted(idx for b in buckets for idx in b)
        self.assertEqual(flattened, list(range(10)))

        capped = distribute_users(2, 8)
        self.assertEqual(len(capped), 2)

    def test_parse_args_with_credentials_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            cred_path = Path(tmp) / "creds.json"
            cred_path.write_text(
                json.dumps(
                    {
                        "video_sessions": [
                            {
                                "session_id": "sess-1",
                                "patient_email": "p@eva.test",
                                "patient_password": "p1",
                                "counselor_email": "c@eva.test",
                                "counselor_password": "c1",
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            cfg = parse_args(
                [
                    "--target-url",
                    "https://api.eva.id",
                    "--scenario",
                    "mixed",
                    "--users",
                    "25",
                    "--instances",
                    "4",
                    "--ai-mode",
                    "mock",
                    "--credentials-file",
                    str(cred_path),
                ]
            )
            self.assertEqual(cfg.scenario, "mixed")
            self.assertEqual(cfg.users, 25)
            self.assertEqual(cfg.instances, 4)
            self.assertEqual(cfg.user_email_domain, "gmail.com")
            self.assertFalse(cfg.shared_auth)
            self.assertEqual(len(cfg.video_pairs), 1)
            self.assertEqual(cfg.video_pairs[0].session_id, "sess-1")

            shared_cfg = parse_args(
                [
                    "--target-url",
                    "https://api.eva.id",
                    "--email-domain",
                    "example.com",
                    "--shared-auth",
                    "--voice-duration",
                    "45",
                    "--audio-pace",
                    "fast",
                    "--stt-fallback",
                ]
            )
            self.assertEqual(shared_cfg.user_email_domain, "example.com")
            self.assertTrue(shared_cfg.shared_auth)
            self.assertEqual(shared_cfg.voice_duration_seconds, 45.0)
            self.assertEqual(shared_cfg.audio_pace, "fast")
            self.assertTrue(shared_cfg.stt_fallback)


class StressTestMetricsTests(unittest.TestCase):
    def test_percentile_calculation(self) -> None:
        self.assertEqual(percentile([], 95), 0.0)
        self.assertEqual(percentile([42.0], 99), 42.0)
        self.assertAlmostEqual(percentile([10.0, 20.0, 30.0, 40.0], 50), 25.0)
        self.assertAlmostEqual(percentile([10.0, 20.0, 30.0, 40.0], 95), 38.5)

    def test_summarize_and_write_reports(self) -> None:
        cfg = StressConfig(target_url="http://127.0.0.1:8888", scenario="ai", users=2)
        workers = [
            WorkerResult(
                worker_id=0,
                user_indices=[0],
                http_samples=[
                    RequestSample("GET /conversations", 200, 50.0, True),
                    RequestSample("GET /conversations", 500, 150.0, False, "HTTP 500"),
                ],
                ws_samples=[
                    WsEventSample(
                        "WS /call/ws/{session_id}",
                        80.0,
                        1,
                        2,
                        False,
                        ttfa_ms=650.0,
                        turn_latency_ms=3200.0,
                        audio_seconds_sent=10.0,
                    ),
                ],
            ),
            WorkerResult(
                worker_id=1,
                user_indices=[1],
                http_samples=[
                    RequestSample("GET /conversations", 200, 100.0, True),
                ],
                ws_samples=[
                    WsEventSample("WS /call/ws/{session_id}", 0.0, 0, 0, True, "timeout"),
                ],
            ),
        ]
        summary = summarize_results(cfg, workers, wall_duration_s=1.25)
        self.assertEqual(summary["overall"]["http_total"], 3)
        self.assertEqual(summary["overall"]["http_errors"], 1)
        self.assertEqual(summary["overall"]["ws_total"], 2)
        self.assertEqual(summary["overall"]["ws_drops"], 1)
        ws_ep = summary["ws_endpoints"]["WS /call/ws/{session_id}"]
        self.assertEqual(ws_ep["ttfa_p50_ms"], 650.0)
        self.assertEqual(ws_ep["audio_seconds_sent"], 10.0)

        md = render_markdown_report(summary)
        self.assertIn("EVA Ecosystem Stress Test Report", md)
        self.assertIn("GET /conversations", md)
        self.assertIn("WS /call/ws/{session_id}", md)

        with tempfile.TemporaryDirectory() as tmp:
            json_path, md_path = write_reports(summary, tmp)
            self.assertTrue(json_path.exists())
            self.assertTrue(md_path.exists())

    def test_missing_runtime_dependencies_fails_fast(self) -> None:
        cfg = StressConfig(target_url="http://127.0.0.1:8888", scenario="ai", users=2)
        with patch("tests.load_test.run_stress_test.importlib.util.find_spec", return_value=None):
            with self.assertRaises(SystemExit) as ctx:
                run_multi_instance(cfg)
            self.assertIn("Missing required Python packages", str(ctx.exception))


class AudioUtilsTests(unittest.TestCase):
    def test_downmix_resample_and_dynamic_duration(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            wav_path = Path(tmp) / "1.wav"
            # Generate 1 second of 48kHz stereo 16-bit PCM
            samples = array.array("h", [1000, -1000] * 48000)
            with wave.open(str(wav_path), "wb") as wf:
                wf.setnchannels(2)
                wf.setsampwidth(2)
                wf.setframerate(48000)
                wf.writeframes(samples.tobytes())

            pcm16k = load_wav_as_pcm16k(wav_path)
            self.assertEqual(len(pcm16k), TARGET_SAMPLE_RATE * 2)

            pool = load_pcm_pool(tmp)
            self.assertEqual(len(pool), TARGET_SAMPLE_RATE * 2)

            sliced = build_pcm_for_duration(pool, 0.5)
            self.assertEqual(len(sliced), int(TARGET_SAMPLE_RATE * 0.5) * 2)

            looped = build_pcm_for_duration(pool, 2.5)
            self.assertEqual(len(looped), int(TARGET_SAMPLE_RATE * 2.5) * 2)

            chunks = list(iter_pcm_chunks(sliced, chunk_ms=100))
            self.assertEqual(len(chunks), 5)
            self.assertEqual(len(chunks[0]), 3200)


if __name__ == "__main__":
    unittest.main()
