from collections import Counter
from datetime import datetime, timezone
import logging
import math
from typing import Any
import uuid

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.tz import get_wib_day_range_utc, get_wib_today, to_wib
from app.models.conversation import Conversation, ConversationSummary, Message
from app.models.diary import DiaryEntry
from app.models.enums import MessageType
from app.models.safety import EmotionAnalysis
from app.schemas.conversation import (
    ConversationAnalysis,
    ConversationDetailResponse,
    ConversationListResponse,
    ConversationPagination,
    EmotionBreakdownSimple,
    MessageItemResponse,
    SendMessageRequest,
    SentMessageResponse,
    TodayConversationItem,
    TodayConversationResponse,
    TodayMessageItem,
    TodayMessagesResponse,
    TranscriptItem,
)
from app.services.emotion import MLEmotionDetectorService

logger = logging.getLogger(__name__)


def format_time_local(dt: datetime | None) -> str:
    """Format datetime into 12-hour local time format (hh:mm AM/PM)."""
    if not dt:
        return "09:15 AM"
    try:
        dt_wib = to_wib(dt)
        return dt_wib.strftime("%I:%M %p") if dt_wib else "09:15 AM"
    except Exception:
        return dt.strftime("%I:%M %p")


def format_duration_str(started_at: datetime | None, last_message_at: datetime | None) -> str:
    """Calculate elapsed session duration and format as MM:SS."""
    if not started_at or not last_message_at:
        return "00:00"
    try:
        t1 = started_at if started_at.tzinfo else started_at.replace(tzinfo=timezone.utc)
        t2 = last_message_at if last_message_at.tzinfo else last_message_at.replace(tzinfo=timezone.utc)
        diff = int((t2 - t1).total_seconds())
        if diff < 0:
            diff = 0
        mins = diff // 60
        secs = diff % 60
        return f"{mins:02d}:{secs:02d}"
    except Exception:
        return "00:00"


def analyze_message_emotion_fallback(text: str) -> tuple[str, str]:
    """Determine emotion tag and emoji dynamically from message text keywords."""
    t_low = (text or "").lower()
    anx_words = ["cemas", "takut", "nervous", "panggung", "khawatir", "panik", "deg-degan", "gugup", "takutnya", "bingung", "was-was", "tegang"]
    dep_words = ["sedih", "nangis", "menangis", "hampa", "sendiri", "kehilangan", "terpuruk", "putus asa", "kecewa", "patah hati", "bunuh diri"]
    str_words = ["stres", "capek", "lelah", "beban", "berat", "penat", "pusing", "mumet", "tekanan", "tugas", "deadline", "kerjaan", "letih"]
    ang_words = ["marah", "kesal", "jengkel", "benci", "emosi", "sebal", "kesel", "geram", "murka"]
    pos_words = ["lega", "senang", "bahagia", "terima kasih", "makasih", "enakan", "tenang", "nyaman", "santai", "alhamdulillah", "syukurlah", "baik", "bersyukur"]

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


def get_message_emotion(
    m: Message, emotion_map: dict[uuid.UUID, EmotionAnalysis] | None = None
) -> tuple[str, str]:
    """Retrieve emotion tag and emoji for a message from ML emotion map or keyword heuristic."""
    if m.role not in ("user",):
        return "", ""

    if emotion_map and m.id in emotion_map:
        emo = emotion_map[m.id]
        if emo and emo.primary_emotion:
            pct = int((float(emo.confidence) if emo.confidence else 0.8) * 100)
            emo_lower = emo.primary_emotion.lower()
            name_map = {
                "fearful": "fear",
                "sad": "sadness",
                "angry": "anger",
                "neutral": "netral",
                "happy": "joy",
            }
            display_name = name_map.get(emo_lower, emo_lower)
            emoji_map = {
                "happy": "😃", "joy": "😃", "senang": "😃", "bahagia": "😃",
                "calm": "😌", "tenang": "😌", "lega": "😌",
                "fearful": "😨", "fear": "😨", "cemas": "😨", "takut": "😨",
                "sad": "😔", "sadness": "😔", "sedih": "😔",
                "angry": "😡", "anger": "😡", "marah": "😡",
                "stress": "💥", "stres": "💥",
                "neutral": "😐", "netral": "😐",
            }
            return f"{display_name} ({pct}%)", emoji_map.get(emo_lower, "🌱")

    return analyze_message_emotion_fallback(m.content)


