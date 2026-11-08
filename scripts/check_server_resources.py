#!/usr/bin/env python3
"""
EVA AI Backend - Server Resource Diagnostic & Feasibility Checker
Evaluates CPU, RAM, Swap, Disk Storage, and Docker capability to determine
if the current host/server is strong enough to run the EVA Ecosystem backend stack.

Zero external dependencies - standard library only.
Usage:
    python3 scripts/check_server_resources.py
"""

import os
import platform
import shutil
import socket
import subprocess
import sys
from typing import NamedTuple

# ANSI Colors
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
CYAN = "\033[96m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"


class CheckResult(NamedTuple):
    category: str
    name: str
    status: str  # "PASS", "WARN", "FAIL"
    message: str
    recommendation: str = ""


def get_mem_info() -> dict[str, int]:
    """Parse /proc/meminfo in KiB, returns dict in bytes."""
    mem_info = {}
    if os.path.exists("/proc/meminfo"):
        try:
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    parts = line.split(":")
                    if len(parts) == 2:
                        key = parts[0].strip()
                        val_str = parts[1].strip().split()[0]
                        if val_str.isdigit():
                            mem_info[key] = int(val_str) * 1024  # convert KiB to bytes
        except Exception:
            pass
    return mem_info


def format_bytes(b: float) -> str:
    """Format bytes into human-readable string (MB, GB)."""
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if b < 1024.0 or unit == "TB":
            return f"{b:.1f} {unit}"
        b /= 1024.0
    return f"{b:.1f} GB"


