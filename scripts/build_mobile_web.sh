#!/usr/bin/env bash
# ==============================================================================
# Script: build_mobile_web.sh
# Purpose: Build EVA Ecosystem Web (Eva Mobile & Eva Counselor) for GitHub Pages
# Usage:
#   ./scripts/build_mobile_web.sh               # Full multi-app build
#   APP=mobile ./scripts/build_mobile_web.sh    # Only Eva Mobile
#   APP=counselor ./scripts/build_mobile_web.sh # Only Eva Counselor
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

BASE_HREF="${BASE_HREF:-/eva-ecosystem/}"
[[ "$BASE_HREF" != */ ]] && BASE_HREF="${BASE_HREF}/"

API_BASE_URL="${API_BASE_URL:-https://eva.nexacode.dev/api/v1}"
FALLBACK_HYBRID="${FALLBACK_HYBRID:-true}"
TARGET_APP="${APP:-all}"

echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
echo -e "${BOLD}${CYAN}        EVA ECOSYSTEM — MULTI-APP WEB BUILDER (GITHUB PAGES)                    ${NC}"
echo -e "${BOLD}${CYAN}================================================================================${NC}\n"

echo -e "${CYAN}Configuration:${NC}"
echo -e "  - Target App     : ${BOLD}${TARGET_APP}${NC}"
echo -e "  - Root Base Href : ${BOLD}${BASE_HREF}${NC}"
echo -e "  - Mobile Href    : ${BOLD}${BASE_HREF}app/${NC}"
echo -e "  - Counselor Href : ${BOLD}${BASE_HREF}counselor/${NC}"
echo -e "  - API Base URL   : ${BOLD}${API_BASE_URL}${NC}"
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

DIST_DIR="${ROOT_DIR}/dist"
mkdir -p "${DIST_DIR}/app" "${DIST_DIR}/counselor"

# 1. Build Eva Mobile
if [ "${TARGET_APP}" = "all" ] || [ "${TARGET_APP}" = "mobile" ]; then
    echo -e "${GREEN}==> [1/2] Mengompilasi Eva Mobile (${BASE_HREF}app/)...${NC}"
    cd "${ROOT_DIR}/apps/eva_mobile"
    "${FLUTTER_BIN}" pub get
    "${FLUTTER_BIN}" build web --release \
        --base-href "${BASE_HREF}app/" \
        --dart-define=USE_LOCAL_API=false \
        --dart-define=USE_HYBRID_FALLBACK="${FALLBACK_HYBRID}" \
        --dart-define=HYBRID="${FALLBACK_HYBRID}" \
        --dart-define=API_BASE_URL="${API_BASE_URL}"

    cp -r "${ROOT_DIR}/apps/eva_mobile/build/web/"* "${DIST_DIR}/app/"
fi

# 2. Build Eva Counselor Mobile
if [ "${TARGET_APP}" = "all" ] || [ "${TARGET_APP}" = "counselor" ]; then
    echo -e "${GREEN}==> [2/2] Mengompilasi Eva Counselor (${BASE_HREF}counselor/)...${NC}"
    cd "${ROOT_DIR}/apps/eva_counselor_mobile"
    "${FLUTTER_BIN}" pub get
    "${FLUTTER_BIN}" build web --release \
        --base-href "${BASE_HREF}counselor/" \
        --dart-define=USE_LOCAL_API=false \
        --dart-define=USE_MOCK_DATA=false

    cp -r "${ROOT_DIR}/apps/eva_counselor_mobile/build/web/"* "${DIST_DIR}/counselor/"
fi

# 3. Copy Hub & SPA 404 handler
echo -e "${GREEN}==> Menyiapkan Portal Switcher & 404 Routing...${NC}"
cp -f "${ROOT_DIR}/scripts/web-hub/index.html" "${DIST_DIR}/index.html"
cp -f "${ROOT_DIR}/scripts/web-hub/404.html" "${DIST_DIR}/404.html"
touch "${DIST_DIR}/.nojekyll"

echo -e "\n${BOLD}${GREEN}✓ Build Multi-App Selesai di: ${DIST_DIR}${NC}\n"
echo -e "Untuk menguji bundle lokal secara utuh:"
echo -e "  cd ${DIST_DIR} && python3 -m http.server 8080"
echo -e "  Buka http://localhost:8080 di browser.\n"
