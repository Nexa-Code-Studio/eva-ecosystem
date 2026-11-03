---
name: monorepo-ops
description: Run operational tasks for the monorepo using the full Docker environment including development/production stacks, database migrations with Alembic, database resets, and backend service runners.
---

# Monorepo Operations Runbook (Full Docker)

This skill guides you through executing common development and operational workflows across the backend, workers, database, and infrastructure via **100% Docker commands**.

## 1. Development Environment Startup

All backend services, workers, database, cache, and vector store run inside Docker:

```bash
# Interactive development mode (FastAPI, FastMCP, ARQ, PostgreSQL, Redis, Qdrant)
make dev

# Background detached development mode
make dev-d

# Rebuild containers
make dev-build

# Stream logs
make logs
make logs-api
make logs-worker
```

## 2. Production Stack

```bash
# Start production stack
make prod

# Stop production stack
make prod-down

# View production logs
make logs-prod
```

## 3. Database & Migrations (PostgreSQL + Alembic)

All migrations and seeders execute inside the Docker environment without requiring local Python virtual environments:

```bash
# Run pending migrations
make migrate

# Generate a new migration
make migration-gen m="describe_changes"

# Reset database & re-seed data
make db-reset

# Run standalone seeders
make seed

# Open interactive PostgreSQL shell (psql)
make db-shell
```

## 4. Tests & Quality Checks

```bash
# Run backend & AI package tests via Docker
make test-backend

# Run mobile tests
make test-mobile

# Linting & Formatting
make lint
make format
```
