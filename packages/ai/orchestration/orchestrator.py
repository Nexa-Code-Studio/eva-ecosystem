import asyncio
import logging
import os
import time
from collections.abc import AsyncGenerator
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

from ai.factories.llm_factory import LLMFactory
from ai.factories.tts_factory import TTSFactory
from ai.interfaces.embedding import BaseEmbeddingProvider
from ai.interfaces.llm import BaseLLMProvider, LLMMessage
from ai.interfaces.stt import BaseSTTProvider
from ai.interfaces.tts import BaseTTSProvider
from ai.interfaces.vector_store import BaseVectorStore
from ai.services.embedding_service import DefaultEmbeddingProvider
from ai.services.emotion_service import EmotionService
from ai.services.rag import RAGService
from ai.services.risk_assessment_service import RiskAssessmentService
from ai.services.safety_gate import SafetyGate
from ai.services.symptom_service import SymptomService
from ai.vector_store.qdrant import QdrantVectorStore
from packages.shared.config import settings
from shared.domain_types import (
    EmotionDetectionResult,
    EmotionSource,
    EmotionWindowStatus,
    LLMMode,
    MentalHealthSeverity,
    ProtocolAction,
    ResponseMode,
    RiskAssessmentInput,
    RiskAssessmentOutput,
    SafetyGateInput,
    SafetyPolicyDecision,
    SymptomExtractionResult,
    TemporalEmotionSnapshot,
)

logger = logging.getLogger(__name__)

CRISIS_SOP_MESSAGE = (
    "Aku mendengar betapa berat dan melelahkannya apa yang sedang kamu rasakan saat ini. "
    "Ketahuilah bahwa kamu sangat berharga dan kamu tidak harus menanggung ini sendirian. "
    "Tolong segera hubungi layanan darurat kesehatan mental bebas pulsa Kemenkes di 119 ekstensi 8, "
    "atau Hotline LISA di 0811-3855-472. "
    "Aku di sini untuk mendengarkan, tapi tolong hubungi orang terdekat atau tenaga profesional sekarang juga ya."
)


@dataclass
class OrchestratedTurnResult:
    """Kontainer hasil pemrosesan giliran percakapan yang lengkap dengan audit keamanan & metadata."""
    user_text: str
    emotion: EmotionDetectionResult
    symptoms: SymptomExtractionResult
    risk_output: RiskAssessmentOutput
    safety_decision: SafetyPolicyDecision
    rag_items: list[dict[str, Any]]
    is_crisis: bool
    final_system_prompt: str
    token_stream: AsyncGenerator[str, None]
    execution_time_ms: float = 0.0


