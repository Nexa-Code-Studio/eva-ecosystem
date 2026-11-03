.PHONY: help dev dev-d dev-build dev-api dev-mcp dev-worker prod prod-down logs logs-api logs-worker logs-prod ps down db-shell migrate migration-gen db-reset seed mobile-usb mobile-emu mobile-mock mobile-web web-dev web-build web-lint test test-backend test-mobile lint format

help:
	@echo "EVA Ecosystem Management Commands (Full Docker Environment):"
	@echo ""
	@echo "  Docker Development Stack:"
	@echo "    make dev           - Jalankan seluruh stack dev Docker interaktif (Ctrl+C auto down)"
	@echo "    make dev-d         - Jalankan stack dev Docker di background (detached)"
	@echo "    make dev-build     - Rebuild seluruh image container Docker & jalankan"
	@echo "    make dev-api       - Jalankan container API saja (FastAPI :8888)"
	@echo "    make dev-mcp       - Jalankan container MCP saja (FastMCP :8889)"
	@echo "    make dev-worker    - Jalankan container ARQ Worker saja"
	@echo "    make logs          - Streaming log seluruh container dev"
	@echo "    make logs-api      - Streaming log container eva_api"
	@echo "    make logs-worker   - Streaming log container eva_worker"
	@echo ""
	@echo "  Docker Production Stack:"
	@echo "    make prod          - Rebuild & jalankan stack production"
	@echo "    make prod-down     - Matikan stack production"
	@echo "    make logs-prod     - Streaming log stack production"
	@echo ""
	@echo "  Docker General & Database Management:"
	@echo "    make ps            - Cek status container dev dan prod"
	@echo "    make down          - Hentikan seluruh container"
	@echo "    make db-shell      - Buka shell psql interaktif di PostgreSQL eva_ai"
	@echo "    make migrate       - Jalankan migrasi Alembic via Docker (upgrade head)"
	@echo "    make migration-gen - Buat migrasi baru (contoh: make migration-gen m=\"add_table\")"
	@echo "    make db-reset      - Reset database penuh dan re-seeding data via Docker"
	@echo "    make seed          - Jalankan seeder akun & mental health knowledge via Docker"
	@echo ""
	@echo "  Mobile Applications (Eva Mobile):"
	@echo "    make mobile-usb    - Jalankan Eva Mobile di HP Fisik via USB (auto adb reverse 8888)"
	@echo "    make mobile-emu    - Jalankan Eva Mobile di Android Emulator (route 10.0.2.2:8888)"
	@echo "    make mobile-mock   - Jalankan Eva Mobile dengan Mock Data lokal"
	@echo "    make mobile-web    - Jalankan Eva Mobile di Chrome Web Simulator"
	@echo ""
	@echo "  Web Application (Eva Web Portal):"
	@echo "    make web-dev       - Jalankan server development Vite apps/web (port 5174)"
	@echo "    make web-build     - Jalankan build produksi apps/web (tsc -b && vite build)"
	@echo "    make web-lint      - Jalankan code linter ESLint untuk apps/web"
	@echo ""
	@echo "  Testing & Code Quality:"
	@echo "    make test          - Jalankan seluruh test suite (Backend via Docker & Mobile)"
	@echo "    make test-backend  - Jalankan pytest untuk API dan AI package di dalam Docker"
	@echo "    make test-mobile   - Jalankan flutter test untuk Eva Mobile"
	@echo "    make lint          - Jalankan code linter (ruff via Docker & flutter analyze)"
	@echo "    make format        - Format otomatis seluruh kode (ruff via Docker & dart format)"

# ------------------------------------------------------------------------------
# Docker Development Mode
# ------------------------------------------------------------------------------
dev:
	@./scripts/docker-dev.sh

dev-d:
	docker compose up -d

dev-build:
	docker compose up --build

dev-api:
	docker compose up api

dev-mcp:
	docker compose up mcp

dev-worker:
	docker compose up worker

logs:
	docker compose logs -f

logs-api:
	docker compose logs -f api

logs-worker:
	docker compose logs -f worker

# ------------------------------------------------------------------------------
# Docker Production Mode
# ------------------------------------------------------------------------------
prod:
	@./scripts/docker-prod.sh up

prod-down:
	@./scripts/docker-prod.sh down

logs-prod:
	docker compose -f docker-compose.prod.yml logs -f

# ------------------------------------------------------------------------------
# Docker General & Database Management
# ------------------------------------------------------------------------------
ps:
	docker compose ps
	@echo ""
	docker compose -f docker-compose.prod.yml ps 2>/dev/null || true

down:
	docker compose down
	docker compose -f docker-compose.prod.yml down 2>/dev/null || true

db-shell:
	docker compose exec postgres psql -U postgres -d eva_ai

migrate:
	docker compose exec -T api alembic upgrade head

migration-gen:
	@if [ -z "$(m)" ]; then echo "Error: sertakan deskripsi migrasi, contoh: make migration-gen m=\"add_table\""; exit 1; fi
	docker compose exec -T api alembic revision --autogenerate -m "$(m)"

db-reset:
	@./scripts/reset_db.sh

seed:
	docker compose exec -T api python -m app.db.seed

# ------------------------------------------------------------------------------
# Mobile Applications Runner (Physical USB / Emulator / Mock / Web)
# ------------------------------------------------------------------------------
mobile-usb:
	@./scripts/run_mobile.sh usb $(ARGS)

mobile-emu:
	@./scripts/run_mobile.sh emu $(ARGS)

mobile-mock:
	@./scripts/run_mobile.sh mock $(ARGS)

mobile-web:
	@./scripts/run_mobile.sh web $(ARGS)

# ------------------------------------------------------------------------------
# Web Application Runner & Build (React & Vite)
# ------------------------------------------------------------------------------
web-dev:
	cd apps/web && npm run dev

web-build:
	cd apps/web && npm run build

web-lint:
	cd apps/web && npm run lint

# ------------------------------------------------------------------------------
# Testing & Code Quality
# ------------------------------------------------------------------------------
test: test-backend test-mobile

test-backend:
	docker compose exec -T -w /workspace api pytest apps/backend/api/tests packages/ai/tests

test-mobile:
	cd apps/eva_mobile && flutter test

lint:
	docker compose exec -T api ruff check . 2>/dev/null || ruff check .
	cd apps/eva_mobile && flutter analyze
	cd apps/web && npm run lint

format:
	docker compose exec -T api ruff format . 2>/dev/null || ruff format .
	cd apps/eva_mobile && dart format .
