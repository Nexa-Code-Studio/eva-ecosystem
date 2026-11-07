# Alur Kerja Harian (Daily Workflow)

Panduan praktis langkah demi langkah bagi developer dalam menggunakan Antigravity CLI dan tooling agentic untuk menyelesaikan pekerjaan harian.

---

## 1. Membuka Sesi & Memeriksa Konteks Tugas

Setiap memulai hari atau berpindah fokus:

```bash
# 1. Jalankan ringkasan tugas aktif
python3 scripts/agentic/tasks.py
```

Perintah ini akan menampilkan:
- Akun developer aktif dan machine label.
- Cabang git yang sedang aktif.
- Daftar cabang tugas lokal `{type}/{issue}-{slug}`.
- Git worktree yang sedang terbuka.
- Isu GitHub yang ditugaskan kepada Anda (jika terhubung online).

---

## 2. Memulai Tugas Baru (`start-task`)

Pilih satu issue dari backlog, lalu buat cabang tugas:

```bash
# Contoh: Membuat branch untuk Issue #142 (fitur mood check-in)
python3 scripts/agentic/start-task.py \
  --type feat \
  --issue 142 \
  --slug mood-checkin-screen
```

### Opsi: Menggunakan Git Worktree (Isolasi Penuh)
Jika Anda ingin mengerjakan tugas baru tanpa mengganggu direktori kerja utama:

```bash
python3 scripts/agentic/start-task.py \
  --type fix \
  --issue 145 \
  --slug audio-pitch-glitch \
  --worktree
```
Lalu pindah ke direktori worktree:
```bash
cd .agent/worktrees/145-audio-pitch-glitch
```

---

## 3. Menandai Status Kerja (`In Progress`)

Sinkronkan status bahwa Anda telah mulai mengimplementasikan tugas tersebut:

```bash
python3 scripts/agentic/sync-state.py --state "In Progress"
```

---

## 4. Coding Berpasangan dengan Antigravity Agent

Berikan prompt instruksi spesifik kepada agent Antigravity di terminal atau IDE:
- Gunakan acuan aturan arsitektur (`AGENTS.md` dan `.agents/rules/`).
- Minta agent mengimplementasikan fitur sesuai acceptance criteria pada issue.
- Minta agent membuat unit test pendukung.

---

## 5. Menjalankan Tes & Mengumpulkan Bukti

Sebelum membuka Pull Request, jalankan pengujian lokal:

```bash
# Pengujian modul Python / Agentic
python3 -m unittest discover -s tests/agentic

# Pengujian modul Flutter Mobile (jika relevan)
# make test-mobile
```

---

## 6. Menyiapkan Pull Request (`prepare-pr`)

Setelah pengujian lulus dan commit dibuat:

```bash
python3 scripts/agentic/prepare-pr.py \
  --test-cmd "python3 -m unittest discover -s tests/agentic"
```

Script akan:
1. Memeriksa konvensi penamaan branch.
2. Memastikan tidak ada file kotor (*dirty tree*).
3. Menjalankan tes dan menyertakan bukti kelulusan (*test evidence*).
4. Menyusun draf Markdown sesuai template repository.

---

## 7. Memperbarui Status ke `In Review`

Setelah Pull Request dibuka di GitHub:

```bash
python3 scripts/agentic/sync-state.py \
  --state "In Review" \
  --pr-url "https://github.com/Nexa-Code-Studio/eva-ecosystem/pull/45" \
  --test-evidence "100% tests passing via python3 -m unittest"
```

---

## 8. Menandai Tugas Selesai (`Done`)

Setelah PR disetujui (*approved*) dan di-merge ke branch utama:

```bash
python3 scripts/agentic/sync-state.py \
  --state Done \
  --pr-merged
```
