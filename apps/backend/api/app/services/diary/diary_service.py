from datetime import date
import logging
from typing import Any
import uuid

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.tz import get_wib_day_range_utc, get_wib_today, to_wib
from app.models.conversation import Conversation
from app.models.diary import DiaryEntry
from app.schemas.diary import (
    CreateDiaryRequest,
    DeleteDiaryResponse,
    DiaryEntryResponse,
    DiaryRiskWarning,
    DiarySessionItem,
    EmotionBreakdownItem,
    TranscriptItem,
)
from app.services.diary.diary_generator import DiaryGeneratorService

logger = logging.getLogger(__name__)


class DiaryService:
    """Service handling diary CRUD, emotion analysis breakdown, and session transcript aggregation."""

    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def _analyze_message_emotion(text: str, is_user: bool) -> tuple[str, str]:
        """Dynamically determine emotion tag and emoji from individual message content."""
        if not is_user:
            return "empathy", "💙"

        t_low = text.lower()
        anx_words = ["cemas", "takut", "nervous", "panggung", "khawatir", "panik", "deg-degan", "gugup", "takutnya", "bingung"]
        dep_words = ["sedih", "nangis", "menangis", "hampa", "sendiri", "kehilangan", "terpuruk", "putus asa", "kecewa", "patah hati", "bunuh diri"]
        str_words = ["stres", "capek", "lelah", "beban", "berat", "penat", "pusing", "mumet", "tekanan", "tugas", "deadline", "kerjaan"]
        ang_words = ["marah", "kesal", "jengkel", "benci", "emosi", "sebal", "kesel"]
        pos_words = ["lega", "senang", "bahagia", "terima kasih", "makasih", "enakan", "tenang", "nyaman", "santai", "alhamdulillah", "syukurlah", "baik"]

        if any(w in t_low for w in anx_words):
            return "fear (78%)", "😨"
        if any(w in t_low for w in dep_words):
            return "sadness (82%)", "😔"
        if any(w in t_low for w in str_words):
            return "stress (75%)", "💥"
        if any(w in t_low for w in ang_words):
            return "anger (70%)", "😡"
        if any(w in t_low for w in pos_words):
            return "calm (85%)", "😌"

        return "netral (60%)", "😐"

    @staticmethod
    def _calculate_session_emotions(
        transcripts: list[TranscriptItem],
        session_title: str,
        default_breakdown: list[EmotionBreakdownItem],
    ) -> list[EmotionBreakdownItem]:
        combined_text = (session_title + " " + " ".join(t.text for t in transcripts if t.isUser)).lower()

        anx_keywords = ["cemas", "takut", "nervous", "panggung", "khawatir", "panik", "deg-degan", "gugup"]
        dep_keywords = ["bunuh diri", "depresi", "sedih", "sendiri", "kehilangan", "hampa", "nangis", "menangis", "terpuruk"]
        str_keywords = ["stres", "capek", "lelah", "beban", "berat", "penat", "tugas", "kerja"]
        pos_keywords = ["lega", "senang", "terima kasih", "enakan", "tenang", "nyaman", "tidur", "santai", "baik"]

        anx_count = sum(1 for kw in anx_keywords if kw in combined_text)
        dep_count = sum(1 for kw in dep_keywords if kw in combined_text)
        str_count = sum(1 for kw in str_keywords if kw in combined_text)
        pos_count = sum(1 for kw in pos_keywords if kw in combined_text)

        if anx_count == 0 and dep_count == 0 and str_count == 0 and pos_count == 0:
            return default_breakdown

        raw = [
            {"name": "fear", "label": "Takut / Gelisah", "emoji": "😨", "percent": max(0.04, anx_count * 0.25), "color": "#6C63FF"},
            {"name": "sadness", "label": "Sedih / Haru", "emoji": "😔", "percent": max(0.04, dep_count * 0.25), "color": "#8B93FF"},
            {"name": "netral", "label": "Netral", "emoji": "😐", "percent": 0.08, "color": "#A7E6FF"},
            {"name": "stress", "label": "Stres / Tertekan", "emoji": "💥", "percent": max(0.04, str_count * 0.20), "color": "#FF8A80"},
            {"name": "happy", "label": "Bahagia", "emoji": "😃", "percent": max(0.03, pos_count * 0.15), "color": "#FFE6A7"},
            {"name": "surprise", "label": "Terkejut", "emoji": "😲", "percent": 0.02, "color": "#C3B8FF"},
            {"name": "anger", "label": "Marah", "emoji": "😡", "percent": 0.01, "color": "#FFB6C1"},
        ]
        tot = sum(item["percent"] for item in raw)
        return [
            EmotionBreakdownItem(
                name=item["name"],
                label=item["label"],
                emoji=item["emoji"],
                percent=round(item["percent"] / tot, 2),
                color=item["color"],
            )
            for item in raw
        ]

    @classmethod
    def format_diary_entry(cls, d: DiaryEntry | None) -> DiaryEntryResponse:
        """Format a DiaryEntry SQLAlchemy model into a structured DiaryEntryResponse DTO."""
        if not d:
            return DiaryEntryResponse()

        raw_events = d.important_events if isinstance(d.important_events, list) else []
        events = raw_events if raw_events else ["Sesi refleksi harian tercatat dalam sistem LUNA."]

        scores = d.mental_health_scores or {}
        dep = float(scores.get("depression", 0.25))
        anx = float(scores.get("anxiety", 0.45))
        strs = float(scores.get("stress", 0.15))

        raw_breakdown = [
            {"name": "fear", "label": "Takut / Gelisah", "emoji": "😨", "percent": max(0.05, anx), "color": "#6C63FF"},
            {"name": "sadness", "label": "Sedih / Haru", "emoji": "😔", "percent": max(0.05, dep), "color": "#8B93FF"},
            {"name": "netral", "label": "Netral", "emoji": "😐", "percent": 0.15, "color": "#A7E6FF"},
            {"name": "stress", "label": "Stres / Tertekan", "emoji": "💥", "percent": max(0.05, strs), "color": "#FF8A80"},
            {"name": "happy", "label": "Bahagia", "emoji": "😃", "percent": 0.10, "color": "#FFE6A7"},
            {"name": "surprise", "label": "Terkejut", "emoji": "😲", "percent": 0.03, "color": "#C3B8FF"},
            {"name": "anger", "label": "Marah", "emoji": "😡", "percent": 0.02, "color": "#FFB6C1"},
        ]
        tot = sum(item["percent"] for item in raw_breakdown)
        emotions_breakdown = [
            EmotionBreakdownItem(
                name=item["name"],
                label=item["label"],
                emoji=item["emoji"],
                percent=round(item["percent"] / tot, 2),
                color=item["color"],
            )
            for item in raw_breakdown
        ]

        mood_tag = d.mood_tag or "Netral"
        has_risk = any(kw in mood_tag for kw in ("Darurat", "Stres", "Cemas", "Sedih"))
        risk_warning = (
            DiaryRiskWarning(
                detected=True,
                type="High Risk / Krisis",
                title="PERINGATAN KRISIS EMOSIONAL",
                level="RISIKO TINGGI",
                message="Sistem LUNA mendeteksi akumulasi indikasi krisis emosional tinggi dan stres berat pada percakapan hari ini. Protokol keselamatan aktif untuk rujukan darurat 119 ext 8.",
            )
            if has_risk
            else None
        )

        return DiaryEntryResponse(
            id=str(d.id),
            title=d.title or "Refleksi Harian LUNA",
            date=d.entry_date.strftime("%d %B %Y") if isinstance(d.entry_date, date) else str(d.entry_date),
            sessionCount=0,
            lastSessionTime="-",
            moodTag=mood_tag,
            moodEmoji=d.mood_emoji or "😌",
            summary=d.summary or "Catatan harian perkembangan emosional bersama LUNA.",
            riskWarning=risk_warning,
            aiInsight=d.ai_insight or "Analisis AI menunjukkan kondisi stabil.",
            importantEvents=events,
            emotionalReflection=d.emotional_reflection or "Merasa tenang setelah refleksi.",
            mentalHealthScores=scores,
            emotionsBreakdown=emotions_breakdown,
            sessions=[],
        )

    async def _attach_sessions(
        self, formatted: DiaryEntryResponse, entry: DiaryEntry
    ) -> DiaryEntryResponse:
        """Attach real conversation transcripts and breakdown for the diary's date."""
        if not isinstance(entry.entry_date, date):
            return formatted

        start_utc, end_utc = get_wib_day_range_utc(entry.entry_date)
        conv_query = (
            select(Conversation)
            .options(selectinload(Conversation.messages))
            .where(
                Conversation.user_id == entry.user_id,
                Conversation.started_at >= start_utc,
                Conversation.started_at <= end_utc,
            )
            .order_by(Conversation.started_at.asc())
        )
        conv_res = await self.db.execute(conv_query)
        convs = conv_res.scalars().all()

        sessions_data: list[DiarySessionItem] = []
        for c in convs:
            sorted_msgs = sorted(c.messages, key=lambda m: m.sequence_number) if c.messages else []
            sess_transcripts: list[TranscriptItem] = []
            for m in sorted_msgs:
                if m.role in ("user", "assistant") and m.content:
                    msg_t = to_wib(m.created_at)
                    emo_tag, emo_emoji = self._analyze_message_emotion(m.content, m.role == "user")
                    sess_transcripts.append(
                        TranscriptItem(
                            isUser=m.role == "user",
                            time=msg_t.strftime("%H:%M") if msg_t else "09:00",
                            text=m.content,
                            emotionTag=emo_tag,
                            emotionEmoji=emo_emoji,
                        )
                    )

            if not sess_transcripts:
                continue

            c_t = to_wib(c.started_at)
            time_str = c_t.strftime("%H:%M") if c_t else "09:00"
            title = (c.title or "").replace("$skeleton", "").strip()
            if not title:
                title = f"Sesi #{len(sessions_data) + 1} Percakapan Suara"

            sess_emotions = self._calculate_session_emotions(
                sess_transcripts,
                title,
                formatted.emotionsBreakdown,
            )

            sessions_data.append(
                DiarySessionItem(
                    id=str(c.id),
                    title=title,
                    time=time_str,
                    moodTag=entry.mood_tag or "Netral",
                    moodEmoji=entry.mood_emoji or "😌",
                    emotionsBreakdown=sess_emotions,
                    transcripts=sess_transcripts,
                )
            )

        formatted.sessions = sessions_data
        formatted.sessionCount = len(sessions_data)
        formatted.lastSessionTime = sessions_data[-1].time if sessions_data else "-"
        return formatted

    async def get_diaries(
        self, user_id: uuid.UUID, mood: str | None = None, search: str | None = None
    ) -> list[DiaryEntryResponse]:
        """Fetch all diary entries for a user, optionally filtered by mood tag or search term."""
        query = select(DiaryEntry).where(DiaryEntry.user_id == user_id).order_by(DiaryEntry.entry_date.desc())
        res = await self.db.execute(query)
        entries = res.scalars().all()

        formatted_list: list[DiaryEntryResponse] = []
        for e in entries:
            if e is not None:
                f = self.format_diary_entry(e)
                f = await self._attach_sessions(f, e)
                formatted_list.append(f)

        if mood and mood != "Semua":
            clean_mood = mood.lower()
            formatted_list = [f for f in formatted_list if clean_mood in (f.moodTag or "").lower()]

        if search:
            clean_q = search.lower()
            formatted_list = [
                f for f in formatted_list
                if clean_q in (f.title or "").lower() or clean_q in (f.summary or "").lower()
            ]

        return formatted_list

    async def get_today_diary(self, user_id: uuid.UUID) -> DiaryEntryResponse:
        """Fetch today's diary entry, generating a new one via LLM if not yet present."""
        today = get_wib_today()
        query = select(DiaryEntry).where(DiaryEntry.user_id == user_id, DiaryEntry.entry_date == today)
        res = await self.db.execute(query)
        entry = res.scalar_one_or_none()

        if not entry:
            entry = await DiaryGeneratorService.generate_today_diary(user_id, self.db)

        if not entry:
            return DiaryEntryResponse(id=None, message="Belum ada jurnal untuk hari ini.")

        formatted = self.format_diary_entry(entry)
        return await self._attach_sessions(formatted, entry)

    async def get_diary_by_id(self, user_id: uuid.UUID, diary_id: str) -> DiaryEntryResponse:
        """Fetch single diary entry by ID verifying user ownership."""
        try:
            d_uuid = uuid.UUID(diary_id)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid diary ID")

        query = select(DiaryEntry).where(
            DiaryEntry.id == d_uuid,
            DiaryEntry.user_id == user_id,
        )
        res = await self.db.execute(query)
        entry = res.scalar_one_or_none()

        if not entry:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Diary entry not found")

        formatted = self.format_diary_entry(entry)
        return await self._attach_sessions(formatted, entry)

    async def generate_today_diary(self, user_id: uuid.UUID) -> DiaryEntryResponse:
        """Force manual generation or re-synthesis of today's diary."""
        entry = await DiaryGeneratorService.generate_today_diary(user_id, self.db)
        return self.format_diary_entry(entry)

    async def create_diary(self, user_id: uuid.UUID, payload: CreateDiaryRequest) -> DiaryEntryResponse:
        """Create or append today's custom diary entry reflection."""
        today = get_wib_today()

        query = select(DiaryEntry).where(DiaryEntry.user_id == user_id, DiaryEntry.entry_date == today)
        res = await self.db.execute(query)
        entry = res.scalar_one_or_none()

        if entry:
            entry.summary += f"\n- {payload.content}"
            entry.content += f"\n- {payload.content}"
            if payload.mood_tag:
                entry.mood_tag = payload.mood_tag
        else:
            entry = DiaryEntry(
                user_id=user_id,
                entry_date=today,
                title="Refleksi Catatan Baru",
                summary=payload.content,
                content=payload.content,
                mood_tag=payload.mood_tag or "Netral",
                mood_emoji="😌",
                ai_insight="Catatan refleksi berhasil disimpan.",
                emotional_reflection="Merasa lega setelah menulis catatan.",
                important_events=[f"[Sesi #1] {payload.content[:50]}"],
            )
            self.db.add(entry)

        await self.db.commit()
        await self.db.refresh(entry)

        return self.format_diary_entry(entry)

    async def delete_diary(self, diary_id: str) -> DeleteDiaryResponse:
        """Delete a diary entry by ID."""
        try:
            d_uuid = uuid.UUID(diary_id)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid diary ID")

        query = select(DiaryEntry).where(DiaryEntry.id == d_uuid)
        res = await self.db.execute(query)
        entry = res.scalar_one_or_none()

        if not entry:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Diary entry not found")

        await self.db.delete(entry)
        await self.db.commit()
        return DeleteDiaryResponse()
