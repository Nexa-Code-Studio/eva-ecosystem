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

MODE="${1:-}"
PORT="${PORT:-8888}"
MCP_PORT="${MCP_PORT:-8889}"

usage() {
    echo -e "${BOLD}Usage:${NC} $0 <usb|emu|mock|web> [extra_flutter_args...]"
    echo ""
    echo "Modes:"
    echo "  usb       Jalankan Eva Mobile di HP Fisik via USB (otomatis adb reverse port ${PORT})"
    echo "  emu       Jalankan Eva Mobile di Android Emulator (route 10.0.2.2:${PORT})"
    echo "  mock      Jalankan Eva Mobile dengan data simulasi lokal (USE_MOCK_DATA=true)"
    echo "  web       Jalankan Eva Mobile di Web Browser (Chrome)"
    echo ""
    echo "Examples:"
    echo "  $0 usb                     # Eva Mobile di HP fisik dengan reverse port ${PORT}"
    echo "  $0 emu                     # Eva Mobile di Android Emulator"
    echo "  $0 mock                    # Eva Mobile dengan Mock Data"
    echo "  $0 web                     # Eva Mobile di Chrome"
    echo ""
    echo "Environment Variables:"
    echo "  DEVICE    Tentukan Device ID spesifik (misal: DEVICE=RR8Y900W1RB)"
    echo "  PORT      Port backend FastAPI (default: 8888)"
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
    if command -v curl &>/dev/null; then
        if ! curl -s --connect-timeout 2 "http://localhost:${PORT}/health" &>/dev/null; then
            echo -e "${YELLOW}⚠️  Perhatian:${NC} Backend EVA di http://localhost:${PORT} belum merespons."
            echo -e "   Pastikan backend sudah berjalan via ${BOLD}make dev${NC} atau ${BOLD}make dev-docker${NC}.\n"
        else
            echo -e "${GREEN}✓ Backend EVA aktif di port ${PORT}.${NC}"
        fi
    fi
}

# ==============================================================================
# MODE: USB (Physical Device)
# ==============================================================================
if [ "${MODE}" = "usb" ]; then
    echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
    echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — HP FISIK (USB DEBUGGING)                            ${NC}"
    echo -e "${BOLD}${CYAN}================================================================================${NC}\n"

    check_backend_health

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
    echo -e "${CYAN}Konfigurasi Port Forwarding:${NC} Menghubungkan port ${PORT} & ${MCP_PORT} HP -> PC..."

    # Perform adb reverse for API & MCP
    if "${ADB_BIN}" -s "${TARGET_DEVICE}" reverse "tcp:${PORT}" "tcp:${PORT}"; then
        echo -e "${GREEN}✓ Berhasil reverse port API:${NC} tcp:${PORT} -> tcp:${PORT} pada ${TARGET_DEVICE}"
    else
        echo -e "${RED}[ERROR] Gagal melakukan adb reverse port ${PORT}.${NC}"
        exit 1
    fi
    "${ADB_BIN}" -s "${TARGET_DEVICE}" reverse "tcp:${MCP_PORT}" "tcp:${MCP_PORT}" 2>/dev/null || true

    echo -e "\n${BOLD}${GREEN}🚀 Menjalankan Eva Mobile di ${TARGET_DEVICE}...${NC}\n"
    cd "${APP_DIR}"
    exec "${FLUTTER_BIN}" run -d "${TARGET_DEVICE}" --dart-define=USE_LOCALHOST=true "$@"

# ==============================================================================
# MODE: EMU (Android Emulator)
# ==============================================================================
elif [ "${MODE}" = "emu" ]; then
    echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
    echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — ANDROID EMULATOR                                    ${NC}"
    echo -e "${BOLD}${CYAN}================================================================================${NC}\n"

    check_backend_health

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
    
    # Also reverse port on emulator as safety measure
    "${ADB_BIN}" -s "${TARGET_DEVICE}" reverse "tcp:${PORT}" "tcp:${PORT}" 2>/dev/null || true
    echo -e "${GREEN}✓ Reverse port & bridge alias 10.0.2.2:${PORT} siap.${NC}"

    echo -e "\n${BOLD}${GREEN}🚀 Menjalankan Eva Mobile di emulator ${TARGET_DEVICE}...${NC}\n"
    cd "${APP_DIR}"
    exec "${FLUTTER_BIN}" run -d "${TARGET_DEVICE}" --dart-define=API_BASE_URL="http://10.0.2.2:${PORT}/api/v1" "$@"

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
    echo -e "\n${BOLD}${CYAN}================================================================================${NC}"
    echo -e "${BOLD}${CYAN}        EVA MOBILE RUNNER — WEB SIMULATOR (CHROME)                             ${NC}"
    echo -e "${BOLD}${CYAN}================================================================================${NC}\n"

    check_backend_health
    echo -e "\n${BOLD}${GREEN}🚀 Menjalankan Eva Mobile di Chrome...${NC}\n"
    cd "${APP_DIR}"
    exec "${FLUTTER_BIN}" run -d chrome "$@"

else
    usage
fi
