#!/usr/bin/env bash
set -e

echo "🔄 Resetting Eva AI Database & Re-seeding via Docker..."

# Execute DB reset inside the running or ephemeral api container
if docker compose ps --services 2>/dev/null | grep -q "^api$"; then
    docker compose exec -T api python -m app.db.reset
else
    echo "==> API container not running. Running ephemeral container..."
    docker compose run --rm api python -m app.db.reset
fi

echo "✅ Database reset & re-seeding completed successfully!"
