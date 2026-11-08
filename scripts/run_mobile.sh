#!/usr/bin/env bash
# ==============================================================================
# EVA ECOSYSTEM — AUTOMATED MOBILE RUNNER
# Automates ADB reverse proxy, device detection, and Flutter launch for:
# - Physical Mobile Device via USB (Eva Mobile)
# - Android Emulator (Eva Mobile)
# - Mock Data Mode
# - Web Simulator
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

RAW_MODE="${1:-}"
TARGET_ENV="${ENV:-${TARGET:-local}}"
FALLBACK_HYBRID="${FALLBACK_HYBRID:-false}"

case "${RAW_MODE}" in
    usb-cloud)
        MODE="usb"
        TARGET_ENV="cloud"
        ;;
    emu-cloud)
        MODE="emu"
        TARGET_ENV="cloud"
        ;;
    web-cloud)
        MODE="web"
        TARGET_ENV="cloud"
        ;;
    cloud)
        MODE="usb"
        TARGET_ENV="cloud"
        ;;
    usb-hybrid)
        MODE="usb"
        FALLBACK_HYBRID=true
        ;;
    emu-hybrid)
        MODE="emu"
        FALLBACK_HYBRID=true
        ;;
    web-hybrid)
        MODE="web"
        FALLBACK_HYBRID=true
        ;;
    hybrid)
        MODE="usb"
        FALLBACK_HYBRID=true
        ;;
    *)
        MODE="${RAW_MODE}"
        ;;
esac

PORT="${PORT:-8888}"
MCP_PORT="${MCP_PORT:-8889}"

usage() {
    echo -e "${BOLD}Usage:${NC} $0 <usb|emu|mock|web|hybrid|usb-hybrid|emu-hybrid|web-hybrid|usb-cloud|emu-cloud|web-cloud> [extra_flutter_args...]"
    echo ""
    echo "Modes (DEFAULT: Nembak Local API port ${PORT}):"
    echo "  usb         Jalankan di HP Fisik via USB (DEFAULT: API Lokal via reverse port ${PORT})"
    echo "  emu         Jalankan di Android Emulator (DEFAULT: API Lokal via 10.0.2.2:${PORT})"
    echo "  web         Jalankan di Web Browser Chrome (DEFAULT: API Lokal via 127.0.0.1:${PORT})"
    echo "  mock        Jalankan dengan data simulasi lokal (USE_MOCK_DATA=true, offline)"
    echo "  hybrid      Jalankan mode Hybrid (Remote API dengan fallback otomatis ke Mock)"
    echo ""
    echo "Hybrid Fallback Modes (Remote API + Auto Mock Fallback on 404/Offline):"
    echo "  usb-hybrid  HP Fisik dengan Hybrid Fallback"
    echo "  emu-hybrid  Android Emulator dengan Hybrid Fallback"
    echo "  web-hybrid  Chrome Web dengan Hybrid Fallback"
    echo ""
    echo "Cloud Modes (Nembak Production Cloud eva.nexacode.dev):"
    echo "  usb-cloud   Jalankan di HP Fisik nembak ke Cloud (eva.nexacode.dev)"
    echo "  emu-cloud   Jalankan di Android Emulator nembak ke Cloud (eva.nexacode.dev)"
    echo "  web-cloud   Jalankan di Web Browser nembak ke Cloud (eva.nexacode.dev)"
    echo ""
    echo "Examples:"
    echo "  $0 usb                     # HP fisik nembak lokal port ${PORT}"
    echo "  $0 hybrid                  # HP fisik dengan mode Hybrid Fallback"
    echo "  $0 emu-hybrid              # Emulator dengan mode Hybrid Fallback"
    echo "  $0 mock                    # Eva Mobile dengan Mock Data murni"
    echo ""
    echo "Environment Variables:"
    echo "  DEVICE      Tentukan Device ID spesifik (misal: DEVICE=RR8Y900W1RB)"
    echo "  PORT        Port backend FastAPI lokal (default: 8888)"
    echo "  TARGET_ENV  Tentukan target server ('local' atau 'cloud')"
    exit 1
}

if [ -z "${MODE}" ]; then
    usage
fi

# Locate Flutter binary
FLUTTER_BIN=""
if command -v flutter &>/dev/null; then
    FLUTTER_BIN="$(command -v flutter)"
elif [ -x "${HOME}/development/flutter/bin/flutter" ]; then
    FLUTTER_BIN="${HOME}/development/flutter/bin/flutter"
elif [ -x "/home/mashupsoat/development/flutter/bin/flutter" ]; then
    FLUTTER_BIN="/home/mashupsoat/development/flutter/bin/flutter"
