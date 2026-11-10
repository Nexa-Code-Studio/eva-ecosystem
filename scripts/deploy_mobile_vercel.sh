#!/usr/bin/env bash
# ==============================================================================
# Script: deploy_mobile_vercel.sh
# Purpose: Build Eva Mobile (Flutter Web in Hybrid API Mode) and Deploy to Vercel
# Usage:
#   ./scripts/deploy_mobile_vercel.sh               # Build & Deploy to Production
#   SKIP_BUILD=true ./scripts/deploy_mobile_vercel.sh  # Deploy existing build/web
#   API_BASE_URL="https://eva.nexacode.dev/api/v1" ./scripts/deploy_mobile_vercel.sh
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${ROOT_DIR}/apps/eva_mobile"
BUILD_DIR="${APP_DIR}/build/web"

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m"

API_BASE_URL="${API_BASE_URL:-https://eva.nexacode.dev/api/v1}"
FALLBACK_HYBRID="${FALLBACK_HYBRID:-true}"
SKIP_BUILD="${SKIP_BUILD:-false}"
DEPLOY_FLAG="${DEPLOY_FLAG:---prod --yes}"

echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
echo -e "${BOLD}${CYAN}        EVA MOBILE — VERCEL HYBRID DEPLOYMENT                                   ${NC}"
echo -e "${BOLD}${CYAN}================================================================================${NC}\n"

echo -e "${CYAN}Target Configuration:${NC}"
echo -e "  - Platform       : ${BOLD}Vercel Web${NC}"
echo -e "  - Base URL (API) : ${BOLD}${API_BASE_URL}${NC}"
echo -e "  - Hybrid Fallback: ${BOLD}${FALLBACK_HYBRID}${NC}"
echo -e "  - Deploy Target  : ${BOLD}${DEPLOY_FLAG}${NC}"
echo ""

# ------------------------------------------------------------------------------
# 1. Compile Flutter Web
# ------------------------------------------------------------------------------
if [ "${SKIP_BUILD}" = "false" ]; then
    FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
    if ! command -v "${FLUTTER_BIN}" >/dev/null 2>&1; then
        if [ -x "/home/mashupsoat/development/flutter/bin/flutter" ]; then
            FLUTTER_BIN="/home/mashupsoat/development/flutter/bin/flutter"
        fi
    fi

    if command -v "${FLUTTER_BIN}" >/dev/null 2>&1; then
        echo -e "${GREEN}==> [1/3] Mengompilasi Flutter Web (Release Hybrid Mode)...${NC}"
        cd "${APP_DIR}"
        "${FLUTTER_BIN}" pub get
        "${FLUTTER_BIN}" build web --release \
            --base-href "/" \
            --dart-define=USE_LOCAL_API=false \
            --dart-define=USE_HYBRID_FALLBACK="${FALLBACK_HYBRID}" \
            --dart-define=HYBRID="${FALLBACK_HYBRID}" \
            --dart-define=API_BASE_URL="${API_BASE_URL}"
    else
        if [ -d "${BUILD_DIR}" ] && [ -f "${BUILD_DIR}/index.html" ]; then
            echo -e "${YELLOW}[INFO] Flutter executable tidak ditemukan, menggunakan build yang sudah ada di: ${BUILD_DIR}${NC}"
        else
            echo -e "${RED}[ERROR] Flutter tidak terpasang di sistem dan belum ada file di ${BUILD_DIR}!${NC}"
            echo -e "Solusi:"
            echo -e "1. Install Flutter SDK untuk mengompilasi web di mesin lokal, atau"
            echo -e "2. Gunakan GitHub Actions Workflow (.github/workflows/deploy-mobile-vercel.yml) untuk otomatis build & deploy via cloud."
            exit 1
        fi
    fi
else
    echo -e "${YELLOW}==> [1/3] Melewati tahap build (SKIP_BUILD=true)...${NC}"
fi

# Ensure vercel.json exists in build/web
if [ ! -d "${BUILD_DIR}" ]; then
    echo -e "${RED}[ERROR] Direktori ${BUILD_DIR} tidak ditemukan.${NC}"
    exit 1
fi

echo -e "${GREEN}==> [2/3] Menyalin konfigurasi routing vercel.json ke build artifact...${NC}"
cp -f "${APP_DIR}/web/vercel.json" "${BUILD_DIR}/vercel.json"

# ------------------------------------------------------------------------------
# 2. Deploy to Vercel via CLI
# ------------------------------------------------------------------------------
echo -e "${GREEN}==> [3/3] Melakukan deployment ke Vercel via CLI...${NC}"

cd "${BUILD_DIR}"

if command -v vercel >/dev/null 2>&1; then
    VERCEL_CMD="vercel"
elif command -v npx >/dev/null 2>&1; then
    VERCEL_CMD="npx --yes vercel"
else
    echo -e "${RED}[ERROR] Tidak ditemukan 'vercel' maupun 'npx' di PATH.${NC}"
    echo -e "Silakan install Node.js / Vercel CLI: npm install -g vercel"
    exit 1
fi

echo -e "${CYAN}Menjalankan: ${BOLD}${VERCEL_CMD} ${DEPLOY_FLAG}${NC}"
echo -e "${YELLOW}Catatan:${NC}"
echo -e "  • Jika ini pertama kali, npx sedang mengunduh Vercel CLI (~60MB) lalu membuka login browser."
echo -e "  • Periksa tab browser Anda jika diminta konfirmasi login akun Vercel."
echo -e "  • Jika muncul pertanyaan di terminal, tekan ${BOLD}Enter${NC} untuk menyetujui default.\n"
# Execute Vercel command
${VERCEL_CMD} ${DEPLOY_FLAG}

echo -e "\n${BOLD}${GREEN}✓ Deployment ke Vercel Selesai!${NC}\n"
