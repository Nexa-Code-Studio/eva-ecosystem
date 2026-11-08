#!/usr/bin/env bash
# ==============================================================================
# EVA AI Ecosystem - Standalone Server Resource & Feasibility Diagnostic Script
# ==============================================================================
# Portable bash script for fresh/remote VPS & bare-metal Linux servers.
# Zero dependencies: runs out-of-the-box using standard coreutils (df, free, nproc, awk).
#
# Usage on remote server:
#   bash check_server.sh
#
# Or run directly via SSH from your local machine:
#   ssh user@your-server-ip 'bash -s' < scripts/check_server.sh
# ==============================================================================

set -o pipefail

# ANSI Colors
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
CYAN="\033[1;36m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

print_header() {
    echo -e "${CYAN}=================================================================${RESET}"
    echo -e "${BOLD}${CYAN}   EVA AI Backend - Remote Server Hardware Diagnostic Tool      ${RESET}"
    echo -e "${CYAN}=================================================================${RESET}"
    
    OS_NAME="Linux"
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_NAME="${PRETTY_NAME:-$NAME $VERSION}"
    fi
    KERNEL=$(uname -r)
    ARCH=$(uname -m)
    HOSTNAME_STR=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "localhost")

    echo -e "${DIM}Host       : ${HOSTNAME_STR}${RESET}"
    echo -e "${DIM}OS / Kernel: ${OS_NAME} (${KERNEL})${RESET}"
    echo -e "${DIM}Arch       : ${ARCH}${RESET}"
    echo ""
}