else
    echo -e "${RED}${BOLD}[ERROR]${NC} Flutter binary tidak ditemukan di PATH atau ~/development/flutter/bin/flutter"
    exit 1
fi

# Locate ADB binary
ADB_BIN=""
if command -v adb &>/dev/null; then
    ADB_BIN="$(command -v adb)"
elif [ -x "${HOME}/Android/sdk/platform-tools/adb" ]; then
    ADB_BIN="${HOME}/Android/sdk/platform-tools/adb"
elif [ -x "/home/mashupsoat/Android/sdk/platform-tools/adb" ]; then
    ADB_BIN="/home/mashupsoat/Android/sdk/platform-tools/adb"
elif [ -x "/usr/bin/adb" ]; then
    ADB_BIN="/usr/bin/adb"
else
    echo -e "${RED}${BOLD}[ERROR]${NC} adb binary tidak ditemukan. Pastikan Android SDK platform-tools terpasang."
    exit 1
fi

APP_DIR="${ROOT_DIR}/apps/eva_mobile"
if [ ! -d "${APP_DIR}" ]; then
    echo -e "${RED}${BOLD}[ERROR]${NC} Direktori aplikasi tidak ditemukan: ${APP_DIR}"
    exit 1
fi

# Shift mode argument so remaining args can be passed directly to flutter run
shift 1 || true

check_backend_health() {
    echo -e "${CYAN}Memeriksa status backend lokal...${NC}"
    if command -v curl &>/dev/null; then
        if ! curl -s --connect-timeout 2 "http://127.0.0.1:${PORT}/health" &>/dev/null; then
            echo -e "${YELLOW}⚠️  Perhatian:${NC} Backend EVA di http://127.0.0.1:${PORT} belum merespons."
            echo -e "   Pastikan backend sudah berjalan via ${BOLD}make dev${NC} atau ${BOLD}make dev-d${NC}.\n"
        else
            echo -e "${GREEN}✓ Backend EVA aktif di port ${PORT}.${NC}\n"
        fi
    fi
}

