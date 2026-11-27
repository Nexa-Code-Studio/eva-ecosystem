import logging
from datetime import date
from typing import Any
import uuid

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.orm.attributes import flag_modified

from ai.services.dass_extraction_service import DASSExtractionService
from app.core.tz import get_wib_day_range_utc, get_wib_today
from app.models.conversation import Conversation
from app.models.dass import DASSAssessment
from app.schemas.dass import (
    DASSAssessmentResponse,
    DASSItemSchema,
    DASSItemUpdate,
)

logger = logging.getLogger(__name__)

OFFICIAL_DASS21_ITEMS: list[dict[str, Any]] = [
    {"item_id": 1, "scale": "stress", "question_text": "Saya merasa bahwa diri saya menjadi marah karena hal-hal sepele."},
    {"item_id": 2, "scale": "anxiety", "question_text": "Saya merasa bibir saya sering kering."},
    {"item_id": 3, "scale": "depression", "question_text": "Saya sama sekali tidak dapat merasakan perasaan positif."},
    {"item_id": 4, "scale": "anxiety", "question_text": "Saya mengalami kesulitan bernafas (misalnya : seringkali terengah-engah atau tidak dapat bernafas padahal tidak melakukan aktivitas fisik sebelumnya)."},
    {"item_id": 5, "scale": "depression", "question_text": "Saya sepertinya tidak kuat lagi untuk melakukan suatu kegiatan."},
    {"item_id": 6, "scale": "stress", "question_text": "Saya cenderung bereaksi berlebihan terhadap suatu situasi."},
    {"item_id": 7, "scale": "anxiety", "question_text": "Saya merasa goyah (misalnya : kaki terasa mau 'copot')."},
    {"item_id": 8, "scale": "stress", "question_text": "Saya merasa sulit untuk bersantai."},
    {"item_id": 9, "scale": "anxiety", "question_text": "Saya menemukan diri saya berada dalam situasi yang membuat saya merasa sangat cemas dan saya akan merasa sangat lega jika semua ini berakhir."},
    {"item_id": 10, "scale": "depression", "question_text": "Saya merasa tidak ada hal yang dapat diharapkan di masa depan."},
    {"item_id": 11, "scale": "stress", "question_text": "Saya menemukan diri saya mudah merasa kesal."},
    {"item_id": 12, "scale": "stress", "question_text": "Saya merasa telah menghabiskan banyak energi untuk merasa cemas."},
    {"item_id": 13, "scale": "depression", "question_text": "Saya merasa sedih dan tertekan."},
    {"item_id": 14, "scale": "stress", "question_text": "Saya menemukan diri saya menjadi tidak sabar ketika mengalami penundaan (misalnya : kemacetan lalu lintas, menunggu sesuatu)."},
    {"item_id": 15, "scale": "anxiety", "question_text": "Saya merasa lemas seperti mau pingsan."},
    {"item_id": 16, "scale": "depression", "question_text": "Saya merasa saya kehilangan minat akan segala hal."},
    {"item_id": 17, "scale": "depression", "question_text": "Saya merasa bahwa saya tidak berharga sebagai seorang manusia."},
    {"item_id": 18, "scale": "stress", "question_text": "Saya merasa bahwa saya mudah tersinggung."},
    {"item_id": 19, "scale": "anxiety", "question_text": "Saya berkeringat secara berlebihan (misalnya : tangan berkeringat), padahal temperatur tidak panas atau tidak melakukan aktivitas fisik sebelumnya."},
    {"item_id": 20, "scale": "anxiety", "question_text": "Saya merasa takut tanpa alasan yang jelas."},
    {"item_id": 21, "scale": "depression", "question_text": "Saya merasa bahwa hidup tidak bermanfaat."},
]