# ------------------------------------------------------------------------------
# 1. CPU CHECK
# ------------------------------------------------------------------------------
check_cpu() {
    echo -e "${BOLD}[ 1. CPU Evaluation ]${RESET}"
    CPU_CORES=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
    
    LOAD_1M="0.00"
    if [ -f /proc/loadavg ]; then
        LOAD_1M=$(awk '{print $1}' /proc/loadavg)
    fi

    # Evaluation
    # Check if load per core is manageable
    LOAD_INT=$(echo "$LOAD_1M" | awk -v cores="$CPU_CORES" '{if ($1/cores > 1.0) print 1; else print 0}')

    if [ "$CPU_CORES" -ge 2 ] && [ "$LOAD_INT" -eq 0 ]; then
        echo -e "  ${GREEN}✅ PASS${RESET}  ${BOLD}Core Count & Load     :${RESET} ${CPU_CORES} vCPU Cores (Load 1m: ${LOAD_1M}) - Sangat cukup untuk multi-worker Uvicorn & ARQ."
        ((PASS_COUNT++))
    elif [ "$CPU_CORES" -ge 1 ] && [ "$LOAD_INT" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠️  WARN${RESET}  ${BOLD}Core Count & Load     :${RESET} ${CPU_CORES} vCPU Core (Load 1m: ${LOAD_1M}) - Cukup untuk beban ringan (1 worker)."
        echo -e "       ${CYAN}↳ Catatan:${RESET} Disarankan minimal 2 vCPU jika melayani lebih dari 10 sesi panggilan bersamaan."
        ((WARN_COUNT++))
    else
        echo -e "  ${RED}❌ FAIL${RESET}  ${BOLD}Core Count & Load     :${RESET} ${CPU_CORES} vCPU dengan beban sangat tinggi (Load 1m: ${LOAD_1M})."
        echo -e "       ${CYAN}↳ Rekomendasi:${RESET} Hentikan proses yang memakan CPU atau upgrade paket vCPU server."
        ((FAIL_COUNT++))
    fi
    echo ""
}

# ------------------------------------------------------------------------------
# 2. RAM & SWAP CHECK
# ------------------------------------------------------------------------------
check_ram() {
    echo -e "${BOLD}[ 2. Memory (RAM & Swap) Evaluation ]${RESET}"
    
    # Parse /proc/meminfo in MB
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    AVAIL_RAM_KB=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    TOTAL_SWAP_KB=$(grep SwapTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    FREE_SWAP_KB=$(grep SwapFree /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)

    TOTAL_RAM_MB=$((TOTAL_RAM_KB / 1024))
    AVAIL_RAM_MB=$((AVAIL_RAM_KB / 1024))
    TOTAL_SWAP_MB=$((TOTAL_SWAP_KB / 1024))
    FREE_SWAP_MB=$((FREE_SWAP_KB / 1024))

    TOTAL_RAM_GB=$(awk -v m="$TOTAL_RAM_MB" 'BEGIN {printf "%.1f", m/1024}')
    AVAIL_RAM_GB=$(awk -v m="$AVAIL_RAM_MB" 'BEGIN {printf "%.1f", m/1024}')
    TOTAL_SWAP_GB=$(awk -v m="$TOTAL_SWAP_MB" 'BEGIN {printf "%.1f", m/1024}')

    # Physical RAM
    if [ "$TOTAL_RAM_MB" -ge 1800 ] && [ "$AVAIL_RAM_MB" -ge 800 ]; then
        echo -e "  ${GREEN}✅ PASS${RESET}  ${BOLD}Physical RAM          :${RESET} Total: ${TOTAL_RAM_GB} GB | Tersedia: ${AVAIL_RAM_GB} GB - Sangat aman."
        ((PASS_COUNT++))
    elif [ "$TOTAL_RAM_MB" -ge 900 ] || [ "$AVAIL_RAM_MB" -ge 450 ]; then
        echo -e "  ${YELLOW}⚠️  WARN${RESET}  ${BOLD}Physical RAM          :${RESET} Total: ${TOTAL_RAM_GB} GB | Tersedia: ${AVAIL_RAM_GB} GB - Cukup, namun mendekati batas minimal."
        echo -e "       ${CYAN}↳ Catatan:${RESET} Pastikan Swap aktif minimal 2 GB untuk menampung lonjakan memori Docker."
        ((WARN_COUNT++))
    else
        echo -e "  ${RED}❌ FAIL${RESET}  ${BOLD}Physical RAM          :${RESET} Total: ${TOTAL_RAM_GB} GB (Tersedia: ${AVAIL_RAM_GB} GB) - Kurang dari 1 GB."
        echo -e "       ${CYAN}↳ Rekomendasi:${RESET} Stack EVA (FastAPI, Qdrant, Postgres, Redis) membutuhkan minimal 1 GB RAM fisik."
        ((FAIL_COUNT++))
    fi

    # Swap Space (Critical for VPS under 2GB)
    if [ "$TOTAL_SWAP_MB" -ge 1800 ]; then
        echo -e "  ${GREEN}✅ PASS${RESET}  ${BOLD}Swap Space            :${RESET} Total: ${TOTAL_SWAP_GB} GB - Perlindungan Linux OOM-Killer aktif."
        ((PASS_COUNT++))
    elif [ "$TOTAL_SWAP_MB" -ge 500 ]; then
        echo -e "  ${YELLOW}⚠️  WARN${RESET}  ${BOLD}Swap Space            :${RESET} Total: ${TOTAL_SWAP_GB} GB - Disarankan 2 GB untuk kestabilan penuh."
        ((WARN_COUNT++))
    else
        if [ "$TOTAL_RAM_MB" -ge 3800 ]; then
            echo -e "  ${YELLOW}⚠️  WARN${RESET}  ${BOLD}Swap Space            :${RESET} Swap tidak aktif (0 MB). RAM fisik cukup besar (${TOTAL_RAM_GB} GB)."
            ((WARN_COUNT++))
        else
            echo -e "  ${RED}❌ FAIL${RESET}  ${BOLD}Swap Space            :${RESET} Swap tidak aktif (0 MB) pada RAM ${TOTAL_RAM_GB} GB."
            echo -e "       ${CYAN}↳ Wajib Aktifkan Swap (Copy-Paste perintah ini):${RESET}"
            echo -e "         ${BOLD}sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile && echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab${RESET}"
            ((FAIL_COUNT++))
        fi
    fi
    echo ""
}

# ------------------------------------------------------------------------------
# 3. DISK STORAGE CHECK
# ------------------------------------------------------------------------------
check_storage() {
    echo -e "${BOLD}[ 3. Storage / Disk Space Evaluation ]${RESET}"
    
    TARGET_DIR="/"
    if [ -d "/var/lib/docker" ]; then
        TARGET_DIR="/var/lib/docker"
    fi

    # Available disk in MB
    AVAIL_KB=$(df -k "$TARGET_DIR" | awk 'NR==2 {print $4}')
    TOTAL_KB=$(df -k "$TARGET_DIR" | awk 'NR==2 {print $2}')
    
    AVAIL_MB=$((AVAIL_KB / 1024))
    TOTAL_MB=$((TOTAL_KB / 1024))
    
    AVAIL_GB=$(awk -v m="$AVAIL_MB" 'BEGIN {printf "%.1f", m/1024}')
    TOTAL_GB=$(awk -v m="$TOTAL_MB" 'BEGIN {printf "%.1f", m/1024}')

    if [ "$AVAIL_MB" -ge 15000 ]; then
        echo -e "  ${GREEN}✅ PASS${RESET}  ${BOLD}Free Disk Space       :${RESET} Tersedia: ${AVAIL_GB} GB / Total: ${TOTAL_GB} GB - Sangat lega untuk Docker & Database."
        ((PASS_COUNT++))
    elif [ "$AVAIL_MB" -ge 6000 ]; then
        echo -e "  ${YELLOW}⚠️  WARN${RESET}  ${BOLD}Free Disk Space       :${RESET} Tersedia: ${AVAIL_GB} GB / Total: ${TOTAL_GB} GB - Cukup untuk deploy awal."
        echo -e "       ${CYAN}↳ Catatan:${RESET} Rutin bersihkan cache Docker dengan 'docker system prune -f' agar sisa disk tidak habis."
        ((WARN_COUNT++))
    else
        echo -e "  ${RED}❌ FAIL${RESET}  ${BOLD}Free Disk Space       :${RESET} Tersedia hanya ${AVAIL_GB} GB - Kurang dari 6 GB."
        echo -e "       ${CYAN}↳ Rekomendasi:${RESET} Stack image Docker (~2.5 GB) dan volume data membutuhkan minimal 6-8 GB free space."
        ((FAIL_COUNT++))
    fi
    echo ""
}

# ------------------------------------------------------------------------------
# 4. DOCKER & RUNTIME CHECK
# ------------------------------------------------------------------------------
check_docker() {
    echo -e "${BOLD}[ 4. Docker & Container Runtime Evaluation ]${RESET}"
    
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            DOCKER_VER=$(docker --version | head -n1)
            echo -e "  ${GREEN}✅ PASS${RESET}  ${BOLD}Docker Daemon         :${RESET} ${DOCKER_VER} (Service Aktif & Berjalan)."
            ((PASS_COUNT++))
        else
            echo -e "  ${YELLOW}⚠️  WARN${RESET}  ${BOLD}Docker Daemon         :${RESET} Docker terpasang, namun daemon mati atau butuh akses sudo."
            echo -e "       ${CYAN}↳ Jalankan:${RESET} sudo systemctl start docker && sudo usermod -aG docker \$USER"
            ((WARN_COUNT++))
        fi
    else
        echo -e "  ${RED}❌ FAIL${RESET}  ${BOLD}Docker Daemon         :${RESET} Docker belum terinstal di server."
        echo -e "       ${CYAN}↳ Install Cepat (Official):${RESET} curl -fsSL https://get.docker.com | sh"
        ((FAIL_COUNT++))
    fi

    # Docker Compose
    COMPOSE_OK=0
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_VER=$(docker compose version | head -n1)
        echo -e "  ${GREEN}✅ PASS${RESET}  ${BOLD}Docker Compose        :${RESET} ${COMPOSE_VER}"
        COMPOSE_OK=1
        ((PASS_COUNT++))
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_VER=$(docker-compose --version | head -n1)
        echo -e "  ${GREEN}✅ PASS${RESET}  ${BOLD}Docker Compose        :${RESET} ${COMPOSE_VER} (Standalone)"
        COMPOSE_OK=1
        ((PASS_COUNT++))
    fi

    if [ "$COMPOSE_OK" -eq 0 ]; then
        echo -e "  ${RED}❌ FAIL${RESET}  ${BOLD}Docker Compose        :${RESET} Docker Compose plugin belum terpasang."
        echo -e "       ${CYAN}↳ Install:${RESET} sudo apt-get install docker-compose-plugin (atau: sudo dnf install docker-compose-plugin)"
        ((FAIL_COUNT++))
    fi
    echo ""
}

# ------------------------------------------------------------------------------
# 5. PORT CONFLICT CHECK
# ------------------------------------------------------------------------------
check_ports() {
    echo -e "${BOLD}[ 5. Network & Port Conflict Evaluation ]${RESET}"
    
    PORTS=(8888 8889 5435 6381 6333)
    PORT_NAMES=("EVA API (:8888)" "EVA MCP (:8889)" "Postgres (:5435)" "Redis (:6381)" "Qdrant (:6333)")
    
    CONFLICTS=""
    for i in "${!PORTS[@]}"; do
        P="${PORTS[$i]}"
        NAME="${PORT_NAMES[$i]}"
        
        # Check using ss, netstat, or /dev/tcp
        IS_BUSY=0
        if command -v ss >/dev/null 2>&1; then
            if ss -tuln | grep -q ":${P} "; then IS_BUSY=1; fi
        elif command -v netstat >/dev/null 2>&1; then
            if netstat -tuln | grep -q ":${P} "; then IS_BUSY=1; fi
        fi

        if [ "$IS_BUSY" -eq 1 ]; then
            CONFLICTS="${CONFLICTS} ${NAME}"
        fi
    done

    if [ -z "$CONFLICTS" ]; then
        echo -e "  ${GREEN}✅ PASS${RESET}  ${BOLD}Port Availability     :${RESET} Seluruh port host (8888, 8889, 5435, 6381, 6333) kosong & siap digunakan."
        ((PASS_COUNT++))
    else
        echo -e "  ${YELLOW}⚠️  WARN${RESET}  ${BOLD}Port Availability     :${RESET} Port aktif:${CONFLICTS}."
        echo -e "       ${CYAN}↳ Catatan:${RESET} Jika container EVA sudah berjalan di server ini, ini normal. Jika digunakan service lain, ubah port di .env."
        ((WARN_COUNT++))
    fi
    echo ""
}

# ------------------------------------------------------------------------------
# FINAL FEASIBILITY VERDICT
# ------------------------------------------------------------------------------
print_verdict() {
    echo -e "${CYAN}-----------------------------------------------------------------${RESET}"
    echo -e "${BOLD}KESIMPULAN KELAYAKAN SERVER (FEASIBILITY VERDICT):${RESET}"
    echo -e "${DIM}Skor: ${GREEN}${PASS_COUNT} Passed${RESET}, ${YELLOW}${WARN_COUNT} Warnings${RESET}, ${RED}${FAIL_COUNT} Failed${RESET}"
    echo ""

    if [ "$FAIL_COUNT" -eq 0 ] && [ "$WARN_COUNT" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🚀 SIAP & SANGAT KUAT (READY FOR PRODUCTION)${RESET}"
        echo -e "Server ini memiliki hardware yang sangat optimal untuk menjalankan seluruh backend EVA AI."
        echo -e "Langkah selanjutnya:"
        echo -e "  1. Clone repo: ${BOLD}git clone https://github.com/Nexa-Code-Studio/eva-ecosystem.git${RESET}"
        echo -e "  2. Salin .env: ${BOLD}cp .env.example .env${RESET} (isi DEEPSEEK & ELEVENLABS keys)"
        echo -e "  3. Jalankan  : ${BOLD}make prod${RESET}"
        echo ""
        exit 0
    elif [ "$FAIL_COUNT" -eq 0 ]; then
        echo -e "${YELLOW}${BOLD}⚠️  MEMENUHI SYARAT DENGAN CATATAN (QUALIFIED WITH WARNINGS)${RESET}"
        echo -e "Server ini sanggup menjalankan backend EVA, namun harap perhatikan rekomendasi catatan kuning di atas (terutama swap & kapasitas disk)."
        echo -e "Langkah selanjutnya:"
        echo -e "  1. Clone repo: ${BOLD}git clone https://github.com/Nexa-Code-Studio/eva-ecosystem.git${RESET}"
        echo -e "  2. Jalankan  : ${BOLD}make prod${RESET}"
        echo ""
        exit 0
    else
        echo -e "${RED}${BOLD}❌ BELUM MEMENUHI SYARAT (INSUFFICIENT HARDWARE)${RESET}"
        echo -e "Ditemukan ${FAIL_COUNT} kendala kritis yang dapat menyebabkan container crash atau kehabisan memori."
        echo -e "Silakan ikuti instruksi perbaikan berwarna merah di atas sebelum menjalankan backend."
        echo ""
        exit 1
    fi
}

# Main execution
print_header
check_cpu
check_ram
check_storage
check_docker
check_ports
print_verdict