# ==============================================================================
# MODE: USB (Physical Device)
# ==============================================================================
if [ "${MODE}" = "usb" ]; then
    if [ "${TARGET_ENV}" = "cloud" ]; then
        echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
        echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — HP FISIK (CLOUD: eva.nexacode.dev)                  ${NC}"
        echo -e "${BOLD}${CYAN}================================================================================${NC}\n"
        echo -e "${GREEN}🌐 Menghubungkan ke Server Production Cloud...${NC}\n"
    else
        echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
        echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — HP FISIK (LOCAL API: 127.0.0.1:${PORT})             ${NC}"
        echo -e "${BOLD}${CYAN}================================================================================${NC}\n"
        check_backend_health
    fi

    # Check for unauthorized devices
    if "${ADB_BIN}" devices | grep -q "unauthorized"; then
        echo -e "${YELLOW}${BOLD}[WARNING]${NC} Terdeteksi perangkat dengan status UNAUTHORIZED."
        echo -e "Mohon periksa layar HP Anda dan setujui dialog ${BOLD}'Allow USB Debugging'${NC}.\n"
    fi

    # Detect physical devices (exclude emulators)
    mapfile -t PHYSICAL_DEVICES < <("${ADB_BIN}" devices | awk '$2=="device" && $1!~/^emulator-/ {print $1}')
    DEV_COUNT=${#PHYSICAL_DEVICES[@]}

    TARGET_DEVICE="${DEVICE:-}"

    if [ -z "${TARGET_DEVICE}" ]; then
        if [ "${DEV_COUNT}" -eq 0 ]; then
            echo -e "${RED}${BOLD}[ERROR]${NC} Tidak ada HP fisik yang terdeteksi via ADB."
            echo -e "Langkah penanganan:"
            echo -e "1. Hubungkan HP ke PC dengan kabel data USB."
            echo -e "2. Pastikan Developer Options & USB Debugging sudah aktif di HP."
            echo -e "3. Jalankan 'adb devices' untuk memastikan status 'device'."
            exit 1
        elif [ "${DEV_COUNT}" -eq 1 ]; then
            TARGET_DEVICE="${PHYSICAL_DEVICES[0]}"
        else
            TARGET_DEVICE="${PHYSICAL_DEVICES[0]}"
            echo -e "${YELLOW}Terdeteksi beberapa HP fisik.${NC} Menggunakan perangkat pertama: ${BOLD}${TARGET_DEVICE}${NC}"
            echo -e "(Gunakan ${BOLD}DEVICE=<id> make mobile-usb${NC} untuk memilih perangkat tertentu)."
        fi
    fi

    echo -e "${CYAN}Target Device:${NC} ${BOLD}${TARGET_DEVICE}${NC} (Eva Mobile)"

    if [ "${TARGET_ENV}" != "cloud" ]; then
        echo -e "${CYAN}Konfigurasi Port Forwarding:${NC} Menghubungkan port ${PORT} & ${MCP_PORT} HP -> PC..."
        # Perform adb reverse for API & MCP
        if "${ADB_BIN}" -s "${TARGET_DEVICE}" reverse "tcp:${PORT}" "tcp:${PORT}"; then
            echo -e "${GREEN}✓ Berhasil reverse port API:${NC} tcp:${PORT} -> tcp:${PORT} pada ${TARGET_DEVICE}"
        else
            echo -e "${RED}[ERROR] Gagal melakukan adb reverse port ${PORT}.${NC}"
            exit 1
        fi
        "${ADB_BIN}" -s "${TARGET_DEVICE}" reverse "tcp:${MCP_PORT}" "tcp:${MCP_PORT}" 2>/dev/null || true
    fi

    if [ "${FALLBACK_HYBRID}" = "true" ]; then
        echo -e "${GREEN}✓ Hybrid Fallback diaktifkan (Auto-mock pada 404 / server offline).${NC}\n"
    fi

    echo -e "${BOLD}${GREEN}🚀 Menjalankan Eva Mobile di ${TARGET_DEVICE}...${NC}"
    echo -e "${CYAN}Mengompilasi dan memulai aplikasi (Gradle assembleDebug), mohon tunggu...${NC}\n"
    cd "${APP_DIR}"
    if [ "${TARGET_ENV}" = "cloud" ]; then
        exec "${FLUTTER_BIN}" run -d "${TARGET_DEVICE}" \
            --dart-define=USE_LOCAL_API=false \
            --dart-define=USE_HYBRID_FALLBACK="${FALLBACK_HYBRID}" \
            --dart-define=HYBRID="${FALLBACK_HYBRID}" \
            "$@"
    else
        exec "${FLUTTER_BIN}" run -d "${TARGET_DEVICE}" \
            --dart-define=USE_LOCAL_API=true \
            --dart-define=LOCAL=true \
            --dart-define=USE_LOCALHOST=true \
            --dart-define=LOCAL_HOST="127.0.0.1:${PORT}" \
            --dart-define=API_BASE_URL="http://127.0.0.1:${PORT}/api/v1" \
            --dart-define=USE_HYBRID_FALLBACK="${FALLBACK_HYBRID}" \
            --dart-define=HYBRID="${FALLBACK_HYBRID}" \
            "$@"
    fi

# ==============================================================================
# MODE: EMU (Android Emulator)
# ==============================================================================
elif [ "${MODE}" = "emu" ]; then
    if [ "${TARGET_ENV}" = "cloud" ]; then
        echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
        echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — ANDROID EMULATOR (CLOUD: eva.nexacode.dev)          ${NC}"
        echo -e "${BOLD}${CYAN}================================================================================${NC}\n"
        echo -e "${GREEN}🌐 Menghubungkan ke Server Production Cloud...${NC}\n"
    else
        echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
        echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — ANDROID EMULATOR (LOCAL API: 10.0.2.2:${PORT})      ${NC}"
        echo -e "${BOLD}${CYAN}================================================================================${NC}\n"
        check_backend_health
    fi

    # Detect running emulators
    mapfile -t EMU_DEVICES < <("${ADB_BIN}" devices | awk '$2=="device" && $1~/^emulator-/ {print $1}')
    EMU_COUNT=${#EMU_DEVICES[@]}

    TARGET_DEVICE="${DEVICE:-}"

    if [ -z "${TARGET_DEVICE}" ]; then
        if [ "${EMU_COUNT}" -eq 0 ]; then
            echo -e "${RED}${BOLD}[ERROR]${NC} Tidak ada Android Emulator yang sedang aktif."
            echo -e "Langkah penanganan:"
            echo -e "1. Buka Android Studio -> Virtual Device Manager -> Start Emulator."
            echo -e "2. Atau jalankan perintah: ${BOLD}flutter emulators --launch <nama_emulator>${NC}"
            exit 1
        elif [ "${EMU_COUNT}" -eq 1 ]; then
            TARGET_DEVICE="${EMU_DEVICES[0]}"
        else
            TARGET_DEVICE="${EMU_DEVICES[0]}"
            echo -e "${YELLOW}Terdeteksi beberapa emulator.${NC} Menggunakan emulator pertama: ${BOLD}${TARGET_DEVICE}${NC}"
        fi
    fi

    echo -e "${CYAN}Target Emulator:${NC} ${BOLD}${TARGET_DEVICE}${NC} (Eva Mobile)"
    
    if [ "${TARGET_ENV}" != "cloud" ]; then
        # Also reverse port on emulator as safety measure
        "${ADB_BIN}" -s "${TARGET_DEVICE}" reverse "tcp:${PORT}" "tcp:${PORT}" 2>/dev/null || true
        echo -e "${GREEN}✓ Reverse port & bridge alias 10.0.2.2:${PORT} siap.${NC}"
    fi

    if [ "${FALLBACK_HYBRID}" = "true" ]; then
        echo -e "${GREEN}✓ Hybrid Fallback diaktifkan (Auto-mock pada 404 / server offline).${NC}\n"
    fi

    echo -e "${BOLD}${GREEN}🚀 Menjalankan Eva Mobile di emulator ${TARGET_DEVICE}...${NC}"
    echo -e "${CYAN}Mengompilasi dan memulai aplikasi (Gradle assembleDebug), mohon tunggu...${NC}\n"
    cd "${APP_DIR}"
    if [ "${TARGET_ENV}" = "cloud" ]; then
        exec "${FLUTTER_BIN}" run -d "${TARGET_DEVICE}" \
            --dart-define=USE_LOCAL_API=false \
            --dart-define=USE_HYBRID_FALLBACK="${FALLBACK_HYBRID}" \
            --dart-define=HYBRID="${FALLBACK_HYBRID}" \
            "$@"
    else
        exec "${FLUTTER_BIN}" run -d "${TARGET_DEVICE}" \
            --dart-define=USE_LOCAL_API=true \
            --dart-define=LOCAL=true \
            --dart-define=IS_EMULATOR=true \
            --dart-define=EMULATOR=true \
            --dart-define=LOCAL_HOST="10.0.2.2:${PORT}" \
            --dart-define=API_BASE_URL="http://10.0.2.2:${PORT}/api/v1" \
            --dart-define=USE_HYBRID_FALLBACK="${FALLBACK_HYBRID}" \
            --dart-define=HYBRID="${FALLBACK_HYBRID}" \
            "$@"
    fi

# ==============================================================================
# MODE: MOCK (Local Mock Data Mode)
# ==============================================================================
elif [ "${MODE}" = "mock" ]; then
    echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
    echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — MOCK DATA MODE                                      ${NC}"
    echo -e "${BOLD}${CYAN}================================================================================${NC}\n"

    echo -e "${GREEN}✓ Mode Mock Data aktif (tanpa perlu koneksi backend API).${NC}"
    echo -e "\n${BOLD}${GREEN}🚀 Menjalankan Eva Mobile dengan mock data...${NC}\n"
    cd "${APP_DIR}"
    exec "${FLUTTER_BIN}" run --dart-define=USE_MOCK_DATA=true "$@"

# ==============================================================================
# MODE: WEB (Chrome Browser Simulator)
# ==============================================================================
elif [ "${MODE}" = "web" ]; then
    if [ "${TARGET_ENV}" = "cloud" ]; then
        echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
        echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — WEB SIMULATOR (CLOUD: eva.nexacode.dev)             ${NC}"
        echo -e "${BOLD}${CYAN}================================================================================${NC}\n"
        echo -e "${GREEN}🌐 Menghubungkan ke Server Production Cloud...${NC}\n"
    else
        echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
        echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — WEB SIMULATOR (LOCAL API: 127.0.0.1:${PORT})        ${NC}"
        echo -e "${BOLD}${CYAN}================================================================================${NC}\n"
        check_backend_health
    fi

    if [ "${FALLBACK_HYBRID}" = "true" ]; then
        echo -e "${GREEN}✓ Hybrid Fallback diaktifkan (Auto-mock pada 404 / server offline).${NC}\n"
    fi

    echo -e "${BOLD}${GREEN}🚀 Menjalankan Eva Mobile di Chrome...${NC}\n"
    cd "${APP_DIR}"
    if [ "${TARGET_ENV}" = "cloud" ]; then
        exec "${FLUTTER_BIN}" run -d chrome \
            --dart-define=USE_LOCAL_API=false \
            --dart-define=USE_HYBRID_FALLBACK="${FALLBACK_HYBRID}" \
            --dart-define=HYBRID="${FALLBACK_HYBRID}" \
            "$@"
    else
        exec "${FLUTTER_BIN}" run -d chrome \
            --dart-define=USE_LOCAL_API=true \
            --dart-define=LOCAL=true \
            --dart-define=LOCAL_HOST="127.0.0.1:${PORT}" \
            --dart-define=API_BASE_URL="http://127.0.0.1:${PORT}/api/v1" \
            --dart-define=USE_HYBRID_FALLBACK="${FALLBACK_HYBRID}" \
            --dart-define=HYBRID="${FALLBACK_HYBRID}" \
            "$@"
    fi

else
    usage
fi
