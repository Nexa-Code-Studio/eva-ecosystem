# Backend (FastAPI, MCP & Workers) - Sub-Workspace Rules

> Scope: `apps/backend/**`

## 1. Directory & Code Organization
- **API (`apps/backend/api`)**:
  - Routes in `app/api/routes`
  - SQLAlchemy models in `app/models`, Pydantic schemas in `app/schemas`
  - Domain business services in `app/services`
  - Database sessions and engine in `app/db`
- **MCP (`apps/backend/mcp`)**:
  - FastMCP tool definitions in `app/tools`
  - Completely decoupled from direct HTTP router dependencies.
- **Workers (`apps/backend/workers`)**:
  - Async ARQ task definitions in `app/tasks` and worker loop in `app/workers`.

## 2. Abstraction & Dependency Injection
- Never instantiate database sessions or AI provider classes directly inside route handlers.
- Always inject via FastAPI `Depends()`:
  - Database: `db: AsyncSession = Depends(get_db_session)`
  - AI Providers: `llm: BaseLLMProvider = Depends(get_llm_provider)`
- Services must be decoupled from FastAPI request/response lifecycle where possible to allow worker reuse.

## 3. Database & Migrations
- Use Alembic for all schema changes (`alembic revision --autogenerate -m "..."`).
- Never perform raw schema alterations in production migrations.
- Test queries using async SQLAlchemy patterns (`select()`, `scalars()`).

## 4. Service Cohesion & Separation of Concerns
- Separate real-time event dispatching (WebSockets, streaming audio) from database persistence transactions.
- Keep route handlers focused on validation and delegating to services without inline SQL queries.
