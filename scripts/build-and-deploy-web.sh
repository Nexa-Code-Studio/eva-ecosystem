#!/usr/bin/env bash
set -e

# ==============================================================================
# Script: build-and-deploy-web.sh
# Purpose: Build and deploy Eva Web (React 19 & Vite) to /var/www/eva-web
# Usage:
#   ./build-and-deploy-web.sh               # Full build & deploy
#   ./build-and-deploy-web.sh --build-only  # Only compile web release
#   ./build-and-deploy-web.sh --deploy-only # Only copy dist to /var/www
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/../apps/web" && pwd)"
BUILD_DIR="$APP_DIR/dist"
WEB_ROOT="/var/www/eva-web"
DOMAIN="eva.nexacode.dev"

export CI=true

MODE="all"
if [ "${1:-}" = "--build-only" ]; then
    MODE="build"
elif [ "${1:-}" = "--deploy-only" ]; then
    MODE="deploy"
fi

# 1. Build Phase
if [ "$MODE" = "all" ] || [ "$MODE" = "build" ]; then
    if ! command -v npm >/dev/null 2>&1; then
        echo "Error: npm binary not found in PATH!"
        exit 1
    fi

    echo "==> [1/3] Fetching dependencies for Eva Web..."
    (cd "$APP_DIR" && npm install)

    echo "==> [2/3] Building Eva Web (production mode)..."
    (cd "$APP_DIR" && VITE_ENABLE_DEMO=false npm run build)

    echo "==> Build successful: $BUILD_DIR"
fi

# 2. Deploy Phase
if [ "$MODE" = "all" ] || [ "$MODE" = "deploy" ]; then
    if [ ! -d "$BUILD_DIR" ]; then
        echo "Error: Build directory $BUILD_DIR does not exist. Run with --build-only first."
        exit 1
    fi

    echo "==> [3/3] Deploying to $WEB_ROOT..."
    mkdir -p "$WEB_ROOT"
    rm -rf "${WEB_ROOT:?}"/*
    cp -r "$BUILD_DIR"/* "$WEB_ROOT/"

    if command -v chown >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
        chown -R www-data:www-data "$WEB_ROOT"
        chmod -R 755 "$WEB_ROOT"
    fi

    if command -v systemctl >/dev/null 2>&1; then
        echo "==> Reloading Nginx..."
        systemctl reload nginx || true
    fi

    echo "==> Validating deployment..."
    STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/" 2>/dev/null || echo "000")
    HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$DOMAIN/health" 2>/dev/null || echo "000")

    echo "    - Web Root (https://$DOMAIN/): HTTP $STATUS_CODE"
    echo "    - Backend (https://$DOMAIN/health): HTTP $HEALTH_CODE"

    if [ "$STATUS_CODE" = "200" ] && [ "$HEALTH_CODE" = "200" ]; then
        echo "==> Deployment completed successfully!"
    else
        echo "==> Note: Check nginx configuration if endpoints returned non-200 status code."
    fi
fi