def format_conversation(
    c: Conversation, emotion_map: dict[uuid.UUID, EmotionAnalysis] | None = None
) -> ConversationDetailResponse:
    """Format a conversation entity into a structured ConversationDetailResponse DTO."""
    msgs = sorted(c.messages, key=lambda m: m.sequence_number) if c.messages else []
    last_msg = msgs[-1].content if msgs else ""
    formatted_msgs = []
    user_emotions: list[tuple[str, str]] = []
    for m in msgs:
        emo_tag, emo_emoji = get_message_emotion(m, emotion_map)
        if m.role in ("user",) and emo_tag:
            user_emotions.append((emo_tag, emo_emoji))
        formatted_msgs.append(
            MessageItemResponse(
                id=str(m.id),
                sender="eva" if m.role in ("assistant", "luna", "eva") else "user",
                text=m.content,
                time=format_time_local(m.created_at),
                isAudio=m.message_type in (MessageType.VOICE, "voice", "audio"),
                emotionTag=emo_tag or None,
                emotionEmoji=emo_emoji or None,
            )
        )

    dominant_label = "Tenang & Nyaman"
    dominant_emoji = "😌"
    if user_emotions:
        counts: Counter[str] = Counter()
        emoji_by_name: dict[str, str] = {}
        for tag, emoji in user_emotions:
            name = tag.split()[0].lower() if tag else "netral"
            counts[name] += 1
            if emoji:
                emoji_by_name[name] = emoji

        most_common_name, _ = counts.most_common(1)[0]
        name_map = {
            "happy": "Lega & Senang",
            "joy": "Lega & Senang",
            "calm": "Tenang & Damai",
            "fear": "Cemas & Takut",
            "fearful": "Cemas & Takut",
            "anxiety": "Cemas & Gelisah",
            "sadness": "Sedih & Hampa",
            "sad": "Sedih & Hampa",
            "depression": "Sedih & Tertekan",
            "stress": "Stres & Lelah",
            "anger": "Marah & Kesal",
            "angry": "Marah & Kesal",
            "neutral": "Netral & Rileks",
            "netral": "Netral & Rileks",
        }
        dominant_label = name_map.get(most_common_name, most_common_name.capitalize())
        dominant_emoji = emoji_by_name.get(most_common_name, "😌")

    crisis_keywords = (
        "bunuh diri", "capek hidup", "mati saja", "ingin mati", "putus asa",
        "menyakiti diri", "gantung diri", "akhiri hidup", "tak sanggup lagi",
        "tidak sanggup hidup"
    )
    all_user_text = " ".join([m.content.lower() for m in msgs if m.role == "user" and m.content])
    if any(kw in all_user_text for kw in crisis_keywords):
        dominant_label = "Krisis / Sangat Tertekan"
        dominant_emoji = "🆘"

    end_time = c.last_message_at or (msgs[-1].created_at if msgs else c.started_at)
    duration_str = format_duration_str(c.started_at, end_time)

    summary_text = None
    if hasattr(c, "summaries") and c.summaries:
        summary_text = c.summaries[-1].summary

    return ConversationDetailResponse(
        id=str(c.id),
        title=c.title or "Sesi Percakapan",
        is_title_generating="$skeleton" in (c.title or ""),
        lastMessage=last_msg,
        lastMessageTime=format_time_local(c.started_at),
        duration=duration_str,
        dominant_emotion=dominant_label,
        dominant_emoji=dominant_emoji,
        summary=summary_text,
        messages=formatted_msgs,
    )


