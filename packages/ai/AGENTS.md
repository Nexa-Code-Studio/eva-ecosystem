# AI Package & Orchestration - Sub-Workspace Rules

> Scope: `packages/ai/**`

## 1. Provider Abstraction & Interface Enforcement
- All AI connectors (LLM, TTS, STT, Vector Store) must implement an abstract interface defined in `packages/ai/interfaces/` using `abc.ABC` and `@abstractmethod`.
- Existing interfaces:
  - `BaseLLMProvider` in `interfaces/llm.py`
  - `BaseTTSProvider` in `interfaces/tts.py`
  - `BaseSTTProvider` in `interfaces/stt.py`
  - `BaseVectorStore` in `interfaces/vector_store.py`

## 2. Factory Pattern & Environment Fallback
- Instantiate providers exclusively through factories (`LLMFactory`, `TTSFactory`).
- **Development Fallback**: In `development` mode, if API keys are missing or contain placeholder values, smoothly fallback to Mock or free providers (`MockLLMProvider`, `EdgeTTSProvider`).
- **Production Fail-Fast**: In `production` mode (`APP_ENV=production`), raise informative configuration exceptions at startup if required provider keys are missing.

## 3. Safety & RAG Principles
- Safety gates (`services/safety_gate.py`) and risk assessment (`services/risk_assessment_service.py`) must evaluate inputs before sensitive agent actions.
- Qdrant vector retrieval (`vector_store/qdrant.py`) must be guarded by `rag_gating.py` to avoid unnecessary vector search latency.
