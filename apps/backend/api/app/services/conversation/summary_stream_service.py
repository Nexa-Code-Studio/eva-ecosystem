from collections.abc import AsyncGenerator
import json
import logging
from typing import Any
import uuid

from fastapi import HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.session import AsyncSessionLocal
from app.models.conversation import Conversation, ConversationSummary
from packages.ai.factories.llm_factory import LLMFactory
from packages.ai.interfaces.llm import LLMMessage

logger = logging.getLogger(__name__)

CRISIS_KEYWORDS = (
    "bunuh diri", "capek hidup", "mati saja", "ingin mati", "putus asa",
    "menyakiti diri", "gantung diri", "akhiri hidup", "tak sanggup lagi",
    "tidak sanggup hidup"
)


class SummaryStreamService:
    """Service to generate and stream empathetic counseling summaries via SSE and persist to database."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def stream_summary(
        self, conversation_id: uuid.UUID, user_id: uuid.UUID
    ) -> StreamingResponse:
        """Stream 2-3 sentence empathetic counseling summary token-by-token using SSE."""
        query = (
            select(Conversation)
            .options(
                selectinload(Conversation.messages),
                selectinload(Conversation.summaries),
            )
            .where(Conversation.id == conversation_id, Conversation.user_id == user_id)
        )
        res = await self.db.execute(query)
        conv = res.scalar_one_or_none()
        if not conv:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Percakapan tidak ditemukan",
            )

        # 1. If already persisted in DB, yield cached summary immediately
        if conv.summaries and conv.summaries[-1].summary:
            existing_summary = conv.summaries[-1].summary

            async def cached_stream() -> AsyncGenerator[str, None]:
                yield f"data: {json.dumps({'token': existing_summary})}\n\n"
                yield f"data: {json.dumps({'done': True, 'summary': existing_summary})}\n\n"

            return StreamingResponse(
                cached_stream(),
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no",
                },
            )

        # 2. Extract user and assistant messages for transcript
        msgs = sorted(conv.messages, key=lambda m: m.created_at) if conv.messages else []
        user_assistant_msgs = [
            m for m in msgs if m.role in ("user", "assistant") and m.content and m.content.strip()
        ]

        transcript_text = "\n".join([f"{m.role.upper()}: {m.content}" for m in user_assistant_msgs])
        full_lower = transcript_text.lower()
        has_crisis = any(kw in full_lower for kw in CRISIS_KEYWORDS)

        if not user_assistant_msgs:
            fallback_summary = "Sesi percakapan curhat bersama LUNA berjalan dengan tenang dan aman."

            async def empty_stream() -> AsyncGenerator[str, None]:
                yield f"data: {json.dumps({'token': fallback_summary})}\n\n"
                yield f"data: {json.dumps({'done': True, 'summary': fallback_summary})}\n\n"

            return StreamingResponse(
                empty_stream(),
                media_type="text/event-stream",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "X-Accel-Buffering": "no",
                },
            )

        system_prompt = LLMMessage(
            role="system",
            content=(
                "Anda adalah konselor psikologis profesional LUNA AI. "
                "Tugas Anda adalah membuat ringkasan percakapan konseling yang sangat ringkas, padat, dan menenangkan (tepat 2-3 kalimat Bahasa Indonesia).\n"
                "Pedoman wajib:\n"
                "1. Fokus pada esensi perasaan yang dicurahkan pengguna dan pendampingan reflektif dari LUNA.\n"
                "2. Gunakan nada bicara hangat, empatik, tenang, dan suportif.\n"
                "3. DILARANG KERAS mengutip mentah kata-kata pengguna dalam tanda kutip.\n"
                "4. Jika terdeteksi kondisi krisis berat, berikan narasi suportif yang menekankan ruang aman dan pentingnya pertolongan profesional.\n"
                "5. Hasilkan HANYA teks ringkasan langsung tanpa judul, tanpa pembuka/penutup, dan tanpa format markdown."
            ),
        )
        user_prompt = LLMMessage(
            role="user",
            content=f"Berikut transkrip percakapan suara:\n\n{transcript_text}\n\nBuat ringkasan konseling 2-3 kalimat:",
        )

        async def generate_stream() -> AsyncGenerator[str, None]:
            full_tokens: list[str] = []
            try:
                llm_provider = LLMFactory.get_provider()
                async for token in llm_provider.stream_response([system_prompt, user_prompt]):
                    full_tokens.append(token)
                    yield f"data: {json.dumps({'token': token})}\n\n"
            except Exception as e:
                logger.error(f"⚠️ [SUMMARY STREAM LLM EXCEPTION]: {e}")
                fallback_text = (
                    "Pengguna meluangkan waktu untuk mengekspresikan beban emosional yang berat dalam sesi ini. "
                    "LUNA hadir mendampingi secara suportif, memberikan ruang aman untuk bercerita, "
                    "dan menegaskan bahwa setiap perasaan berharga serta bantuan selalu tersedia."
                    if has_crisis
                    else "Pengguna berbagi refleksi harian dan tantangan perasaan secara terbuka. "
                    "LUNA memberikan tanggapan yang menenangkan serta ruang aman untuk meredakan ketegangan."
                )
                if not full_tokens:
                    yield f"data: {json.dumps({'token': fallback_text})}\n\n"
                    full_tokens.append(fallback_text)

            full_summary = "".join(full_tokens).strip()
            if full_summary.startswith('"') and full_summary.endswith('"') and len(full_summary) > 2:
                full_summary = full_summary[1:-1].strip()

            if full_summary:
                try:
                    async with AsyncSessionLocal() as db_stream:
                        new_summary = ConversationSummary(
                            conversation_id=conversation_id,
                            summary=full_summary,
                        )
                        db_stream.add(new_summary)
                        await db_stream.commit()
                        logger.info(f"✅ [SUMMARY STREAM PERSISTED]: Conversation {conversation_id}")
                except Exception as db_err:
                    logger.error(f"⚠️ [FAILED TO PERSIST STREAM SUMMARY]: {db_err}")

            dominant_emotion = "Krisis / Sangat Tertekan" if has_crisis else None
            dominant_emoji = "🆘" if has_crisis else None

            yield f"data: {json.dumps({'done': True, 'summary': full_summary, 'dominant_emotion': dominant_emotion, 'dominant_emoji': dominant_emoji})}\n\n"

        return StreamingResponse(
            generate_stream(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )
