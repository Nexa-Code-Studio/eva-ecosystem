#!/usr/bin/env bash
# ==============================================================================
# Script: build_mobile_web.sh
# Purpose: Build Eva Mobile (Flutter Web) in Hybrid / API mode for GitHub Pages or local testing
# Usage:
#   ./scripts/build_mobile_web.sh
#   BASE_HREF="/" ./scripts/build_mobile_web.sh
#   API_BASE_URL="https://eva.nexacode.dev/api/v1" ./scripts/build_mobile_web.sh
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${ROOT_DIR}/apps/eva_mobile"

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

BASE_HREF="${BASE_HREF:-/eva-ecosystem/}"
API_BASE_URL="${API_BASE_URL:-https://eva.nexacode.dev/api/v1}"
FALLBACK_HYBRID="${FALLBACK_HYBRID:-true}"

echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
echo -e "${BOLD}${CYAN}        EVA MOBILE — FLUTTER WEB BUILDER (HYBRID API MODE)                      ${NC}"
echo -e "${BOLD}${CYAN}================================================================================${NC}\n"

echo -e "${CYAN}Configuration:${NC}"
echo -e "  - Base Href      : ${BOLD}${BASE_HREF}${NC}"
echo -e "  - API Base URL   : ${BOLD}${API_BASE_URL}${NC}"
echo -e "  - Hybrid Fallback: ${BOLD}${FALLBACK_HYBRID}${NC}"
echo ""

# Find flutter binary
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
if ! command -v "${FLUTTER_BIN}" >/dev/null 2>&1; then
    if [ -x "/home/mashupsoat/development/flutter/bin/flutter" ]; then
        FLUTTER_BIN="/home/mashupsoat/development/flutter/bin/flutter"
    else
        echo -e "${RED}[ERROR] Flutter executable not found in PATH!${NC}"
        echo -e "Pastikan Flutter SDK terpasang dan dapat diakses."
        exit 1
    fi
fi

cd "${APP_DIR}"

echo -e "${GREEN}==> Mengambil dependensi Flutter...${NC}"
"${FLUTTER_BIN}" pub get

echo -e "${GREEN}==> Mengompilasi Flutter Web (Release Mode)...${NC}"
"${FLUTTER_BIN}" build web --release \
    --base-href "${BASE_HREF}" \
    --dart-define=USE_LOCAL_API=false \
    --dart-define=USE_HYBRID_FALLBACK="${FALLBACK_HYBRID}" \
    --dart-define=HYBRID="${FALLBACK_HYBRID}" \
    --dart-define=API_BASE_URL="${API_BASE_URL}"

BUILD_DIR="${APP_DIR}/build/web"

echo -e "${GREEN}==> Menyiapkan kompatibilitas GitHub Pages...${NC}"
# Prevent Jekyll from ignoring _underscore folders
touch "${BUILD_DIR}/.nojekyll"

# Copy index.html to 404.html for SPA router handling on refresh
cp "${BUILD_DIR}/index.html" "${BUILD_DIR}/404.html"

echo -e "\n${BOLD}${GREEN}✓ Build Web Berhasil di: ${BUILD_DIR}${NC}\n"
echo -e "Untuk menguji build web secara lokal:"
echo -e "  cd ${BUILD_DIR} && python3 -m http.server 8080"
echo -e "  Buka http://localhost:8080 di browser.\n"
