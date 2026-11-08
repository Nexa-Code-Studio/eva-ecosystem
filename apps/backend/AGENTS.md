# Backend (FastAPI, MCP & Workers) - Sub-Workspace Rules

> Scope: `apps/backend/**`  
> Mandat Arsitektur: Wajib mematuhi [.agents/rules/backend-clean-architecture.md](file:///home/mashupsoat/Project/eva-ecosystem/.agents/rules/backend-clean-architecture.md)

## 1. Directory & Code Organization
- **API (`apps/backend/api`)**:
  - **Routes (`app/api/routes`)**: Thin Controllers (3–5 baris per endpoint). Hanya mendeklarasikan HTTP path, `response_model`, dan delegasi ke service.
  - **Centralized Dependencies (`app/api/dependencies.py`)**: Seluruh dependency (`get_current_user`, `get_db_session`, service factories) dipusatkan di sini. Dilarang duplikasi `_get_current_user` di file route.
  - **Modular Schemas (`app/schemas/{module}/`)**: Kontrak Pydantic per domain (`requests.py`, `responses.py`, dan `__init__.py` barrel export). Dilarang mengembalikan `dict[str, Any]` tanpa Pydantic schema.
  - **Modular Domain Services (`app/services/{module}/`)**: Logika bisnis, transaksi database, dan orkestrasi per domain (`{name}_service.py` dan `__init__.py`).
  - **Database Models (`app/models`)**: SQLAlchemy ORM models dan declarative base.
  - **Database Sessions & Seeders (`app/db`)**: Engine konfigurasi dan master data seeding.
- **MCP (`apps/backend/mcp`)**:
  - FastMCP tool definitions in `app/tools`
  - Completely decoupled from direct HTTP router dependencies.
- **Workers (`apps/backend/workers`)**:
  - Async ARQ task definitions in `app/tasks` and worker loop in `app/workers`.

## 2. Abstraction & Dependency Injection
- Never instantiate database sessions (`AsyncSessionLocal()`), AI provider classes (`LLMFactory`), or services directly inside route handlers.
- Always inject via FastAPI `Depends()`:
  - User Identity: `user: User = Depends(get_current_user)` (dari `app.api.dependencies`)
  - Database: `db: AsyncSession = Depends(get_db_session)`
  - Domain Services: `service: AuthService = Depends(get_auth_service)`
  - AI Providers: `llm: BaseLLMProvider = Depends(get_llm_provider)`
- Services must be decoupled from FastAPI request/response lifecycle where possible to allow worker reuse.

## 3. Thin Router Invariant (3–5 Baris per Endpoint)
- Dilarang menulis raw SQL queries (`select()`, `db.execute()`, `db.commit()`) di dalam router handler.
- Dilarang melakukan kalkulasi emosi, validasi password manual, atau pembuatan token JWT di dalam router handler.
- Router hanya bertugas menerima request, memicu method service, dan mengembalikan response model Pydantic yang valid.

## 4. Database & Migrations
- Use Alembic for all schema changes (`alembic revision --autogenerate -m "..."`).
- Never perform raw schema alterations in production migrations.
- Test queries using async SQLAlchemy patterns (`select()`, `scalars()`).

## 5. Service Cohesion & Separation of Concerns
- Modul berat (*heavyweight modules*) seperti voice call (`app/services/call/`) wajib memisahkan I/O real-time (WebSockets, audio streaming, turn detection) dari transaksi persistensi database (`persistence.py`). Seluruh koneksi WebSocket di router wajib didelegasikan langsung ke `call_session_manager.handle_connection`.
- Modul emosi (`app/services/emotion/`) wajib memisahkan detektor ML (`ml_detector.py`) dari heuristik fallback / formatting (`analyzer.py`).
