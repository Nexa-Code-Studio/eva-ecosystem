import pytest
from ai.orchestration.orchestrator import AIOrchestrator, CRISIS_SOP_MESSAGE
from ai.interfaces.llm import BaseLLMProvider, LLMMessage
from shared.domain_types import ResponseMode


class MockLLMProvider(BaseLLMProvider):
    """Mock LLM Provider for deterministic orchestration testing."""

    async def generate_response(self, messages: list[LLMMessage], **kwargs) -> str:
        return "Halo, aku mendengar ceritamu dan memahami perasaanmu saat ini."

    async def stream_response(self, messages: list[LLMMessage], **kwargs):
        tokens = ["Halo,", " aku", " mendengar", " ceritamu", " dengan", " baik."]
        for t in tokens:
            yield t


@pytest.mark.asyncio
async def test_orchestrator_normal_turn():
    mock_llm = MockLLMProvider()
    orchestrator = AIOrchestrator(llm_provider=mock_llm)

    user_text = "Wah, akhirnya selesai juga! Aku senang banget hari ini!"
    turn = await orchestrator.prepare_turn(user_text=user_text)

    assert turn.is_crisis is False
    assert turn.emotion.primary_emotion == "happy"
    assert turn.risk_output.risk_level in ["none", "low"]
    assert "Eva" in turn.final_system_prompt or "Luna" in turn.final_system_prompt
    assert "happy" in turn.final_system_prompt

    tokens = []
    async for token in turn.token_stream:
        tokens.append(token)
    assert len(tokens) > 0
    assert "".join(tokens) == "Halo, aku mendengar ceritamu dengan baik."


@pytest.mark.asyncio
async def test_orchestrator_symptom_turn():
    mock_llm = MockLLMProvider()
    orchestrator = AIOrchestrator(llm_provider=mock_llm)

    user_text = "Aku merasa cemas dan susah tidur hampir tiap malam, lelah rasanya."
    turn = await orchestrator.prepare_turn(user_text=user_text)

    assert turn.is_crisis is False
    # Check that symptom extraction identified sleep/fatigue/anxiety
    symptom_codes = [s.symptom_code for s in turn.symptoms.extracted_symptoms]
    assert "sleep_disturbance" in symptom_codes or "fatigue" in symptom_codes
    assert turn.emotion.primary_emotion in ["fearful", "sad"]


@pytest.mark.asyncio
async def test_orchestrator_crisis_safeguard():
    mock_llm = MockLLMProvider()
    orchestrator = AIOrchestrator(llm_provider=mock_llm)

    # Triggering explicit suicidal plan
    user_text = "Aku sudah tidak sanggup lagi, aku mau bunuh diri malam ini."
    turn = await orchestrator.prepare_turn(user_text=user_text)

    # Must be intercepted by Safety Gate as CRISIS
    assert turn.is_crisis is True
    assert turn.safety_decision.mode == ResponseMode.CRISIS
    assert turn.rag_items == []

    # Stream should invoke dynamic LLM with bounded emergency prompt (no static bypass)
    assert "MODE DARURAT AKTIF" in turn.final_system_prompt
    assert "grounding" in turn.final_system_prompt
    tokens = []
    async for token in turn.token_stream:
        tokens.append(token)
    full_output = "".join(tokens).strip()

    assert full_output == "Halo, aku mendengar ceritamu dengan baik."


@pytest.mark.asyncio
async def test_orchestrator_crisis_llm_failure_falls_back_to_sop():
    class FailingLLM(BaseLLMProvider):
        async def generate_response(self, messages: list[LLMMessage], **kwargs) -> str:
            raise RuntimeError("LLM offline")

        async def stream_response(self, messages: list[LLMMessage], **kwargs):
            if False:
                yield ""
            raise RuntimeError("LLM offline")

    orchestrator = AIOrchestrator(llm_provider=FailingLLM())
    turn = await orchestrator.prepare_turn(
        user_text="Aku capek hidup, pengen mengakhiri semuanya.",
    )
    assert turn.is_crisis is True
    tokens = []
    async for token in turn.token_stream:
        tokens.append(token)
    full_output = "".join(tokens).strip()
    assert "119 ekstensi 8" in full_output
    assert "LISA" in full_output


@pytest.mark.asyncio
async def test_orchestrator_crisis_session_keeps_elevated_care_on_followup():
    mock_llm = MockLLMProvider()
    orchestrator = AIOrchestrator(llm_provider=mock_llm)

    turn = await orchestrator.prepare_turn(
        user_text="Iya, aku lagi di kamar sendirian sekarang.",
        is_crisis_session=True,
    )

    assert turn.is_crisis is False
    assert turn.rag_items == []
    assert "MODE DARURAT LANJUTAN" in turn.final_system_prompt
    assert "grounding" in turn.final_system_prompt


@pytest.mark.asyncio
async def test_orchestrator_process_turn_convenience():
    mock_llm = MockLLMProvider()
    orchestrator = AIOrchestrator(llm_provider=mock_llm)

    result = await orchestrator.process_turn("Hari ini biasa saja.")
    assert "response_text" in result
    assert "emotion" in result
    assert "symptoms" in result
    assert result["is_crisis"] is False


@pytest.mark.asyncio
async def test_orchestrator_structured_persisted_context():
    mock_llm = MockLLMProvider()
    orchestrator = AIOrchestrator(llm_provider=mock_llm)

    context = [
        {"category": "coping_strategy", "text": "Jalan pagi di taman membantu menenangkan pikiran"},
        {"category": "interaction_preference", "text": "Lebih suka didengarkan dahulu"},
    ]
    turn = await orchestrator.prepare_turn(
        user_text="Halo Eva, aku mau cerita hari ini.",
        structured_persisted_context=context,
    )

    assert "Fakta Konteks Personal Pengguna" in turn.final_system_prompt
    assert "Jalan pagi di taman membantu menenangkan pikiran" in turn.final_system_prompt
    assert "Lebih suka didengarkan dahulu" in turn.final_system_prompt
    assert turn.is_crisis is False

