from __future__ import annotations

import logging
from typing import Any

from ai.services.dass_extraction_service import DASSExtractionService
from app.schemas.call import (
    CallSynthesizeRequest,
    CallSynthesizeResponse,
    DASSAssessmentPayloadDto,
    DASSItemDto,
    EmotionBreakdownDto,
    JournalDeltaDto,
    MemoryCandidateDto,
)
from app.services.dass import DASSService
from app.services.diary import DiaryGeneratorService
from app.services.emotion import MLEmotionDetectorService
from packages.ai.interfaces.llm import LLMMessage

logger = logging.getLogger(__name__)

# Canonical 7 UI emotion buckets matching Flutter DiaryEmotionDistributionCard & StackedEmotionChartPainter
_UI_EMOTION_META: dict[str, dict[str, str]] = {
    "happy": {"label": "Bahagia & Lega", "emoji": "😃", "color": "#FFE6A7"},
    "netral": {"label": "Netral & Tenang", "emoji": "😌", "color": "#4ECDC4"},
    "fear": {"label": "Cemas & Takut", "emoji": "😰", "color": "#6C63FF"},
    "sadness": {"label": "Sedih", "emoji": "😢", "color": "#74B9FF"},
    "surprise": {"label": "Terkejut", "emoji": "😲", "color": "#A29BFE"},
    "anger": {"label": "Marah", "emoji": "😡", "color": "#FF7675"},
    "disgusted": {"label": "Jijik / Muak", "emoji": "🤢", "color": "#55EFC4"},
}

_SOURCE_TO_UI_KEY: dict[str, str] = {
    "happy": "happy",
    "neutral": "netral",
    "netral": "netral",
    "other": "netral",
    "unknown": "netral",
    "fearful": "fear",
    "fear": "fear",
    "sad": "sadness",
    "sadness": "sadness",
    "surprised": "surprise",
    "surprise": "surprise",
    "angry": "anger",
    "anger": "anger",
    "disgusted": "disgusted",
    "disgust": "disgusted",
}


def scores_to_ui_breakdown(scores: dict[str, float]) -> list[dict[str, Any]]:
    """Map raw 9-class emotion2vec or text heuristic score dictionary to normalized 7 UI emotion items."""
    if not scores:
        return []

    buckets: dict[str, float] = {k: 0.0 for k in _UI_EMOTION_META}
    for raw_key, val in scores.items():
        ui_key = _SOURCE_TO_UI_KEY.get(str(raw_key).strip().lower())
        if ui_key and isinstance(val, (int, float)) and val > 0:
            buckets[ui_key] += float(val)

    total = sum(buckets.values())
    if total <= 0:
        return []

    breakdown: list[dict[str, Any]] = []
    for key, val in buckets.items():
        pct = round(val / total, 4)
        if pct >= 0.01:
            meta = _UI_EMOTION_META[key]
            breakdown.append({
                "name": key,
                "label": meta["label"],
                "emoji": meta["emoji"],
                "percent": pct,
                "color": meta["color"],
            })

    breakdown.sort(key=lambda item: item["percent"], reverse=True)
    return breakdown


def aggregate_turn_scores(turn_scores_list: list[dict[str, float]]) -> list[dict[str, Any]]:
    """Average multiple per-turn emotion score maps into a single normalized 7 UI emotion breakdown."""
    valid = [s for s in turn_scores_list if s]
    if not valid:
        return []

    merged: dict[str, float] = {}
    for score_map in valid:
        for k, v in score_map.items():
            if isinstance(v, (int, float)):
                merged[k] = merged.get(k, 0.0) + float(v)

    averaged = {k: v / len(valid) for k, v in merged.items()}
    return scores_to_ui_breakdown(averaged)


def _normalize_breakdown_items(raw_items: list[Any]) -> list[EmotionBreakdownDto]:
    """Ensure LLM or computed breakdown items conform strictly to EmotionBreakdownDto."""
    if not raw_items:
        return []

    normalized: list[EmotionBreakdownDto] = []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        raw_name = str(item.get("name") or "").strip().lower()
        ui_key = _SOURCE_TO_UI_KEY.get(raw_name, raw_name if raw_name in _UI_EMOTION_META else "netral")
        meta = _UI_EMOTION_META[ui_key]
        pct = float(item.get("percent") or 0.0)
        if pct <= 0.0:
            continue
        normalized.append(
            EmotionBreakdownDto(
                name=ui_key,
                label=str(item.get("label") or meta["label"]),
                emoji=str(item.get("emoji") or meta["emoji"]),
                percent=round(min(1.0, max(0.0, pct)), 4),
                color=str(item.get("color") or meta["color"]),
            )
        )

    total = sum(e.percent for e in normalized)
    if total > 0:
        normalized = [
            e.model_copy(update={"percent": round(e.percent / total, 4)})
            for e in normalized
        ]
    normalized.sort(key=lambda e: e.percent, reverse=True)
    return normalized