def check_port(port: int, host: str = "127.0.0.1") -> bool:
    """Check if a port is in use."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.3)
        return s.connect_ex((host, port)) == 0


def run_cmd(cmd: list[str]) -> tuple[int, str]:
    """Execute command safely and capture output."""
    try:
        res = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=5,
        )
        return res.returncode, res.stdout.strip()
    except Exception as e:
        return 1, str(e)


def main():
    print(f"\n{BOLD}{CYAN}================================================================={RESET}")
    print(f"{BOLD}{CYAN}    EVA AI Backend - Server Hardware & Resource Checker         {RESET}")
    print(f"{BOLD}{CYAN}================================================================={RESET}")
    print(f"{DIM}Inspecting host environment: {platform.system()} {platform.release()} ({platform.machine()}){RESET}\n")

    results: list[CheckResult] = []

    # ---------------------------------------------------------
    # 1. CPU EVALUATION
    # ---------------------------------------------------------
    cpu_cores = os.cpu_count() or 1
    load_avg = [0.0, 0.0, 0.0]
    if hasattr(os, "getloadavg"):
        try:
            load_avg = list(os.getloadavg())
        except Exception:
            pass

    load_1m = load_avg[0]
    if cpu_cores >= 2 and (load_1m / cpu_cores) < 0.8:
        results.append(CheckResult(
            "CPU", "Core Count & Load", "PASS",
            f"{cpu_cores} Cores (Load avg 1m: {load_1m:.2f}) - Sangat cukup untuk multi-worker uvicorn & ARQ."
        ))
    elif cpu_cores >= 1 and (load_1m / cpu_cores) < 1.0:
        results.append(CheckResult(
            "CPU", "Core Count & Load", "WARN",
            f"{cpu_cores} Core (Load avg 1m: {load_1m:.2f}) - Cukup untuk production kecil (1-2 worker).",
            "Disarankan 2 Cores jika berencana menangani >20 pengguna aktif bersamaan."
        ))
    else:
        results.append(CheckResult(
            "CPU", "Core Count & Load", "FAIL",
            f"{cpu_cores} Core dengan load tinggi ({load_1m:.2f}).",
            "Kurangi proses lain di server atau upgrade core CPU."
        ))

    # ---------------------------------------------------------
    # 2. RAM & SWAP EVALUATION
    # ---------------------------------------------------------
    mem_info = get_mem_info()
    total_ram = mem_info.get("MemTotal", 0)
    avail_ram = mem_info.get("MemAvailable", total_ram // 2)
    swap_total = mem_info.get("SwapTotal", 0)
    swap_free = mem_info.get("SwapFree", 0)

    # Convert to GB for clean thresholds
    total_ram_gb = total_ram / (1024 ** 3)
    avail_ram_gb = avail_ram / (1024 ** 3)
    swap_total_gb = swap_total / (1024 ** 3)

    if total_ram_gb >= 1.8 and avail_ram_gb >= 0.8:
        results.append(CheckResult(
            "Memory", "Physical RAM", "PASS",
            f"Total: {format_bytes(total_ram)} | Tersedia: {format_bytes(avail_ram)} - Sangat aman."
        ))
    elif (total_ram_gb >= 0.9 or avail_ram_gb >= 0.5):
        results.append(CheckResult(
            "Memory", "Physical RAM", "WARN",
            f"Total: {format_bytes(total_ram)} | Tersedia: {format_bytes(avail_ram)} - Cukup, namun mendekati batas minimal.",
            "Pastikan Swap File aktif minimal 2 GB untuk menampung lonjakan memory saat build/reload."
        ))
    else:
        results.append(CheckResult(
            "Memory", "Physical RAM", "FAIL",
            f"Total: {format_bytes(total_ram)} | Tersedia: {format_bytes(avail_ram)} - Terlalu kecil (< 1 GB).",
            "Backend EVA (API + Postgres + Qdrant + Redis) memerlukan minimal 1 GB RAM fisik."
        ))

    # Swap check
    if swap_total_gb >= 1.5:
        results.append(CheckResult(
            "Memory", "Swap Space", "PASS",
            f"Total Swap: {format_bytes(swap_total)} (Free: {format_bytes(swap_free)}) - Perlindungan OOM aktif."
        ))
    elif swap_total_gb > 0:
        results.append(CheckResult(
            "Memory", "Swap Space", "WARN",
            f"Swap hanya {format_bytes(swap_total)}.",
            "Disarankan buat swap 2 GB: sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile"
        ))
    else:
        results.append(CheckResult(
            "Memory", "Swap Space", "WARN" if total_ram_gb >= 3.5 else "FAIL",
            "Swap tidak aktif (0 B).",
            "Wajib aktifkan Swap 2-4 GB untuk mencegah Linux OOM-Killer mematikan container saat lonjakan memori: 'sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile'"
        ))

    # ---------------------------------------------------------
    # 3. STORAGE & DISK EVALUATION
    # ---------------------------------------------------------
    target_path = "/"
    if os.path.exists("/var/lib/docker"):
        target_path = "/var/lib/docker"
    elif os.path.exists(os.getcwd()):
        target_path = os.getcwd()

    disk = shutil.disk_usage(target_path)
    disk_total = disk.total
    disk_free = disk.free
    disk_used = disk.used
    disk_free_gb = disk_free / (1024 ** 3)
    disk_total_gb = disk_total / (1024 ** 3)

    if disk_free_gb >= 15.0:
        results.append(CheckResult(
            "Storage", "Free Disk Space", "PASS",
            f"Tersedia: {format_bytes(disk_free)} / {format_bytes(disk_total)} ({disk_free_gb:.1f} GB Free) - Sangat lega."
        ))
    elif disk_free_gb >= 6.0:
        results.append(CheckResult(
            "Storage", "Free Disk Space", "WARN",
            f"Tersedia: {format_bytes(disk_free)} / {format_bytes(disk_total)} ({disk_free_gb:.1f} GB Free) - Cukup untuk jalan.",
            "Jalankan 'docker system prune -f' secara berkala agar sisa disk tidak habis oleh cache build."
        ))
    else:
        results.append(CheckResult(
            "Storage", "Free Disk Space", "FAIL",
            f"Tersedia: {format_bytes(disk_free)} ({disk_free_gb:.1f} GB Free) - Tidak mencukupi (< 6 GB).",
            "Image Docker dan volume EVA memerlukan minimal 6-8 GB free space. Bersihkan disk sebelum menjalankan backend."
        ))

    # ---------------------------------------------------------
    # 4. DOCKER & COMPOSE RUNTIME
    # ---------------------------------------------------------
    docker_bin = shutil.which("docker")
    if docker_bin:
        code, out = run_cmd([docker_bin, "info"])
        if code == 0:
            results.append(CheckResult(
                "Runtime", "Docker Daemon", "PASS",
                f"Docker terinstal dan aktif ({docker_bin})."
            ))
        else:
            results.append(CheckResult(
                "Runtime", "Docker Daemon", "WARN",
                "Docker binary ditemukan, namun daemon belum berjalan atau perlu sudo.",
                "Jalankan 'sudo systemctl start docker' dan tambahkan user ke group docker."
            ))
    else:
        results.append(CheckResult(
            "Runtime", "Docker Daemon", "FAIL",
            "Docker tidak terpasang di sistem.",
            "Install Docker: curl -fsSL https://get.docker.com | sh"
        ))

    # Docker compose check
    compose_ok = False
    if docker_bin:
        code, out = run_cmd([docker_bin, "compose", "version"])
        if code == 0:
            compose_ok = True
            results.append(CheckResult(
                "Runtime", "Docker Compose", "PASS",
                f"Docker Compose plugin aktif: {out.splitlines()[0]}"
            ))
        else:
            code_alt, out_alt = run_cmd(["docker-compose", "version"])
            if code_alt == 0:
                compose_ok = True
                results.append(CheckResult(
                    "Runtime", "Docker Compose", "PASS",
                    f"docker-compose standalone aktif: {out_alt.splitlines()[0]}"
                ))
    if not compose_ok:
        results.append(CheckResult(
            "Runtime", "Docker Compose", "WARN",
            "Docker Compose tidak ditemukan.",
            "Install plugin: sudo apt-get install docker-compose-plugin (atau dnf install docker-compose-plugin)"
        ))

    # ---------------------------------------------------------
    # 5. PORT CONFLICT CHECK
    # ---------------------------------------------------------
    ports_to_check = {
        8888: "EVA FastAPI Backend",
        8889: "EVA FastMCP Server",
        5435: "EVA PostgreSQL (Port Host)",
        6381: "EVA Redis (Port Host)",
        6333: "EVA Qdrant Vector DB",
    }
    conflict_ports = []
    for port, name in ports_to_check.items():
        if check_port(port):
            conflict_ports.append(f"{port} ({name})")

    if not conflict_ports:
        results.append(CheckResult(
            "Network", "Port Availability", "PASS",
            "Seluruh port (8888, 8889, 5435, 6381, 6333) tersedia dan bebas bentrok."
        ))
    else:
        results.append(CheckResult(
            "Network", "Port Availability", "WARN",
            f"Port sedang digunakan: {', '.join(conflict_ports)}.",
            "Jika container EVA sudah berjalan, abaikan peringatan ini. Jika service lain memakai port ini, hentikan proses tersebut."
        ))

    # ---------------------------------------------------------
    # PRESENTATION
    # ---------------------------------------------------------
    categories = ["CPU", "Memory", "Storage", "Runtime", "Network"]
    fail_count = sum(1 for r in results if r.status == "FAIL")
    warn_count = sum(1 for r in results if r.status == "WARN")
    pass_count = sum(1 for r in results if r.status == "PASS")

    for cat in categories:
        cat_items = [r for r in results if r.category == cat]
        if not cat_items:
            continue
        print(f"{BOLD}[ {cat} Check ]{RESET}")
        for r in cat_items:
            if r.status == "PASS":
                badge = f"{GREEN}✅ PASS{RESET}"
            elif r.status == "WARN":
                badge = f"{YELLOW}⚠️  WARN{RESET}"
            else:
                badge = f"{RED}❌ FAIL{RESET}"
            print(f"  {badge}  {BOLD}{r.name:<22}{RESET}: {r.message}")
            if r.recommendation:
                print(f"       {CYAN}↳ Rekomendasi:{RESET} {r.recommendation}")
        print()

    # ---------------------------------------------------------
    # FINAL VERDICT
    # ---------------------------------------------------------
    print(f"{BOLD}{CYAN}-----------------------------------------------------------------{RESET}")
    print(f"{BOLD}HASIL KELAYAKAN SERVER (FEASIBILITY VERDICT):{RESET}")

    if fail_count == 0 and warn_count == 0:
        print(f"{GREEN}{BOLD}🚀 SIAP & SANGAT KUAT (READY FOR PRODUCTION){RESET}")
        print(f"Server memiliki resource yang melimpah dan optimal untuk menjalankan backend EVA.")
        print(f"Jalankan backend dengan: {BOLD}make prod{RESET} atau {BOLD}docker compose -f docker-compose.prod.yml up -d{RESET}\n")
        sys.exit(0)
    elif fail_count == 0:
        print(f"{YELLOW}{BOLD}⚠️  MEMENUHI SYARAT DENGAN CATATAN (QUALIFIED WITH WARNINGS){RESET}")
        print(f"Server sanggup menjalankan backend EVA, namun perhatikan catatan rekomendasi di atas (terutama swap dan free disk).")
        print(f"Jalankan backend dengan: {BOLD}make prod{RESET} atau {BOLD}docker compose -f docker-compose.prod.yml up -d{RESET}\n")
        sys.exit(0)
    else:
        print(f"{RED}{BOLD}❌ BELUM MEMENUHI SYARAT (INSUFFICIENT HARDWARE){RESET}")
        print(f"Ditemukan {fail_count} kendala kritis yang berisiko membuat container crash atau terkena OOM-Kill.")
        print(f"Harap penuhi rekomendasi perbaikan sebelum menjalankan stack backend di server ini.\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
