import logging
import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import desc, select
from sqlalchemy.orm import selectinload

from app.core.security import decode_access_token
from app.core.tz import get_wib_now, get_wib_today
from app.db.session import AsyncSessionLocal
from app.models.conversation import Conversation, ConversationSummary, Message, MessageType
from app.models.dass import DASSAssessment
from app.models.user import User
from app.services.audio_stream_buffer import audio_buffer_service
from app.services.dass_service import DASSService
from app.services.diary_generator import DiaryGeneratorService
from app.services.emotion_analyzer import EmotionAnalyzerService
from app.services.ml_emotion_detector import MLEmotionDetectorService
from packages.ai.services.dass_extraction_service import DASSExtractionService

logger = logging.getLogger(__name__)


class CallPersistenceService:
    """Handles all database persistence and history synchronization for voice call sessions."""

    @staticmethod
    async def load_conversation_history(session: Any) -> None:
        """Load past conversation and DASS context into session history and create new DB conversation."""
        if session.is_history_loaded:
            return

        try:
            async with AsyncSessionLocal() as db:
                user = None
                if session.auth_token:
                    decoded = decode_access_token(session.auth_token)
                    if decoded and "sub" in decoded:
                        try:
                            u_uuid = uuid.UUID(decoded["sub"])
                            res_user = await db.execute(select(User).where(User.id == u_uuid))
                            user = res_user.scalar_one_or_none()
                        except Exception:
                            pass

                if user:
                    session.user_id = user.id
                    session.user_name = user.display_name or user.username or None
                    logger.info(
                        f"👤 [USER CONTEXT LOADED] Session {session.session_id}: User ID {user.id}, Name: '{session.user_name}'"
                    )

                    # Retrieve previous conversation history memory context
                    conv_query = (
                        select(Conversation)
                        .options(selectinload(Conversation.messages))
                        .where(Conversation.user_id == user.id)
                        .order_by(Conversation.started_at.desc())
                    )
                    res_conv = await db.execute(conv_query)
                    past_convs = res_conv.scalars().all()

                    if past_convs:
                        all_past_msgs = []
                        for pc in past_convs[:5]:
                            sorted_m = sorted(pc.messages, key=lambda m: m.sequence_number)
                            all_past_msgs.extend([f"{m.role}: {m.content}" for m in sorted_m if m.content])

                        if all_past_msgs:
                            memory_summary = " ".join(all_past_msgs[-10:])[:1000]
                            session.conversation_history[0].content += (
                                f"\n\n[Memori Percakapan Terdahulu Pengguna]:\n{memory_summary}"
                            )

                    # Retrieve latest DASS-21 psychometric assessment context
                    dass_stmt = (
                        select(DASSAssessment)
                        .where(DASSAssessment.user_id == user.id)
                        .order_by(desc(DASSAssessment.assessed_date))
                        .limit(1)
                    )
                    res_dass = await db.execute(dass_stmt)
                    latest_dass = res_dass.scalars().first()
                    if latest_dass and (
                        latest_dass.depression_score > 0
                        or latest_dass.anxiety_score > 0
                        or latest_dass.stress_score > 0
                    ):
                        session.dass_scores = {
                            "depression": latest_dass.depression_score,
                            "anxiety": latest_dass.anxiety_score,
                            "stress": latest_dass.stress_score,
                        }
                        session.conversation_history[0].content += (
                            f"\n\n[Profil Asesmen Psikologis DASS-21 Terkini Pengguna]:\n"
                            f"- Tingkat Depresi: {latest_dass.depression_severity} (Skor: {latest_dass.depression_score})\n"
                            f"- Tingkat Kecemasan: {latest_dass.anxiety_severity} (Skor: {latest_dass.anxiety_score})\n"
                            f"- Tingkat Stres: {latest_dass.stress_severity} (Skor: {latest_dass.stress_score})\n"
                            f"Gunakan profil ini sebagai acuan empati dan gaya berbicara (jangan sebut angka skor secara kaku, "
                            f"melainkan sesuaikan kehangatan dan kepekaanmu terhadap kondisi emosionalnya)."
                        )
                        logger.info(
                            f"📊 [DASS CONTEXT LOADED] Session {session.session_id}: "
                            f"Depression={latest_dass.depression_severity}, Anxiety={latest_dass.anxiety_severity}, Stress={latest_dass.stress_severity}"
                        )

                    # Always create a NEW distinct Conversation record for this new voice session
                    now_str = get_wib_now().strftime("%d %b %Y %H:%M")
                    new_conv = Conversation(
                        user_id=user.id,
                        title=f"Panggilan Suara EVA {now_str}",
                    )
                    db.add(new_conv)
                    await db.commit()
                    await db.refresh(new_conv)

                    session.db_conversation_id = new_conv.id
                    logger.info(
                        f"📜 [NEW VOICE CONVERSATION CREATED] Session {session.session_id}: "
                        f"Created Conversation ID {new_conv.id} ('{new_conv.title}') in DB"
                    )

            session.is_history_loaded = True
        except Exception as e:
            logger.error(f"⚠️ [LOAD HISTORY EXCEPTION] Session {session.session_id}: {e}")
            session.is_history_loaded = True

    @staticmethod
    async def save_message(
        session: Any,
        role: str,
        content: str,
        analysis_result: dict[str, Any] | None = None,
    ) -> None:
        """Persist a single voice turn message and trigger ML emotion detection."""
        if not session.db_conversation_id or not content.strip():
            return
        try:
            async with AsyncSessionLocal() as db:
                query = (
                    select(Conversation)
                    .options(selectinload(Conversation.messages))
                    .where(Conversation.id == session.db_conversation_id)
                )
                res = await db.execute(query)
                conv = res.scalar_one_or_none()
                if conv:
                    next_seq = len(conv.messages) + 1
                    msg = Message(
                        conversation_id=conv.id,
                        role=role,
                        content=content,
                        message_type=MessageType.VOICE,
                        sequence_number=next_seq,
                    )
                    conv.last_message_at = datetime.now(UTC)
                    db.add(msg)
                    await db.commit()
                    await db.refresh(msg)
                    logger.info(f"💾 [SAVED TO DB] Session {session.session_id}: Saved {role} voice message to DB")

                    if role == "user" and content and content.strip():
                        try:
                            if analysis_result is None:
                                buf = audio_buffer_service.get_or_create_buffer(session.session_id)
                                turn_audio_bytes = buf.get_full_audio() if buf.total_bytes > 0 else None
                                buf.clear()
                                analysis_result = await MLEmotionDetectorService.predict_message_emotion(
                                    content, audio_bytes=turn_audio_bytes
                                )
                            await MLEmotionDetectorService.save_emotion_to_db(msg.id, analysis_result, db)
                            logger.info(f"🧠 [VOICE EMOTION PERSISTED]: Saved emotion for voice turn message {msg.id}")
                        except Exception as emo_err:
                            logger.warning(f"⚠️ [VOICE EMOTION EXCEPTION]: Failed to save emotion analysis: {emo_err}")
        except Exception as e:
            logger.error(f"⚠️ [SAVE MSG EXCEPTION] Session {session.session_id}: {e}")

    @staticmethod
    async def update_session_end(db_conversation_id: Any, duration_seconds: int | None = None) -> None:
        """Update last_message_at based on actual duration upon session completion."""
        if not db_conversation_id:
            return
        try:
            async with AsyncSessionLocal() as db:
                query = select(Conversation).where(Conversation.id == db_conversation_id)
                res = await db.execute(query)
                conv = res.scalar_one_or_none()
                if conv:
                    now = datetime.now(UTC)
                    if duration_seconds and duration_seconds > 0:
                        conv.last_message_at = conv.started_at + timedelta(seconds=duration_seconds)
                    else:
                        conv.last_message_at = now
                    await db.commit()
                    logger.info(f"⏱️ [SESSION END DURATION PERSISTED]: Updated last_message_at to {conv.last_message_at}")
        except Exception as e:
            logger.error(f"⚠️ [UPDATE SESSION END EXCEPTION]: {e}")

    @staticmethod
    async def sync_today_diary(session: Any) -> None:
        """Create or Update today's single DiaryEntry ONCE upon disconnecting a voice call session."""
        if not session.user_id:
            return

        try:
            user_texts = [m.content for m in session.conversation_history if m.role == "user" and m.content]
            if not user_texts:
                return

            analysis = await EmotionAnalyzerService.analyze_transcript(session.conversation_history)

            session_title = analysis.get("session_title")
            session_summary = analysis.get("diary_summary") or analysis.get("ai_insight")
            if session.db_conversation_id:
                async with AsyncSessionLocal() as db_conv:
                    conv_res = await db_conv.execute(
                        select(Conversation).where(Conversation.id == session.db_conversation_id)
                    )
                    conv_obj = conv_res.scalar_one_or_none()
                    if conv_obj:
                        if session_title:
                            conv_obj.title = session_title
                        if session_summary:
                            new_summary = ConversationSummary(
                                conversation_id=conv_obj.id,
                                summary=session_summary,
                            )
                            db_conv.add(new_summary)
                        await db_conv.commit()
                        logger.info(
                            f"🏷️ [AI CONVERSATION TITLE & SUMMARY PERSISTED]: Conversation {conv_obj.id} -> '{session_title}'"
                        )

            async with AsyncSessionLocal() as db:
                diary_entry = await DiaryGeneratorService.generate_today_diary(session.user_id, db)
                logger.info(
                    f"📖 [DISCONNECT DIARY SYNC SUCCESS] Session {session.session_id}: Synced cumulative DiaryEntry '{diary_entry.title}' for {diary_entry.entry_date}"
                )
        except Exception as e:
            logger.error(f"⚠️ [SYNC DIARY EXCEPTION] Session {session.session_id}: {e}")

    @staticmethod
    async def sync_today_dass(session: Any) -> None:
        """Extract and update today's DASS-21 assessment upon disconnecting a voice call session."""
        if not session.user_id:
            return

        try:
            user_texts = [m.content for m in session.conversation_history if m.role == "user" and m.content]
            if not user_texts:
                return

            formatted_msgs = []
            for m in session.conversation_history:
                if m.role in ("user", "assistant") and m.content and m.content.strip():
                    formatted_msgs.append(f"{m.role.upper()}: {m.content}")

            transcript = "\n".join(formatted_msgs)
            extractor = DASSExtractionService()
            extracted_items = await extractor.extract_from_transcript(transcript)

            async with AsyncSessionLocal() as db:
                today_wib = get_wib_today()
                saved_record = await DASSService.save_or_update_extracted(
                    user_id=session.user_id,
                    assessed_date=today_wib,
                    extracted_items=extracted_items,
                    conversation_id=session.db_conversation_id,
                    db=db,
                )
                logger.info(
                    f"📊 [DISCONNECT DASS SYNC SUCCESS] Session {session.session_id}: "
                    f"Synced DASS-21 for {today_wib} (D: {saved_record.depression_score}, "
                    f"A: {saved_record.anxiety_score}, S: {saved_record.stress_score})"
                )
        except Exception as e:
            logger.error(f"⚠️ [SYNC DASS EXCEPTION] Session {session.session_id}: {e}")