class CallSynthesisService:
    """Stateless AI synthesis orchestrator for local-first mobile clients (zero DB persistence)."""

    async def synthesize_session(
        self,
        *,
        session_id: str,
        turns: list[LLMMessage],
        aggregated_emotions: list[dict[str, Any]] | None = None,
        include_dass: bool = True,
        include_memory_candidates: bool = True,
    ) -> CallSynthesizeResponse:
        dialogue = [
            m for m in turns if m.role in ("user", "assistant") and m.content and m.content.strip()
        ]
        user_turns = [m for m in dialogue if m.role == "user"]

        resolved_emotions = aggregated_emotions
        if not resolved_emotions and user_turns:
            per_turn_scores: list[dict[str, float]] = []
            for m in user_turns:
                pred = MLEmotionDetectorService._predict_from_text(m.content)
                bd = pred.get("emotions_breakdown") or []
                per_turn_scores.append({str(it["name"]): float(it["percent"]) for it in bd if "name" in it})
            resolved_emotions = aggregate_turn_scores(per_turn_scores)

        artifacts = await DiaryGeneratorService.synthesize_session_artifacts(
            dialogue,
            aggregated_emotions=resolved_emotions,
        )

        raw_delta = artifacts.get("journal_delta") or {}
        breakdown_dtos = _normalize_breakdown_items(raw_delta.get("emotions_breakdown") or [])

        # Derive dominant mood_tag / emoji consistently from aggregated emotions if delta kept generic default
        mood_tag = str(raw_delta.get("mood_tag") or "Netral & Tenang 😌")
        mood_emoji = str(raw_delta.get("mood_emoji") or "😌")
        if breakdown_dtos and mood_tag == "Netral & Tenang 😌" and breakdown_dtos[0].name != "netral":
            top = breakdown_dtos[0]
            if top.percent >= 0.35:
                mood_tag = f"{top.label} {top.emoji}"
                mood_emoji = top.emoji

        journal_delta = JournalDeltaDto(
            title=str(raw_delta.get("title") or "Refleksi Sesi Suara EVA"),
            summary=str(raw_delta.get("summary") or artifacts.get("session_summary") or ""),
            content=str(raw_delta.get("content") or artifacts.get("session_summary") or ""),
            mood_tag=mood_tag,
            mood_emoji=mood_emoji,
            emotional_level=int(raw_delta.get("emotional_level") or 3),
            ai_insight=str(raw_delta.get("ai_insight") or ""),
            emotional_reflection=str(raw_delta.get("emotional_reflection") or ""),
            important_events=[str(ev) for ev in (raw_delta.get("important_events") or [])],
            emotions_breakdown=breakdown_dtos,
        )

        dass_payload: DASSAssessmentPayloadDto | None = None
        if include_dass and user_turns:
            transcript_text = "\n".join(f"{m.role.upper()}: {m.content}" for m in dialogue)
            extractor = DASSExtractionService()
            extracted_items = await extractor.extract_from_transcript(transcript_text)
            scores = DASSService.calculate_scores(extracted_items)
            dass_payload = DASSAssessmentPayloadDto(
                stress_score=int(scores["stress_score"]),
                anxiety_score=int(scores["anxiety_score"]),
                depression_score=int(scores["depression_score"]),
                stress_category=str(scores["stress_severity"]),
                anxiety_category=str(scores["anxiety_severity"]),
                depression_category=str(scores["depression_severity"]),
                stress_severity=str(scores["stress_severity"]),
                anxiety_severity=str(scores["anxiety_severity"]),
                depression_severity=str(scores["depression_severity"]),
                items=[DASSItemDto(**it) for it in extracted_items],
            )

        candidates: list[MemoryCandidateDto] = []
        if include_memory_candidates:
            for cand in artifacts.get("memory_candidates") or []:
                if isinstance(cand, dict):
                    candidates.append(MemoryCandidateDto(**cand))

        return CallSynthesizeResponse(
            session_id=session_id,
            session_summary=str(artifacts.get("session_summary") or journal_delta.summary),
            journal_delta=journal_delta,
            dass_assessment=dass_payload,
            memory_candidates=candidates,
            metadata={
                "stateless": True,
                "turn_count": len(dialogue),
                "user_turn_count": len(user_turns),
            },
        )

    async def synthesize_from_request(self, payload: CallSynthesizeRequest) -> CallSynthesizeResponse:
        """Convert REST CallSynthesizeRequest turns into LLMMessage list and run stateless synthesis."""
        turns = [
            LLMMessage(role=t.role, content=t.text)
            for t in payload.turns
            if t.text and t.text.strip()
        ]
        return await self.synthesize_session(
            session_id=payload.session_id,
            turns=turns,
            include_dass=payload.include_dass,
            include_memory_candidates=payload.include_memory_candidates,
        )