class AIOrchestrator:
    """Production Multi-Stage Counseling Orchestrator for Eva AI.

    Mengorkestrasi seluruh alur konseling:
    1. Emotion Ingestion (Voice Audio / Text Sentiment)
    2. Symptom Extraction (WHO-EASE Taxonomy)
    3. Risk Assessment & Safety Gate (Triage & Crisis Evaluation)
    4. RAG Retrieval from Qdrant (Mental Health Psychoeducation Knowledge)
    5. Empathetic Prompt Formulation
    6. LLM Streaming / Crisis Template Execution
    """

    def __init__(
        self,
        stt_provider: Optional[BaseSTTProvider] = None,
        llm_provider: Optional[BaseLLMProvider] = None,
        tts_provider: Optional[BaseTTSProvider] = None,
        emotion_service: Optional[EmotionService] = None,
        symptom_service: Optional[SymptomService] = None,
        risk_service: Optional[RiskAssessmentService] = None,
        safety_gate: Optional[SafetyGate] = None,
        rag_service: Optional[RAGService] = None,
        vector_store: Optional[BaseVectorStore] = None,
        embedding_provider: Optional[BaseEmbeddingProvider] = None,
        rag_timeout_seconds: float = 0.4,
    ):
        self.stt_provider = stt_provider
        self._llm_provider: Optional[BaseLLMProvider] = llm_provider
        self._tts_provider: Optional[BaseTTSProvider] = tts_provider
        self.emotion_service = emotion_service or EmotionService()
        self.symptom_service = symptom_service or SymptomService()
        self.risk_service = risk_service or RiskAssessmentService()
        self.safety_gate = safety_gate or SafetyGate()
        self.rag_timeout_seconds = rag_timeout_seconds

    @property
    def llm_provider(self) -> BaseLLMProvider:
        if self._llm_provider is None:
            self._llm_provider = LLMFactory.get_provider()
        return self._llm_provider

    @llm_provider.setter
    def llm_provider(self, value: Optional[BaseLLMProvider]) -> None:
        self._llm_provider = value

    @property
    def tts_provider(self) -> BaseTTSProvider:
        if self._tts_provider is None:
            self._tts_provider = TTSFactory.get_provider()
        return self._tts_provider

    @tts_provider.setter
    def tts_provider(self, value: Optional[BaseTTSProvider]) -> None:
        self._tts_provider = value

        # Inisialisasi komponen RAG Qdrant
        if rag_service and embedding_provider:
            self.rag_service = rag_service
            self.embedding_provider = embedding_provider
            self.vector_store = vector_store
        else:
            try:
                qdrant_url = getattr(settings, "QDRANT_URL", "http://localhost:6333")
                self.vector_store = vector_store or QdrantVectorStore(url=qdrant_url)
                self.embedding_provider = embedding_provider or DefaultEmbeddingProvider()
                self.rag_service = rag_service or RAGService(vector_store=self.vector_store)
            except Exception as e:
                logger.warning(f"⚠️ [ORCHESTRATOR] RAG components initialization deferred/fallback: {e}")
                self.rag_service = None
                self.embedding_provider = None
                self.vector_store = None

    def _infer_emotion_from_text(self, text: str) -> EmotionDetectionResult:
        """Heuristic sentiment fallback jika audio fisik belum tersedia/gagal."""
        text_lower = text.lower()
        if any(w in text_lower for w in ["senang", "bahagia", "suka", "lega", "puas", "bangga", "bersyukur", "lulus", "berhasil"]):
            primary = "happy"
            confidence = 0.88
        elif any(w in text_lower for w in ["cemas", "takut", "khawatir", "stres", "panik", "deg-degan", "gemetar"]):
            primary = "fearful"
            confidence = 0.85
        elif any(w in text_lower for w in ["sedih", "kecewa", "menangis", "lelah", "hancur", "putus asa", "capek"]):
            primary = "sad"
            confidence = 0.80
        elif any(w in text_lower for w in ["marah", "kesal", "kesel", "benci", "jengkel", "geram"]):
            primary = "angry"
            confidence = 0.82
        elif any(w in text_lower for w in ["kaget", "terkejut", "syok"]):
            primary = "surprised"
            confidence = 0.75
        else:
            primary = "neutral"
            confidence = 0.90

        scores = {k: (confidence if k == primary else 0.02) for k in [
            "angry", "disgusted", "fearful", "happy", "neutral", "other", "sad", "surprised", "unknown"
        ]}

        intensity = round(confidence * 0.85, 2)
        sorted_scores = sorted([(k, v) for k, v in scores.items() if k != primary], key=lambda x: x[1], reverse=True)
        secondary = sorted_scores[0][0] if sorted_scores and sorted_scores[0][1] >= 0.10 else None

        return EmotionDetectionResult(
            primary_emotion=primary,
            confidence=confidence,
            intensity=intensity,
            secondary_emotion=secondary,
            scores=scores,
            model_used="text-lexicon-heuristic",
            latency_ms=0.5,
            source=EmotionSource.TEXT_HEURISTIC,
            status=EmotionWindowStatus.READY,
        )


    def _detect_emotion(self, text: str, audio_path: Optional[str] = None) -> EmotionDetectionResult:
        """Mendeteksi emosi dari file audio jika ada, atau fallback ke analisis teks."""
        if audio_path and os.path.exists(audio_path):
            try:
                logger.info(f"🎙️ [ORCHESTRATOR] Running EmotionService on audio '{audio_path}'")
                return self.emotion_service.predict(audio_path)
            except Exception as e:
                logger.warning(f"⚠️ [ORCHESTRATOR] Voice emotion detection error, fallback to text: {e}")

        return self._infer_emotion_from_text(text)

    async def _fetch_rag_context(self, query_text: str) -> list[dict[str, Any]]:
        """Mengambil dokumen pengetahuan mental health dari Qdrant dengan batas timeout ketat."""
        if not self.rag_service or not self.embedding_provider:
            return []

        try:
            async def _search():
                query_vector = await self.embedding_provider.embed_query(query_text)
                return await self.rag_service.search_relevant_context(
                    collection_name="knowledge",
                    query_embedding=query_vector,
                    limit=2,
                )

            items = await asyncio.wait_for(_search(), timeout=self.rag_timeout_seconds)
            logger.info(f"📚 [ORCHESTRATOR] RAG retrieved {len(items)} knowledge chunks from Qdrant")
            return items
        except asyncio.TimeoutError:
            logger.warning(f"⏳ [ORCHESTRATOR] Qdrant RAG search timed out after {self.rag_timeout_seconds}s (skipped for latency)")
            return []
        except Exception as e:
            logger.warning(f"⚠️ [ORCHESTRATOR] RAG search error: {e}")
            return []

    def _compose_crisis_guidance_block(
        self,
        *,
        is_crisis: bool,
        is_crisis_session: bool,
        risk_level: str,
    ) -> str:
        """Build strict, empathetic emergency guidance for dynamic LLM responses."""
        if is_crisis:
            return (
                "\n[MODE DARURAT AKTIF — KESELAMATAN, KEHATI-HATIAN & EMPATI TINGGI]\n"
                f"- Tingkat risiko terdeteksi: '{risk_level}'. Pengguna membutuhkan pendampingan yang sangat hati-hati, tenang, hangat, dan peduli.\n"
                "- Hadir penuh untuk pengguna: validasi rasa sakit/lelahnya tanpa menghakimi, jangan menyalahkan, jangan mendikte, dan jangan memberi janji palsu atau diagnosis klinis.\n"
                "- Gunakan kalimat pendek, lembut, dan menenangkan (grounding) agar pengguna merasa aman dan tidak sendirian.\n"
                "- Ajak secara halus dan penuh kepedulian untuk menghubungi orang terdekat yang dipercaya atau layanan bantuan profesional darurat "
                "(Kemenkes 119 ekstensi 8 atau Hotline LISA 0811-3855-472) yang juga tersedia di layar panggilan, sambil tetap siap mendengarkan bila pengguna ingin terus berbicara.\n"
                "- DILARANG membahas metode menyakiti diri, memberi instruksi berisiko, bersikap dingin/robotik, atau memakai humor."
            )
        if is_crisis_session:
            return (
                "\n[MODE DARURAT LANJUTAN — ELEVATED CARE & GROUNDING]\n"
                "- Panggilan ini berada dalam status perhatian darurat dari giliran sebelumnya. Pertahankan nada yang sangat lembut, berhati-hati, sabar, dan penuh kepedulian.\n"
                "- Dengarkan dan respons langsung ucapan terbaru pengguna dengan validasi hangat dan langkah grounding sederhana (misal mengajak tarik napas perlahan).\n"
                "- Jangan mengulang skrip nomor hotline secara kaku di setiap giliran jika sudah disampaikan, cukup ingatkan secara lembut bila relevan bahwa bantuan profesional atau orang terdekat selalu bisa dihubungi dari layar panggilan.\n"
                "- DILARANG bersikap santai berlebihan, bercanda, atau mengabaikan kerentanan emosional pengguna."
            )
        return ""

    def _compose_system_prompt_v1(
        self,
        emotion: EmotionDetectionResult,
        safety_decision: SafetyPolicyDecision,
        rag_items: list[dict[str, Any]],
        dass_scores: Optional[dict[str, Any]] = None,
        user_name: Optional[str] = None,
        persisted_memory: Optional[str] = None,
        structured_persisted_context: Optional[List[Dict[str, Any]]] = None,
        is_crisis: bool = False,
        is_crisis_session: bool = False,
    ) -> str:
        """Menyusun system prompt empati konseling dinamis berdasarkan hasil observasi multi-agent."""
        emotion_guidance_map = {
            "sad": "Pengguna sedang bersedih atau berduka. Gunakan nada bicara yang lembut, menenangkan, penuh penerimaan tanpa menghakimi. Validasi kesedihannya dan beri ruang aman bagi mereka untuk merasakan apa yang dirasakan.",
            "fearful": "Pengguna merasa cemas, takut, atau tegang. Hadirkan ketenangan yang menstabilkan (grounding), bantu menenangkan nafas, dan tunjukkan bahwa saat ini mereka aman dan didengarkan sepenuhnya.",
            "angry": "Pengguna merasa kesal, marah, atau frustrasi. Dengarkan dengan empati penuh tanpa membela diri atau mendebat. Validasi emosinya yang sah ('Wajar jika kamu merasa kesal...') dan bantu mengurai rasa sesak tersebut.",
            "disgusted": "Pengguna merasa muak, kecewa berat, atau risih. Tunjukkan penerimaan tanpa menghakimi, bantu mereka mengungkapkan rasa ketidaknyamanan tersebut secara sehat.",
            "happy": "Pengguna merasa bahagia, lega, atau bersemangat. Sambut dengan kehangatan tulus, apresiasi momen positif mereka, dan rayakan kemajuan kecil yang mereka rasakan.",
            "surprised": "Pengguna merasa kaget atau terkejut. Bersikaplah suportif dan bantu mereka menata kembali pikiran dan perasaan mereka secara perlahan.",
            "neutral": "Pengguna berada dalam kondisi tenang atau netral. Jaga alur percakapan tetap mengalir santai, terbuka, ramah, dan tunjukkan minat tulus pada ceritanya.",
        }
        guidance = emotion_guidance_map.get(
            emotion.primary_emotion.lower(),
            "Jaga nada bicara tetap ramah, hangat, penuh perhatian, dan empatik terhadap cerita pengguna.",
        )

        intensity_pct = int(getattr(emotion, "intensity", 0.5) * 100)
        conf_pct = int(emotion.confidence * 100)
        secondary_str = f", Nuansa sekunder: '{emotion.secondary_emotion}'" if getattr(emotion, "secondary_emotion", None) else ""

        prompt = (
            "Kamu adalah Eva, seorang konselor pendamping kesehatan mental AI yang ramah, hangat, dan penuh empati.\n"
            f"Kondisi emosi pengguna yang terobservasi: '{emotion.primary_emotion}' (Intensitas: {intensity_pct}%, Keyakinan: {conf_pct}%{secondary_str}).\n"
            f"Panduan Nada Emosional Konseling: {guidance}\n"
            f"Tingkat risiko keselamatan: '{safety_decision.risk_level}'. Kebijakan respon: '{safety_decision.response_policy}'.\n"
        )

        if user_name and user_name.strip():
            clean_name = user_name.strip()
            prompt += (
                f"\n[PROFIL PENGGUNA]\n"
                f"Nama Pengguna: {clean_name}\n"
                f"PANDUAN SAPAAN: Anda mengetahui bahwa nama pengguna adalah {clean_name}. "
                f"Gunakan nama panggilannya secara wajar dan natural untuk membangun kehangatan emosional "
                f"(misalnya di awal respon atau saat memvalidasi perasaannya). "
                f"DILARANG menyebut nama pengguna berulang-ulang di setiap kalimat agar tidak terasa kaku atau aneh.\n"
            )

        if structured_persisted_context:
            context_lines = [
                f"- [{it.get('category', 'konteks')}]: {it.get('text', '').strip()}"
                for it in structured_persisted_context
                if it.get("text")
            ]
            if context_lines:
                prompt += "\n[Fakta Konteks Personal Pengguna (SQLCipher Terenkripsi)]:\n" + "\n".join(context_lines) + "\n"
        elif persisted_memory and persisted_memory.strip():
            prompt += f"\n[Memori Percakapan Terdahulu Pengguna]:\n{persisted_memory.strip()}\n"

        if dass_scores:
            dep = dass_scores.get("depression", 0)
            anx = dass_scores.get("anxiety", 0)
            st = dass_scores.get("stress", 0)
            if dep > 0 or anx > 0 or st > 0:
                prompt += (
                    f"Profil Psikometris Terkini Pengguna (DASS-21): Depresi (skor {dep}), Kecemasan (skor {anx}), Stres (skor {st}). "
                    f"Selaraskan empati dan kehangatanmu sesuai kondisi kerentanan emosional ini.\n"
                )

        if rag_items:
            knowledge_blocks = []
            for item in rag_items:
                title = item.get("title", "Pengetahuan Konseling")
                content = item.get("content", "")[:180]
                knowledge_blocks.append(f"- {title}: {content}")
            prompt += (
                f"\nGunakan referensi pengetahuan konseling berikut jika relevan secara alami sebagai bahan acuan (DILARANG membaca kaku atau mendikte isi artikel):\n"
                + "\n".join(knowledge_blocks)
                + "\n"
            )

        prompt += (
            "\nPedoman Respon Suara (Voice Conversation Rules):\n"
            "1. Berbicaralah dalam Bahasa Indonesia yang santun, akrab, dan hangat (seperti teman bicara yang penuh pengertian).\n"
            "2. Default Panjang Respon: 1 hingga 3 kalimat ringkas per giliran bicara. Ini adalah panggilan telepon suara interaktif, BUKAN penulisan artikel atau esai.\n"
            "3. Validasi Emosi & Refleksi: Fokus utama adalah memvalidasi cerita pengguna dan mendengarkan dengan penuh perhatian. Boleh mengajukan SATU pertanyaan terbuka ringan untuk memperdalam pemahaman.\n"
            "4. DILARANG KERAS: Membuat daftar berpoin (1, 2, 3), tanda pagar (#), simbol cetak tebal (* atau **), emoji dekoratif, atau penjelasan ensiklopedis panjang kecuali pengguna secara eksplisit meminta penjelasan teori atau langkah teknis.\n"
            "5. Eksplorasi DASS-21 Non-Frontal: Saat pengguna mengungkapkan stres, cemas, atau sedih, ajukan pertanyaan terbuka reflektif yang menyentuh sensasi fisik atau suasana hati secara alami tanpa pernah menyebut istilah kuesioner psikologi.\n"
            "6. Tulis kata secara lengkap tanpa singkatan (misal: tulis 'dan lain-lain', bukan 'dll.'). Gunakan tanda koma (,), titik (.), atau elipsis (...) untuk jeda nafas alami TTS."
        )

        enable_audio_tags = getattr(settings, "TTS_ENABLE_AUDIO_TAGS", True)
        if enable_audio_tags:
            prompt += (
                "\n7. Pengendali Vokal & Emosi ElevenLabs v4 Turbo (Audio Tags):\n"
                "Anda berbicara melalui ElevenLabs v4 Turbo. Gunakan konteks emosi dan percakapan untuk menentukan ekspresi vokal yang tepat.\n"
                "Anda dapat menyisipkan Audio Tag vokal alami dalam kurung siku di awal kalimat atau sebelum klausa, contoh:\n"
                "- [warm, calm] untuk pembukaan atau respons yang hangat dan menenangkan.\n"
                "- [soft, reflective] untuk validasi emosi dan empati reflektif.\n"
                "- [gentle curiosity] untuk pertanyaan terbuka yang lembut dan penuh perhatian.\n"
                "- [calm, reassuring] untuk menenangkan kecemasan, kebingungan, atau kegelisahan.\n"
                "- [chuckles] atau [slightly amused] hanya untuk momen santai/humor yang menyenangkan.\n"
                "ATURAN KETAT AUDIO TAG KONSELING:\n"
                "- Gunakan tag secara hemat dan bermakna; jangan berikan tag pada setiap kalimat (maksimal 1 arahan vokal per klausa/kalimat).\n"
                "- Jaga respon tetap tenang, halus, dan non-teatrikal. DILARANG KERAS tag dramatis seperti [crying], [screaming], [terrified], [shouting], [panicking].\n"
                "- Untuk situasi rentan atau risiko tinggi: selalu gunakan nada [calm, steady] yang mantap, hangat, dan jernih.\n"
                "- DILARANG tertawa ([chuckles]) pada situasi sedih, duka, krisis, atau pengungkapan masalah berat.\n"
                "- Gunakan HANYA tag pendengaran vokal. DILARANG tag visual fisik seperti [smiling], [nodding], [standing].\n"
                "- Tag vokal tidak boleh mengubah makna percakapan, menghakimi, atau memberikan diagnosis.\n"
                "- Gunakan tanda elipsis (...) untuk jeda hening alami.\n"
            )

        crisis_block = self._compose_crisis_guidance_block(
            is_crisis=is_crisis,
            is_crisis_session=is_crisis_session,
            risk_level=safety_decision.risk_level,
        )
        if crisis_block:
            prompt += crisis_block + "\n"

        return prompt

    def _compose_system_prompt(
        self,
        emotion: EmotionDetectionResult,
        safety_decision: SafetyPolicyDecision,
        rag_items: list[dict[str, Any]],
        dass_scores: Optional[dict[str, Any]] = None,
        user_name: Optional[str] = None,
        persisted_memory: Optional[str] = None,
        structured_persisted_context: Optional[List[Dict[str, Any]]] = None,
        is_crisis: bool = False,
        is_crisis_session: bool = False,
    ) -> str:
        """Menyusun system prompt empati konseling dinamis berlapis untuk ElevenLabs v4 Turbo."""
        prompt_version = getattr(settings, "EVA_PROMPT_VERSION", getattr(settings, "LUNA_PROMPT_VERSION", "v2"))
        if prompt_version == "v1":
            return self._compose_system_prompt_v1(
                emotion,
                safety_decision,
                rag_items,
                dass_scores,
                user_name,
                persisted_memory,
                structured_persisted_context,
                is_crisis=is_crisis,
                is_crisis_session=is_crisis_session,
            )

        # Layer 1 — Identitas & Peran Eva
        prompt_parts: list[str] = [
            "Kamu adalah Eva, seorang pendamping kesehatan mental AI yang hangat, penuh empati, dan mendengarkan dengan tulus.\n",
            "[LAYER 1 — IDENTITAS & PERAN EVA]",
            "- Hadir sebagai teman bicara suportif yang aman, peduli, dan bebas dari penghakiman.",
            "- Sadar keterbatasan AI: Kamu adalah asisten AI, bukan tenaga medis, psikolog klinis berlisensi, atau psikiater. Jangan memberikan diagnosis klinis atau janji kepastian palsu.",
        ]

        if user_name and user_name.strip():
            clean_name = user_name.strip()
            prompt_parts.append(
                f"- Nama pengguna adalah {clean_name}. Gunakan namanya secara wajar dan natural saat membangun kehangatan. Jangan mengulang namanya di setiap kalimat."
            )

        # Layer 2 — Prioritas Percakapan & Konteks
        prompt_parts.extend([
            "\n[LAYER 2 — PRIORITAS PERCAKAPAN & KONTEKS]",
            "1. Prioritas Utama: Tanggapi langsung ucapan terbaru dan maksud inti pengguna saat ini.",
            "2. Kesinambungan Dialog: Rujuk secara wajar 2-3 giliran dialog terakhir bila relevan, tanpa merangkum ulang cerita panjang lebar.",
            "3. Pengetahuan Referensial: Gunakan informasi referensi hanya sebagai acuan pendukung ringkas bila relevan. DILARANG KERAS mengutip, membacakan esai, atau mendikte isi artikel panjang tanpa diminta pengguna.",
        ])

        if structured_persisted_context:
            context_lines = [
                f"- [{it.get('category', 'konteks')}]: {it.get('text', '').strip()}"
                for it in structured_persisted_context
                if it.get("text")
            ]
            if context_lines:
                prompt_parts.append(
                    "\n[Fakta Konteks Personal Pengguna (SQLCipher Terenkripsi)]:\n" + "\n".join(context_lines)
                )
        elif persisted_memory and persisted_memory.strip():
            prompt_parts.append(f"\n[Memori Percakapan Terdahulu Pengguna]:\n{persisted_memory.strip()}")

        if rag_items:
            knowledge_blocks = []
            for item in rag_items:
                title = item.get("title", "Pengetahuan Konseling")
                content = item.get("content", "")[:180]
                knowledge_blocks.append(f"- {title}: {content}")
            prompt_parts.append(
                "\n[Referensi Pengetahuan Konseling (Hanya gunakan secara alami jika relevan, jangan dibacakan kaku)]:\n"
                + "\n".join(knowledge_blocks)
            )

        # Layer 3 — Safety & Grounding
        temporal = getattr(emotion, "temporal_snapshot", None)
        if temporal is not None and temporal.status in (EmotionWindowStatus.READY, EmotionWindowStatus.PARTIAL) and temporal.primary_emotion:
            dur_s = round(temporal.speech_analyzed_ms / 1000.0, 1)
            cov_pct = int(round(temporal.coverage * 100))
            acoustic_line = (
                f"- Sinyal akustik suara tentatif (status={temporal.status.value}, durasi_valid={dur_s}s, cakupan={cov_pct}%): "
                f"indikasi cenderung '{temporal.primary_emotion}' (skor model {int(round((temporal.confidence or 0.0) * 100))}%). "
                "Sinyal ini bersifat tentatif dan dapat keliru; DILARANG menyatakan pasti seperti 'kamu pasti sedih'. "
                "Jika ucapan/teks pengguna berbeda dengan nada suara, SELALU utamakan pengakuan langsung pengguna dan lakukan klarifikasi lembut bila wajar."
            )
        elif temporal is not None or getattr(emotion, "source", None) == EmotionSource.UNAVAILABLE:
            acoustic_line = (
                "- Sinyal akustik suara belum tersedia pada giliran ini. "
                "Tanggapi sepenuhnya berdasarkan ucapan dan konteks percakapan pengguna secara empatik tanpa berasumsi tentang nada suara."
            )
        else:
            acoustic_line = (
                f"- Observasi emosi pengguna (tentatif): '{emotion.primary_emotion}' (skor model {int(emotion.confidence * 100)}%). "
                "Jangan pernah memperlakukan hasil deteksi sebagai fakta mutlak; utamakan pernyataan langsung pengguna dan gunakan bahasa yang tentatif."
            )

        effective_risk_level = (
            safety_decision.risk_level
            if safety_decision.risk_level in ("high", "critical")
            else ("high" if (is_crisis or is_crisis_session) else safety_decision.risk_level)
        )

        prompt_parts.extend([
            "\n[LAYER 3 — SAFETY & GROUNDING]",
            f"- Status Risiko: '{effective_risk_level}'. Kebijakan respon: '{safety_decision.response_policy}'.",
            acoustic_line,
        ])

        crisis_block = self._compose_crisis_guidance_block(
            is_crisis=is_crisis,
            is_crisis_session=is_crisis_session,
            risk_level=effective_risk_level,
        )
        if crisis_block:
            prompt_parts.append(crisis_block)

        if dass_scores:
            dep = dass_scores.get("depression", 0)
            anx = dass_scores.get("anxiety", 0)
            st = dass_scores.get("stress", 0)
            if dep > 0 or anx > 0 or st > 0:
                prompt_parts.append(
                    f"- Profil Skrining DASS-21 Pengguna: Depresi ({dep}), Kecemasan ({anx}), Stres ({st}). "
                    "Gunakan profil ini untuk menyelaraskan kehangatan dan kepekaan empati. "
                    "DILARANG KERAS menyebutkan skor, angka, skala, atau istilah kuesioner kepada pengguna."
                )

        # Layer 4 — Bahasa Indonesia Percakapan (Spoken Indonesian)
        if is_crisis or is_crisis_session:
            prompt_parts.extend([
                "\n[LAYER 4 — BAHASA INDONESIA PERCAKAPAN (SPOKEN INDONESIAN)]",
                "- Panjang respons: Default 2 hingga 3 kalimat pendek, lembut, tenang, dan mengalir alami untuk panggilan telepon suara.",
                "- Utamakan kehadiran emosional, validasi hangat, dan grounding; hindari kata-kata bernada menghakimi, terburu-buru, atau bercanda.",
                "- Jangan mengajukan pertanyaan bertubi-tubi; cukup paling banyak satu pertanyaan lembut yang aman bila perlu.",
            ])
        else:
            prompt_parts.extend([
                "\n[LAYER 4 — BAHASA INDONESIA PERCAKAPAN (SPOKEN INDONESIAN)]",
                "- Panjang respons: Default 1 hingga 3 kalimat pendek dan mengalir alami untuk panggilan telepon suara interaktif.",
                "- Responsif pada maksud pengguna. Hindari pembuka template berulang seperti 'Aku mengerti perasaanmu' atau formula mekanis 'validasi + saran + pertanyaan' di setiap respons.",
                "- Selipkan MAKSIMAL SATU pertanyaan lanjutan terbuka yang relevan bila benar-benar diperlukan. Boleh tanpa pertanyaan sama sekali jika situasi membutuhkan ketenangan atau kehadiran mendengarkan.",
                "- Gunakan bahasa percakapan yang hidup dan luwes. Boleh menggunakan kata santai yang wajar (seperti 'nggak', 'udah', 'kok', 'banget') sesuai kenyamanan pengguna tanpa dipaksa kaku.",
            ])

        # Layer 5 — Delivery Suara & Audio Tags (ElevenLabs v4 Turbo)
        enable_audio_tags = getattr(settings, "TTS_ENABLE_AUDIO_TAGS", True)
        if enable_audio_tags:
            from packages.ai.utils.emotion_style_mapper import map_emotion_to_delivery_style
            style, tag = map_emotion_to_delivery_style(
                detected_emotion=emotion.primary_emotion,
                confidence=emotion.confidence,
                risk_level=effective_risk_level,
            )
            hint_desc = f"rekomendasi nada: {style}" + (f" (tag opsi: {tag})" if tag else " (tanpa tag)")
            prompt_parts.extend([
                "\n[LAYER 5 — DELIVERY SUARA & AUDIO TAGS (ELEVENLABS v4 TURBO)]",
                f"- Petunjuk Delivery Giliran Ini: {hint_desc}. Gunakan jika membantu intonasi, atau keluarkan teks biasa tanpa tag jika sudah terasa alami.",
                "- Audio tags bersifat OPSIONAL. Utamakan teks yang bernada baik dan tanda baca alami (koma, titik, elipsis ... untuk jeda napas alami).",
                "- Jika menyisipkan tag, gunakan MAKSIMAL SATU tag di awal kalimat/klausa dari pilihan aman: [softly], [warmly], [calm], [thoughtful], [curious].",
                "- DILARANG KERAS tag negatif atau meniru emosi buruk ([angry], [crying], [screaming]) dan dilarang tertawa ([chuckles], [laughing]) pada topik sedih/berat/krisis.",
                "- DILARANG tag visual fisik seperti [smiling] atau [nodding].",
                "- DILARANG simbol Markdown (*, **, #, -), emoji dekoratif, atau metadata teknis dalam teks percakapan.",
            ])

        return "\n".join(prompt_parts)

    async def _stream_crisis_sop_fallback(self) -> AsyncGenerator[str, None]:
        """Fallback deterministik saat stream LLM gagal atau kosong pada kondisi darurat."""
        words = CRISIS_SOP_MESSAGE.split(" ")
        for i in range(0, len(words), 3):
            yield " ".join(words[i:i + 3]) + " "
            await asyncio.sleep(0.02)

    async def _stream_with_crisis_fallback(
        self,
        messages: list[LLMMessage],
    ) -> AsyncGenerator[str, None]:
        """Stream respons LLM dinamis dengan fallback aman ke CRISIS_SOP_MESSAGE jika gagal/kosong."""
        has_content = False
        try:
            async for token in self.llm_provider.stream_response(messages):
                if token and token.strip():
                    has_content = True
                yield token
        except Exception as err:
            logger.error(f"⚠️ [ORCHESTRATOR CRISIS LLM FALLBACK] Stream error: {err}")
            if not has_content:
                async for fallback_chunk in self._stream_crisis_sop_fallback():
                    yield fallback_chunk
            return

        if not has_content:
            logger.warning("⚠️ [ORCHESTRATOR CRISIS LLM FALLBACK] Empty LLM stream; yielding CRISIS_SOP_MESSAGE")
            async for fallback_chunk in self._stream_crisis_sop_fallback():
                yield fallback_chunk

    async def prepare_turn(
        self,
        user_text: str,
        conversation_history: Optional[list[LLMMessage]] = None,
        audio_path: Optional[str] = None,
        dass_scores: Optional[dict[str, Any]] = None,
        user_name: Optional[str] = None,
        precomputed_emotion: Optional[EmotionDetectionResult] = None,
        structured_persisted_context: Optional[List[Dict[str, Any]]] = None,
        temporal_emotion: Optional[TemporalEmotionSnapshot] = None,
        allow_sync_audio_fallback: bool = True,
        is_crisis_session: bool = False,
    ) -> OrchestratedTurnResult:
        """Memproses seluruh evaluasi orkestrasi (Emosi -> Gejala -> Risiko -> RAG)

        dan mengembalikan OrchestratedTurnResult yang siap di-stream.
        """
        start_t = time.perf_counter()
        if settings.APP_ENV.lower() == "production":
            logger.info(f"🚀 [ORCHESTRATOR TURN START] User text: <redacted len={len(user_text)}>")
        else:
            logger.info(f"🚀 [ORCHESTRATOR TURN START] User text: \"{user_text}\" | User Name: {user_name or 'None'}")

        # 1. Deteksi Emosi (Temporal Snapshot, Precomputed, Voice Audio, atau Teks Fallback eksplisit)
        if temporal_emotion is not None:
            normalized_snap = (
                temporal_emotion
                if isinstance(temporal_emotion, TemporalEmotionSnapshot)
                else TemporalEmotionSnapshot.model_validate(temporal_emotion.model_dump())
            )
            if (
                normalized_snap.status in (EmotionWindowStatus.READY, EmotionWindowStatus.PARTIAL)
                and normalized_snap.scores
                and normalized_snap.primary_emotion
            ):
                conf = round(float(normalized_snap.confidence or 0.0), 4)
                emotion_res = EmotionDetectionResult(
                    primary_emotion=normalized_snap.primary_emotion,
                    confidence=conf,
                    intensity=conf,
                    secondary_emotion=normalized_snap.secondary_emotion,
                    scores=dict(normalized_snap.scores),
                    model_used=normalized_snap.model_version or "emotion2vec_plus_base",
                    latency_ms=0.0,
                    source=EmotionSource(normalized_snap.source.value),
                    status=EmotionWindowStatus(normalized_snap.status.value),
                    temporal_snapshot=normalized_snap,
                )
            else:
                # Explicit unavailable/text-only fallback: NEVER invoke sync audio model on live call path
                emotion_res = EmotionDetectionResult(
                    primary_emotion="unknown",
                    confidence=0.0,
                    intensity=0.0,
                    secondary_emotion=None,
                    scores={},
                    model_used="unavailable",
                    latency_ms=0.0,
                    source=EmotionSource.UNAVAILABLE,
                    status=EmotionWindowStatus(normalized_snap.status.value),
                    temporal_snapshot=normalized_snap,
                )
        elif precomputed_emotion is not None:
            emotion_res = precomputed_emotion
            logger.info(
                f"🎙️ [ORCHESTRATOR] Using precomputed emotion: '{emotion_res.primary_emotion}' "
                f"(conf: {emotion_res.confidence:.2f}, intensity: {getattr(emotion_res, 'intensity', 0.5):.2f})"
            )
        else:
            effective_audio_path = audio_path if allow_sync_audio_fallback else None
            emotion_res = self._detect_emotion(user_text, audio_path=effective_audio_path)


        # 2. Ekstraksi Gejala
        symptom_res = self.symptom_service.extract_symptoms(user_text)

        # 3. Penilaian Risiko & Gerbang Keamanan (Memperhitungkan Profil DASS-21)
        risk_input = RiskAssessmentInput(
            user_text=user_text,
            symptom_result=symptom_res,
            emotion_result=emotion_res,
            dass_scores=dass_scores,
        )
        risk_output = self.risk_service.assess(risk_input)

        safety_input = SafetyGateInput(risk_output=risk_output)
        safety_decision = self.safety_gate.evaluate_policy(safety_input)

        logger.info(
            f"🛡️ [ORCHESTRATOR SAFETY] Risk Level: {safety_decision.risk_level.upper()}, "
            f"Policy: {safety_decision.response_policy}, Mode: {safety_decision.mode}"
        )

        # 4. Evaluasi Skenario Krisis
        is_crisis = (
            safety_decision.mode == ResponseMode.CRISIS
            or safety_decision.llm_mode == LLMMode.NONE
            or safety_decision.response_policy in [ProtocolAction.IMMEDIATE_HOTLINE, ProtocolAction.CRISIS_REFERRAL]
        )
        crisis_care_active = is_crisis or is_crisis_session

        if is_crisis:
            logger.warning(
                "🚨 [ORCHESTRATOR CRISIS ACTIVATED] Routing to bounded dynamic crisis LLM guidance "
                f"(risk_level={safety_decision.risk_level})"
            )
        elif is_crisis_session:
            logger.info("🛡️ [ORCHESTRATOR ELEVATED CARE] Continuing active crisis session with careful dynamic prompt")

        # 5. RAG Retrieval jika diizinkan oleh Safety Policy DAN Intent Gating
        from packages.ai.services.rag_gating import RAGGatingService
        gating_res = RAGGatingService.evaluate_intent(user_text, is_crisis=crisis_care_active)

        rag_items: list[dict[str, Any]] = []
        if not crisis_care_active and safety_decision.allow_normal_rag and gating_res.should_retrieve_rag:
            logger.info(f"📚 [ORCHESTRATOR RAG ACTIVATED] Querying Qdrant for intent: {gating_res.intent.value}")
            rag_items = await self._fetch_rag_context(user_text)
        else:
            logger.info(f"📚 [ORCHESTRATOR RAG SKIPPED] Intent: {gating_res.intent.value} ({gating_res.reason})")

        # Extract persisted memory if present in conversation_history system message
        persisted_memory = None
        if conversation_history:
            for msg in conversation_history:
                if msg.role == "system" and "[Memori Percakapan Terdahulu Pengguna]:" in msg.content:
                    parts = msg.content.split("[Memori Percakapan Terdahulu Pengguna]:")
                    if len(parts) > 1:
                        persisted_memory = parts[1].strip()
                        if "[Profil Asesmen Psikologis DASS-21 Terkini Pengguna]:" in persisted_memory:
                            persisted_memory = persisted_memory.split("[Profil Asesmen Psikologis DASS-21 Terkini Pengguna]:")[0].strip()

        # 6. Formulasi Dynamic Empathetic Prompt
        system_prompt = self._compose_system_prompt(
            emotion_res,
            safety_decision,
            rag_items,
            dass_scores=dass_scores,
            user_name=user_name,
            persisted_memory=persisted_memory,
            structured_persisted_context=structured_persisted_context,
            is_crisis=is_crisis,
            is_crisis_session=is_crisis_session,
        )

        # 7. Siapkan Message History dengan Adaptive History Budgeting
        messages: list[LLMMessage] = [LLMMessage(role="system", content=system_prompt)]
        raw_turns: list[LLMMessage] = []
        if conversation_history:
            for msg in conversation_history:
                if msg.role != "system" and msg.content and msg.content.strip():
                    raw_turns.append(msg)

        # Retain recent turns verbatim (sliding window last 8 turns), summarize older if long
        if len(raw_turns) > 8:
            messages.append(
                LLMMessage(
                    role="system",
                    content=f"[Konteks Sesi Berjalan]: Sesi ini telah berlangsung {len(raw_turns)} giliran interaktif. Pertahankan kesinambungan cerita dan rujuk hal-hal yang telah dibicarakan sebelumnya secara konsisten.",
                )
            )
            messages.extend(raw_turns[-8:])
        else:
            messages.extend(raw_turns)

        # Pastikan user message saat ini ada di akhir
        if not messages or messages[-1].role != "user" or messages[-1].content != user_text:
            messages.append(LLMMessage(role="user", content=user_text))

        # 8. Siapkan Token Stream dari LLM Provider (dengan fallback SOP krisis bila mode darurat aktif)
        token_stream = (
            self._stream_with_crisis_fallback(messages)
            if crisis_care_active
            else self.llm_provider.stream_response(messages)
        )

        exec_time = (time.perf_counter() - start_t) * 1000
        logger.info(
            f"✅ [ORCHESTRATOR TURN READY] Ready in {exec_time:.2f}ms "
            f"(Emosi: {emotion_res.primary_emotion}, CrisisTurn: {is_crisis}, CrisisSession: {is_crisis_session})"
        )

        return OrchestratedTurnResult(
            user_text=user_text,
            emotion=emotion_res,
            symptoms=symptom_res,
            risk_output=risk_output,
            safety_decision=safety_decision,
            rag_items=rag_items,
            is_crisis=is_crisis,
            final_system_prompt=system_prompt,
            token_stream=token_stream,
            execution_time_ms=round(exec_time, 2),
        )

    async def stream_orchestrated_turn(
        self,
        user_text: str,
        conversation_history: Optional[list[LLMMessage]] = None,
        audio_path: Optional[str] = None,
    ) -> AsyncGenerator[str, None]:
        """Convenience generator yang langsung mengalirkan token balasan hasil orkestrasi."""
        turn = await self.prepare_turn(
            user_text=user_text,
            conversation_history=conversation_history,
            audio_path=audio_path,
        )
        async for token in turn.token_stream:
            yield token

    async def process_turn(
        self,
        user_input: str | bytes,
        history: Optional[list[LLMMessage]] = None,
        context: Optional[dict[str, Any]] = None,
    ) -> dict[str, Any]:
        """Eksekusi non-streaming (berguna untuk endpoint REST, worker, dan automated tests)."""
        text_input = user_input if isinstance(user_input, str) else "[Voice Audio]"
        turn = await self.prepare_turn(user_text=text_input, conversation_history=history)

        full_text_list = []
        async for token in turn.token_stream:
            full_text_list.append(token)
        response_text = "".join(full_text_list).strip()

        return {
            "input_text": text_input,
            "response_text": response_text,
            "emotion": turn.emotion.model_dump(),
            "symptoms": turn.symptoms.model_dump(),
            "risk_level": turn.safety_decision.risk_level,
            "safety_policy": str(turn.safety_decision.response_policy),
            "is_crisis": turn.is_crisis,
            "rag_items": turn.rag_items,
            "system_prompt": turn.final_system_prompt,
            "execution_time_ms": turn.execution_time_ms,
        }

    async def process_stream_turn(
        self,
        audio_stream: AsyncGenerator[bytes, None],
    ) -> AsyncGenerator[bytes, None]:
        """Unimplemented streaming-only interface; use prepare_turn instead."""
        raise NotImplementedError("process_stream_turn is not implemented; use prepare_turn.")
        if False:
            yield b""
