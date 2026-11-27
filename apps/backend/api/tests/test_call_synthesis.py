import json
from unittest.mock import AsyncMock, MagicMock, patch
import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.api.dependencies import get_current_user
from app.main import app
from app.models.user import User
from app.schemas.call import CallSynthesizeRequest, SynthesizeTurnInput
from app.services.call.session_manager import CallSession, CallSessionManager
from app.services.call.synthesis_service import (
    CallSynthesisService,
    aggregate_turn_scores,
    scores_to_ui_breakdown,
)
from packages.ai.interfaces.llm import LLMMessage


class _FakeWebSocket:
    def __init__(self) -> None:
        self.sent: list[dict] = []

    async def send_json(self, data: dict) -> None:
        self.sent.append(data)


@pytest.mark.asyncio
async def test_scores_to_ui_breakdown_maps_and_normalizes():
    scores = {
        "happy": 0.6,
        "neutral": 0.3,
        "fearful": 0.1,
    }
    breakdown = scores_to_ui_breakdown(scores)
    assert len(breakdown) == 3
    assert breakdown[0]["name"] == "happy"
    assert breakdown[0]["percent"] == pytest.approx(0.6, abs=0.01)
    assert sum(item["percent"] for item in breakdown) == pytest.approx(1.0, abs=0.02)

    agg = aggregate_turn_scores([scores, {"happy": 0.2, "neutral": 0.8}])
    assert agg[0]["name"] == "netral"


@pytest.mark.asyncio
async def test_call_synthesis_service_stateless_returns_artifacts():
    fake_artifacts = {
        "session_summary": "Pengguna membahas rasa cemas menjelang presentasi dan merasa lebih tenang setelah berdialog.",
        "journal_delta": {
            "title": "Mengelola Kecemasan Sebelum Presentasi",
            "summary": "Sesi membahas kecemasan presentasi dan latihan pernapasan.",
            "content": "Refleksi mendalam terkait ketegangan menjelang presentasi.",
            "mood_tag": "Cemas & Takut 😰",
            "mood_emoji": "😰",
            "emotional_level": 3,
            "ai_insight": "Kesadaran terhadap pemicu stres membantu mengelola kecemasan lebih dini.",
            "emotional_reflection": "Mengambil jeda napas sebelum tampil membantu menenangkan tubuh.",
            "important_events": ["Persiapan presentasi kerja"],
            "emotions_breakdown": [
                {"name": "fear", "label": "Cemas & Takut", "emoji": "😰", "percent": 0.65, "color": "#6C63FF"},
                {"name": "netral", "label": "Netral & Tenang", "emoji": "😌", "percent": 0.35, "color": "#4ECDC4"},
            ],
        },
        "memory_candidates": [
            {
                "candidate_id": "cand-1",
                "category": "emotional_trigger",
                "fact_text": "Merasa cemas sebelum presentasi di depan tim",
                "source_type": "user_reported",
                "source_excerpt": "Aku takut banget mau presentasi besok",
                "source_verification": "unverified",
                "should_require_confirmation": True,
            }
        ],
    }

    fake_dass_items = [
        {
            "item_id": i,
            "scale": "anxiety" if i % 3 == 2 else ("depression" if i % 3 == 0 else "stress"),
            "question_text": f"Item {i}",
            "score": 1 if i == 2 else 0,
            "evidence": "Aku takut banget" if i == 2 else None,
            "reason": "Indikasi cemas" if i == 2 else None,
            "confidence": 0.8 if i == 2 else 0.0,
            "is_user_edited": False,
        }
        for i in range(1, 22)
    ]

    with (
        patch(
            "app.services.call.synthesis_service.DiaryGeneratorService.synthesize_session_artifacts",
            new=AsyncMock(return_value=fake_artifacts),
        ),
        patch(
            "app.services.call.synthesis_service.DASSExtractionService.extract_from_transcript",
            new=AsyncMock(return_value=fake_dass_items),
        ),
    ):
        svc = CallSynthesisService()
        req = CallSynthesizeRequest(
            session_id="call_test_1",
            turns=[
                SynthesizeTurnInput(role="user", text="Aku cemas banget mau presentasi besok.", turn_id=1),
                SynthesizeTurnInput(role="assistant", text="Wajar merasa tegang. Bagian mana yang paling membuatmu khawatir?", turn_id=1),
            ],
            include_dass=True,
            include_memory_candidates=True,
        )
        res = await svc.synthesize_from_request(req)

    assert res.session_id == "call_test_1"
    assert "presentasi" in res.session_summary.lower()
    assert res.journal_delta.title == "Mengelola Kecemasan Sebelum Presentasi"
    assert len(res.journal_delta.emotions_breakdown) >= 2
    assert res.dass_assessment is not None
    assert res.dass_assessment.anxiety_score == 2
    assert res.dass_assessment.anxiety_category == "Normal"
    assert len(res.memory_candidates) == 1
    assert res.memory_candidates[0].should_require_confirmation is True