class DASSService:
    """Service to manage DASS-21 psychological assessments, automated AI extraction, and score calculations."""

    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def generate_default_items() -> list[dict[str, Any]]:
        """Menghasilkan template 21 butir resmi dengan nilai default 0."""
        return [
            {
                "item_id": item["item_id"],
                "scale": item["scale"],
                "question_text": item["question_text"],
                "score": 0,
                "evidence": None,
                "reason": None,
                "confidence": 0.0,
                "is_user_edited": False,
            }
            for item in OFFICIAL_DASS21_ITEMS
        ]

    @staticmethod
    def calculate_scores(items: list[dict[str, Any]]) -> dict[str, Any]:
        """Menghitung total skor per subskala (dikali 2 sesuai norma DASS-21 Indonesia)
        dan mengklasifikasikan ke dalam kategori keparahan.
        """
        dep_raw = sum(int(it.get("score", 0)) for it in items if it.get("scale") == "depression")
        anx_raw = sum(int(it.get("score", 0)) for it in items if it.get("scale") == "anxiety")
        str_raw = sum(int(it.get("score", 0)) for it in items if it.get("scale") == "stress")

        dep_final = dep_raw * 2
        anx_final = anx_raw * 2
        str_final = str_raw * 2

        # Klasifikasi Depresi
        if dep_final >= 28:
            dep_sev = "Extremely Severe"
        elif dep_final >= 21:
            dep_sev = "Severe"
        elif dep_final >= 14:
            dep_sev = "Moderate"
        elif dep_final >= 10:
            dep_sev = "Mild"
        else:
            dep_sev = "Normal"

        # Klasifikasi Kecemasan
        if anx_final >= 20:
            anx_sev = "Extremely Severe"
        elif anx_final >= 15:
            anx_sev = "Severe"
        elif anx_final >= 10:
            anx_sev = "Moderate"
        elif anx_final >= 8:
            anx_sev = "Mild"
        else:
            anx_sev = "Normal"

        # Klasifikasi Stres
        if str_final >= 34:
            str_sev = "Extremely Severe"
        elif str_final >= 26:
            str_sev = "Severe"
        elif str_final >= 19:
            str_sev = "Moderate"
        elif str_final >= 15:
            str_sev = "Mild"
        else:
            str_sev = "Normal"

        return {
            "depression_score": dep_final,
            "anxiety_score": anx_final,
            "stress_score": str_final,
            "depression_severity": dep_sev,
            "anxiety_severity": anx_sev,
            "stress_severity": str_sev,
        }

    async def get_today_assessment(self, user_id: uuid.UUID) -> DASSAssessmentResponse:
        """Mengambil asesmen DASS hari ini. Jika belum ada di database,
        mengembalikan form default 21 butir (skor 0) agar mobile tetap bisa menampilkan form.
        """
        today_date = get_wib_today()
        stmt = select(DASSAssessment).where(
            DASSAssessment.user_id == user_id,
            DASSAssessment.assessed_date == today_date,
        )
        res = await self.db.execute(stmt)
        record = res.scalars().first()

        if record:
            return DASSAssessmentResponse.model_validate(record)

        default_items = self.generate_default_items()
        scores = self.calculate_scores(default_items)

        return DASSAssessmentResponse(
            id=None,
            user_id=user_id,
            conversation_id=None,
            assessed_date=today_date,
            depression_score=scores["depression_score"],
            anxiety_score=scores["anxiety_score"],
            stress_score=scores["stress_score"],
            depression_severity=scores["depression_severity"],
            anxiety_severity=scores["anxiety_severity"],
            stress_severity=scores["stress_severity"],
            verified_by_user=False,
            status="unassessed",
            items=[DASSItemSchema(**it) for it in default_items],
        )

    async def update_user_assessment(
        self,
        user_id: uuid.UUID,
        updates: list[DASSItemUpdate],
        assessment_id: uuid.UUID | None = None,
    ) -> DASSAssessmentResponse:
        """Memperbarui skor butir yang diedit oleh pengguna, menghitung ulang skor subskala,
        dan menandai record sebagai 'verified'.
        """
        today_date = get_wib_today()
        stmt = select(DASSAssessment).where(
            DASSAssessment.user_id == user_id,
            DASSAssessment.assessed_date == today_date,
        )
        res = await self.db.execute(stmt)
        record = res.scalars().first()

        if not record:
            base_items = self.generate_default_items()
            record = DASSAssessment(
                user_id=user_id,
                assessed_date=today_date,
                verified_by_user=True,
                status="verified",
                items=base_items,
            )
            self.db.add(record)

        current_items = list(record.items) if record.items else self.generate_default_items()
        item_dict_map = {it["item_id"]: it for it in current_items}

        for up in updates:
            if up.item_id in item_dict_map:
                item_dict_map[up.item_id]["score"] = up.score
                item_dict_map[up.item_id]["is_user_edited"] = True

        new_items = list(item_dict_map.values())
        scores = self.calculate_scores(new_items)

        record.items = new_items
        flag_modified(record, "items")
        record.depression_score = scores["depression_score"]
        record.anxiety_score = scores["anxiety_score"]
        record.stress_score = scores["stress_score"]
        record.depression_severity = scores["depression_severity"]
        record.anxiety_severity = scores["anxiety_severity"]
        record.stress_severity = scores["stress_severity"]
        record.verified_by_user = True
        record.status = "verified"

        await self.db.commit()
        await self.db.refresh(record)
        return DASSAssessmentResponse.model_validate(record)

    async def extract_today_assessment(self, user_id: uuid.UUID) -> DASSAssessmentResponse:
        """Trigger AI extraction of 21 DASS items from today's conversation transcripts."""
        today_wib = get_wib_today()
        start_utc, end_utc = get_wib_day_range_utc(today_wib)

        conv_stmt = (
            select(Conversation)
            .where(
                Conversation.user_id == user_id,
                or_(
                    and_(Conversation.started_at >= start_utc, Conversation.started_at <= end_utc),
                    and_(Conversation.created_at >= start_utc, Conversation.created_at <= end_utc),
                ),
            )
            .options(selectinload(Conversation.messages))
        )
        conv_res = await self.db.execute(conv_stmt)
        conversations = conv_res.scalars().all()

        formatted_msgs = []
        latest_conv_id = None
        for c in conversations:
            latest_conv_id = c.id
            sorted_msgs = sorted(
                c.messages,
                key=lambda x: (
                    getattr(x, "sequence_number", 0) or 0,
                    getattr(x, "created_at", None) or 0,
                ),
            )
            for m in sorted_msgs:
                if m.content and m.content.strip():
                    formatted_msgs.append(f"{m.role.upper()}: {m.content}")

        transcript = "\n".join(formatted_msgs)
        extractor = DASSExtractionService()
        extracted_items = await extractor.extract_from_transcript(transcript)

        saved_record = await self.save_or_update_extracted(
            user_id=user_id,
            assessed_date=today_wib,
            extracted_items=extracted_items,
            conversation_id=latest_conv_id,
        )
        return DASSAssessmentResponse.model_validate(saved_record)

    async def save_or_update_extracted(
        self,
        user_id: uuid.UUID,
        assessed_date: date,
        extracted_items: list[dict[str, Any]],
        conversation_id: uuid.UUID | None,
    ) -> DASSAssessment:
        """Menyimpan atau memperbarui hasil ekstraksi AI ke tabel dass_assessments."""
        item_map = {it["item_id"]: it for it in extracted_items}
        complete_items = []

        for default_it in self.generate_default_items():
            i_id = default_it["item_id"]
            if i_id in item_map:
                complete_items.append(item_map[i_id])
            else:
                complete_items.append(default_it)

        scores = self.calculate_scores(complete_items)

        stmt = select(DASSAssessment).where(
            DASSAssessment.user_id == user_id,
            DASSAssessment.assessed_date == assessed_date,
        )
        res = await self.db.execute(stmt)
        record = res.scalars().first()

        if record:
            if not record.verified_by_user:
                record.depression_score = scores["depression_score"]
                record.anxiety_score = scores["anxiety_score"]
                record.stress_score = scores["stress_score"]
                record.depression_severity = scores["depression_severity"]
                record.anxiety_severity = scores["anxiety_severity"]
                record.stress_severity = scores["stress_severity"]
                record.items = complete_items
                flag_modified(record, "items")
                if conversation_id:
                    record.conversation_id = conversation_id
        else:
            record = DASSAssessment(
                user_id=user_id,
                conversation_id=conversation_id,
                assessed_date=assessed_date,
                depression_score=scores["depression_score"],
                anxiety_score=scores["anxiety_score"],
                stress_score=scores["stress_score"],
                depression_severity=scores["depression_severity"],
                anxiety_severity=scores["anxiety_severity"],
                stress_severity=scores["stress_severity"],
                verified_by_user=False,
                status="auto_extracted",
                items=complete_items,
            )
            self.db.add(record)

        await self.db.commit()
        await self.db.refresh(record)
        return record
