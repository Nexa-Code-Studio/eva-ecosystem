# Project Rules & Token Optimization Guidelines for Eva AI

> **Purpose:** Guidelines for AI agents (Antigravity) to maintain high code quality while minimizing token consumption.

---

## 1. Documentation & Lazy Reading (Just-In-Time Context)

- **Do NOT read large doc files upfront**: Do not pre-load entire documentation files (e.g. `docs/ai_counseling_business_logic.md`) unless specifically required for the task.
- **Selective Reading**: Read `docs/` files strictly on demand when working on relevant features:
  - Working on overall system topology/monorepo setup? Read `docs/architecture.md`.
  - Working on counseling logic, safety gates, risk worker, or diary synthesis? Read specific line ranges of `docs/ai_counseling_business_logic.md`.
  - Working on FastAPI, PostgreSQL models, FastMCP tools, ARQ workers, or Qdrant vector DB? Read `docs/backend_spec.md`.
  - Working on Flutter mobile, Riverpod providers, Clean Architecture layers, or `AppConfig.useMockData` toggle? Read `docs/mobile_spec.md`.
- **Use Line Ranges**: When inspecting large documents or files, always supply `StartLine` and `EndLine` parameters to read only the target section instead of dumping 800+ lines.

---

## 2. Search & Code Inspection (Targeted Retrieval)

- **Grep Before Reading**: Use `grep_search` or `list_dir` to pinpoint exact filenames, class names, or function definitions before using `view_file`.
- **No Blind Inferences**: Inspect actual type signatures and definitions before calling functions or instantiating classes.
- **Surgical Edits**: Make precise, targeted modifications. Do not rewrite unaffected files or duplicate standard boilerplate.

---

## 3. Codebase Standards & Architecture Constraints

- **Strict Abstraction & Mock vs Prod Switching**:
  - High-level modules (Flutter UI and FastAPI route handlers) must **never** couple directly with mock or concrete cloud services.
  - See [.agents/rules/abstraction-and-mock-prod.md](file:///home/mashupsoat/Project/eva-ecosystem/.agents/rules/abstraction-and-mock-prod.md) for detailed rules.
- **Sweet-Spot Cohesion & Modularity**:
  - Keep files cohesive; extract independent timers, custom painters, and multi-step modals into dedicated widget files while keeping local layout together.
  - See [.agents/rules/cohesion-and-modularity.md](file:///home/mashupsoat/Project/eva-ecosystem/.agents/rules/cohesion-and-modularity.md) for natural separation criteria.
- **Hierarchical Workspace Scopes**:
  - Flutter Mobile: Follow [apps/eva_mobile/AGENTS.md](file:///home/mashupsoat/Project/eva-ecosystem/apps/eva_mobile/AGENTS.md) (Clean Architecture, Riverpod DI, Pure Dart models).
  - Backend API: Follow [apps/backend/AGENTS.md](file:///home/mashupsoat/Project/eva-ecosystem/apps/backend/AGENTS.md) (FastAPI routes, Pydantic schemas, Alembic migrations, FastMCP).
  - AI & Orchestration: Follow [packages/ai/AGENTS.md](file:///home/mashupsoat/Project/eva-ecosystem/packages/ai/AGENTS.md) (Abstract Base Classes, LLM/TTS factories, graceful fallbacks).
- **Available Skills**:
  - `monorepo-ops`: Docker dev/prod, Alembic migrations, database resets, and backend service runner.
  - `flutter-workflow`: Flutter profile runs (Mock, Local API, Production), analysis, and tests.
  - `text-to-speech`: ElevenLabs voice AI integration.
- **State & Code Style**:
  - Write concise, clean, typed code without verbose redundant comments.
  - Do not introduce heavy dependencies without user confirmation.

---

## 4. Response & Output Efficiency

- **Concise Summaries**: Keep natural language explanations clear, direct, and compact.
- **No Redundant Re-summarizations**: After creating/editing artifacts, provide a high-level summary and direct link without duplicating the full content in chat prose.