@pytest.mark.asyncio
async def test_session_manager_ws_v1_context_and_finalize():
    ws = _FakeWebSocket()
    manager = CallSessionManager.__new__(CallSessionManager)
    manager._active_sessions = {}
    manager.orchestrator = MagicMock()
    manager.synthesis_service = MagicMock()
    manager.emotion_coordinator = MagicMock()
    manager.stt_coordinator = MagicMock()
    manager.stt_coordinator.pause_session = AsyncMock()

    session = CallSession(
        session_id="sess_ws_1",
        websocket=ws,  # type: ignore[arg-type]
        privacy_mode="local_private",
    )
    session.conversation_history.extend([
        LLMMessage(role="user", content="Halo Eva, hari ini aku lega banget."),
        LLMMessage(role="assistant", content="Syukur mendengarnya! Apa yang membuatmu lega hari ini?"),
    ])
    session.turn_score_history.append({"happy": 0.7, "neutral": 0.3})

    await manager.handle_event(
        session,
        {
            "type": "client_context_v1",
            "context_request_id": "ctx_1",
            "items": [
                {"id": "m1", "category": "coping_strategy", "text": "Jalan pagi menenangkan pikiran"},
                {"id": "m2", "category": "invalid_cat", "text": "Should reject"},
            ],
        },
    )
    assert len(session.structured_persisted_context) == 1
    assert ws.sent[-1]["type"] == "context_ack_v1"
    assert ws.sent[-1]["accepted_count"] == 1
    assert ws.sent[-1]["rejected_count"] == 1

    with (
        patch(
            "app.services.call.synthesis_service.DiaryGeneratorService.synthesize_session_artifacts",
            new=AsyncMock(
                return_value={
                    "session_summary": "Pengguna berbagi rasa lega hari ini.",
                    "journal_delta": {
                        "title": "Rasa Lega Hari Ini",
                        "summary": "Pengguna merasa lega.",
                        "content": "Sesi positif.",
                        "mood_tag": "Bahagia & Lega 😃",
                        "mood_emoji": "😃",
                        "emotional_level": 4,
                        "ai_insight": "Suasana hati positif.",
                        "emotional_reflection": "Pertahankan rutinitas baik.",
                        "important_events": ["Berbagi kabar baik"],
                        "emotions_breakdown": [
                            {"name": "happy", "label": "Bahagia & Lega", "emoji": "😃", "percent": 0.7, "color": "#FFE6A7"},
                            {"name": "netral", "label": "Netral & Tenang", "emoji": "😌", "percent": 0.3, "color": "#4ECDC4"},
                        ],
                    },
                    "memory_candidates": [],
                }
            ),
        ),
        patch(
            "app.services.call.synthesis_service.DASSExtractionService.extract_from_transcript",
            new=AsyncMock(return_value=[]),
        ),
    ):
        manager.synthesis_service = CallSynthesisService()
        await manager.handle_event(
            session,
            {
                "type": "session_finalize_v1",
                "request_id": "fin_1",
                "duration_seconds": 45,
                "request_memory_candidates": True,
            },
        )

    artifacts_evt = ws.sent[-1]
    assert artifacts_evt["type"] == "session_artifacts_v1"
    assert artifacts_evt["request_id"] == "fin_1"
    assert artifacts_evt["session_summary"] == "Pengguna berbagi rasa lega hari ini."
    assert artifacts_evt["journal_delta"]["emotions_breakdown"][0]["name"] == "happy"

    await manager.handle_event(
        session,
        {"type": "session_artifacts_ack_v1", "request_id": "fin_1", "status": "committed_locally"},
    )
    assert ws.sent[-1]["type"] == "session_finalized_v1"
    assert ws.sent[-1]["status"] == "closed"


@pytest.mark.asyncio
async def test_post_call_synthesize_endpoint_contract():
    fake_user = User(id=uuid.uuid4(), email="test@eva.local", username="tester", password_hash="x")
    app.dependency_overrides[get_current_user] = lambda: fake_user
    try:
        with (
            patch(
                "app.services.call.synthesis_service.DiaryGeneratorService.synthesize_session_artifacts",
                new=AsyncMock(
                    return_value={
                        "session_summary": "Ringkasan sesi uji endpoint.",
                        "journal_delta": {
                            "title": "Judul Sesi Uji",
                            "summary": "Ringkasan.",
                            "content": "Konten.",
                            "mood_tag": "Netral & Tenang 😌",
                            "mood_emoji": "😌",
                            "emotional_level": 3,
                            "ai_insight": "Wawasan.",
                            "emotional_reflection": "Refleksi.",
                            "important_events": ["Uji endpoint"],
                            "emotions_breakdown": [
                                {"name": "netral", "label": "Netral & Tenang", "emoji": "😌", "percent": 1.0, "color": "#4ECDC4"}
                            ],
                        },
                        "memory_candidates": [],
                    }
                ),
            ),
            patch(
                "app.services.call.synthesis_service.DASSExtractionService.extract_from_transcript",
                new=AsyncMock(return_value=[]),
            ),
        ):
            async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
                resp = await client.post(
                    "/api/v1/call/synthesize",
                    json={
                        "session_id": "call_rest_1",
                        "turns": [{"role": "user", "text": "Halo selamat pagi", "turn_id": 1}],
                        "include_dass": True,
                        "include_memory_candidates": True,
                    },
                )
        assert resp.status_code == 200
        body = resp.json()
        assert body["session_id"] == "call_rest_1"
        assert body["session_summary"] == "Ringkasan sesi uji endpoint."
        assert body["journal_delta"]["title"] == "Judul Sesi Uji"
        assert body["journal_delta"]["emotions_breakdown"][0]["name"] == "netral"
    finally:
        app.dependency_overrides.clear()