class ConversationService:
    """Service to handle conversation sessions, message pagination, emotion aggregation, and chat persistence."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_conversations(
        self, user_id: uuid.UUID, page: int = 1, limit: int = 10
    ) -> ConversationListResponse:
        """Retrieve paginated conversations for a user with messages and emotion mappings."""
        count_query = (
            select(func.count())
            .select_from(Conversation)
            .where(Conversation.user_id == user_id)
        )
        total_res = await self.db.execute(count_query)
        total_items = total_res.scalar() or 0

        offset = (page - 1) * limit
        query = (
            select(Conversation)
            .options(
                selectinload(Conversation.messages),
                selectinload(Conversation.summaries),
            )
            .where(Conversation.user_id == user_id)
            .order_by(Conversation.started_at.desc())
            .offset(offset)
            .limit(limit)
        )
        res = await self.db.execute(query)
        convs = res.scalars().all()

        message_ids = [m.id for c in convs for m in c.messages]
        emotion_map: dict[uuid.UUID, EmotionAnalysis] = {}
        if message_ids:
            emo_query = select(EmotionAnalysis).where(EmotionAnalysis.message_id.in_(message_ids))
            emo_res = await self.db.execute(emo_query)
            for emo in emo_res.scalars().all():
                emotion_map[emo.message_id] = emo

        formatted_items = [format_conversation(c, emotion_map) for c in convs]
        total_pages = max(1, math.ceil(total_items / limit)) if total_items > 0 else 1
        has_more = (offset + len(convs)) < total_items

        return ConversationListResponse(
            items=formatted_items,
            pagination=ConversationPagination(
                page=page,
                limit=limit,
                total_items=total_items,
                total_pages=total_pages,
                has_more=has_more,
            ),
            total=total_items,
            page=page,
            limit=limit,
            has_more=has_more,
        )

    async def get_today_conversations(
        self, user_id: uuid.UUID, page: int = 1, limit: int = 10
    ) -> TodayConversationResponse:
        """Retrieve today's voice call sessions with emotion breakdown and pagination."""
        today_wib = get_wib_today()
        start_utc, end_utc = get_wib_day_range_utc(today_wib)

        count_query = (
            select(func.count())
            .select_from(Conversation)
            .where(
                Conversation.user_id == user_id,
                Conversation.started_at >= start_utc,
                Conversation.started_at <= end_utc,
            )
        )
        total_res = await self.db.execute(count_query)
        total_items = total_res.scalar() or 0

        offset = (page - 1) * limit
        query = (
            select(Conversation)
            .options(selectinload(Conversation.messages))
            .where(
                Conversation.user_id == user_id,
                Conversation.started_at >= start_utc,
                Conversation.started_at <= end_utc,
            )
            .order_by(Conversation.started_at.desc())
            .offset(offset)
            .limit(limit)
        )
        res = await self.db.execute(query)
        convs = res.scalars().all()

        message_ids = [m.id for c in convs for m in c.messages]
        emotion_map: dict[uuid.UUID, EmotionAnalysis] = {}
        if message_ids:
            emo_query = select(EmotionAnalysis).where(EmotionAnalysis.message_id.in_(message_ids))
            emo_res = await self.db.execute(emo_query)
            for emo in emo_res.scalars().all():
                emotion_map[emo.message_id] = emo

        diary_query = select(DiaryEntry).where(DiaryEntry.user_id == user_id, DiaryEntry.entry_date == today_wib)
        res_diary = await self.db.execute(diary_query)
        today_diary = res_diary.scalar_one_or_none()

        mood_tag = today_diary.mood_tag if today_diary and today_diary.mood_tag else "Tenang & Nyaman 🌿"
        ai_insight = today_diary.ai_insight if today_diary and today_diary.ai_insight else "Pengguna merasa didengarkan dan tenang setelah berdialog bersama LUNA."

        items: list[TodayConversationItem] = []
        for c in convs:
            msgs = sorted(c.messages, key=lambda m: m.sequence_number) if c.messages else []
            if not msgs:
                continue

            time_formatted = format_time_local(c.started_at)
            c_emotions = [emotion_map[m.id].emotions for m in msgs if m.id in emotion_map and emotion_map[m.id].emotions]
            if c_emotions:
                raw_breakdown = MLEmotionDetectorService.aggregate_session_emotions(c_emotions)
                breakdown = [
                    EmotionBreakdownSimple(
                        label=b["label"],
                        emoji=b["emoji"],
                        percent=float(b["percent"]),
                        color=b["color"],
                    )
                    for b in raw_breakdown
                ]
            else:
                breakdown = [
                    EmotionBreakdownSimple(label="Ketenangan & Kedamaian", emoji="😌", percent=0.70, color="#4ECDC4"),
                    EmotionBreakdownSimple(label="Bahagia & Puas", emoji="😃", percent=0.20, color="#FFE6A7"),
                    EmotionBreakdownSimple(label="Tingkat Stres", emoji="😟", percent=0.10, color="#FF8B94"),
                ]

            analysis = ConversationAnalysis(
                dominant_emotion=mood_tag,
                calm_score="85%",
                stress_level="Rendah",
                empathy_level="Sangat Tinggi",
                ai_insight=ai_insight,
                emotions_breakdown=breakdown,
            )

            transcript_items: list[TranscriptItem] = []
            for m in msgs:
                emo_tag, emo_emoji = get_message_emotion(m, emotion_map)
                transcript_items.append(
                    TranscriptItem(
                        role=m.role,
                        content=m.content,
                        time=format_time_local(m.created_at),
                        emotionTag=emo_tag if m.role == "user" else None,
                        emotionEmoji=emo_emoji if m.role == "user" else None,
                    )
                )

            items.append(
                TodayConversationItem(
                    id=str(c.id),
                    title=c.title or "Sesi Panggilan Suara LUNA",
                    is_title_generating="$skeleton" in (c.title or ""),
                    date=f"Hari ini, {time_formatted}",
                    duration=format_duration_str(c.started_at, c.last_message_at),
                    moodTag=mood_tag,
                    emotion_analysis=analysis,
                    transcript=transcript_items,
                )
            )

        return TodayConversationResponse(
            items=items,
            total=total_items,
            page=page,
            limit=limit,
            has_more=(offset + len(items)) < total_items,
        )

    async def get_today_messages(
        self, user_id: uuid.UUID, page: int = 1, limit: int = 10
    ) -> TodayMessagesResponse:
        """Retrieve all messages from today's conversations ordered chronologically."""
        today_wib = get_wib_today()
        start_utc, end_utc = get_wib_day_range_utc(today_wib)

        conv_query = (
            select(Conversation)
            .options(selectinload(Conversation.messages))
            .where(
                Conversation.user_id == user_id,
                Conversation.started_at >= start_utc,
                Conversation.started_at <= end_utc,
            )
            .order_by(Conversation.started_at.asc())
        )
        conv_res = await self.db.execute(conv_query)
        convs = conv_res.scalars().all()

        message_ids = [m.id for c in convs for m in c.messages]
        emotion_map: dict[uuid.UUID, EmotionAnalysis] = {}
        if message_ids:
            emo_query = select(EmotionAnalysis).where(EmotionAnalysis.message_id.in_(message_ids))
            emo_res = await self.db.execute(emo_query)
            for emo in emo_res.scalars().all():
                emotion_map[emo.message_id] = emo

        all_msgs: list[TodayMessageItem] = []
        for c in convs:
            sorted_msgs = sorted(c.messages, key=lambda m: m.sequence_number) if c.messages else []
            sess_title = (c.title or "Sesi Panggilan Suara LUNA").replace("$skeleton", "").strip()
            for m in sorted_msgs:
                if m.role in ("user", "assistant") and m.content and m.content.strip():
                    is_user = m.role == "user"
                    emo_tag, emo_emoji = get_message_emotion(m, emotion_map)
                    all_msgs.append(
                        TodayMessageItem(
                            id=str(m.id),
                            role=m.role,
                            isUser=is_user,
                            content=m.content,
                            text=m.content,
                            time=format_time_local(m.created_at or c.started_at),
                            sessionTitle=sess_title,
                            emotionTag=emo_tag if is_user else None,
                            emotionEmoji=emo_emoji if is_user else None,
                        )
                    )

        total_items = len(all_msgs)
        total_pages = (total_items + limit - 1) // limit if total_items > 0 else 1
        offset = (page - 1) * limit
        items = all_msgs[offset : offset + limit]

        return TodayMessagesResponse(
            items=items,
            total_items=total_items,
            page=page,
            limit=limit,
            total_pages=total_pages,
        )

    async def get_conversation_by_id(self, conversation_id: str) -> ConversationDetailResponse:
        """Retrieve single conversation detail and transcript."""
        try:
            c_uuid = uuid.UUID(conversation_id)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid conversation ID")

        query = (
            select(Conversation)
            .options(
                selectinload(Conversation.messages),
                selectinload(Conversation.summaries),
            )
            .where(Conversation.id == c_uuid)
        )
        res = await self.db.execute(query)
        conv = res.scalar_one_or_none()

        if not conv:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")

        message_ids = [m.id for m in conv.messages] if conv.messages else []
        emotion_map: dict[uuid.UUID, EmotionAnalysis] = {}
        if message_ids:
            emo_query = select(EmotionAnalysis).where(EmotionAnalysis.message_id.in_(message_ids))
            emo_res = await self.db.execute(emo_query)
            for emo in emo_res.scalars().all():
                emotion_map[emo.message_id] = emo

        return format_conversation(conv, emotion_map)

    async def send_message(
        self, conversation_id: str, payload: SendMessageRequest
    ) -> SentMessageResponse:
        """Send and persist a new user text message in an ongoing conversation session."""
        try:
            c_uuid = uuid.UUID(conversation_id)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid conversation ID")

        query = (
            select(Conversation)
            .options(selectinload(Conversation.messages))
            .where(Conversation.id == c_uuid)
        )
        res = await self.db.execute(query)
        conv = res.scalar_one_or_none()

        if not conv:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")

        next_seq = len(conv.messages) + 1
        user_msg = Message(
            conversation_id=conv.id,
            role="user",
            content=payload.content,
            message_type=MessageType.TEXT,
            sequence_number=next_seq,
        )
        self.db.add(user_msg)
        await self.db.commit()
        await self.db.refresh(user_msg)

        if payload.content and payload.content.strip():
            try:
                analysis_result = await MLEmotionDetectorService.predict_message_emotion(payload.content)
                await MLEmotionDetectorService.save_emotion_to_db(user_msg.id, analysis_result, self.db)
                logger.info(f"🧠 [CHAT EMOTION PERSISTED]: Saved emotion for message {user_msg.id}")
            except Exception as emo_err:
                logger.warning(f"⚠️ [CHAT EMOTION EXCEPTION]: Failed to save emotion analysis: {emo_err}")

        return SentMessageResponse(
            id=str(user_msg.id),
            sender="user",
            text=user_msg.content,
            time="Sekarang",
            isAudio=False,
        )


# Backward-compatible aliases
_format_time_local = format_time_local
_format_duration_str = format_duration_str
_analyze_message_emotion_fallback = analyze_message_emotion_fallback
_get_message_emotion = get_message_emotion
_format_conversation = format_conversation
