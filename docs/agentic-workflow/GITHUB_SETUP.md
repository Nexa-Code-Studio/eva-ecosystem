# Panduan Konfigurasi GitHub & Project v2

Dokumen ini menjelaskan integrasi repository dengan GitHub Issues, GitHub Projects v2, hak akses izin minimal, dan aturan proteksi cabang.

---

## 1. Pemilihan dan Binding GitHub Project v2

GitHub Projects v2 bertindak sebagai sumber kebenaran status pekerjaan tim (*kanban/table board*).

### Menghubungkan Project ke Workstation Developer

1. Buka organisasi GitHub dan pastikan Project v2 telah dibuat (misal: "Eva AI Sprint Board").
2. Catat nomor Project (terlihat di URL: `https://github.com/orgs/Nexa-Code-Studio/projects/<number>`).
3. Tambahkan nomor tersebut ke `.agent/developer.local.json`:
   ```json
   {
     "project": {
       "project_number": 1,
       "project_title": "Eva AI Sprint Board",
       "status_field": "Status"
     }
   }
   ```
4. Atau perbarui via CLI bootstrap:
   ```bash
   python3 scripts/agentic/bootstrap.py --force --project-number 1 --project-title "Eva AI Sprint Board"
   ```

---

## 2. Pemetaan Status Standar (Status Canonical Mapping)

Status kanonikal yang didukung sistem:

| Status Kanonikal | Deskripsi | Makna dalam Siklus Hidup |
| :--- | :--- | :--- |
| `Backlog` | Ide atau fitur yang belum siap dikerjakan | Menunggu persetujuan requirement |
| `Ready` | Requirement dan kriteria penerimaan disetujui | Siap diambil oleh developer |
| `In Progress` | Sedang dikerjakan pada branch/worktree aktif | Developer bertanggung jawab atas implementasi |
| `Blocked` | Terhenti karena dependensi atau hambatan eksternal | Membutuhkan eskalasi/bantuan |
| `In Review` | PR telah dibuka dan lolos uji lokal | Menunggu peninjauan rekan tim |
| `Done` | PR telah di-merge ke branch utama | Pekerjaan selesai dan terverifikasi |

> **Catatan Penting**: Jika GitHub Project tim menggunakan nama status yang berbeda (misalnya `In Progress` dinamai `Doing`), sesuaikan konfigurasi field mapping tanpa membuat field status ganda.

---

## 3. Hak Akses & Lingkup Izin Minimal (Least Privilege)

- **Developer Lokal (Personal Access Token / gh auth)**:
  - Scope minimum: `repo`, `read:project`.
  - Akses `write:project` hanya jika developer diizinkan memperbarui status board langsung dari CLI lokal.
- **GitHub Actions (`GITHUB_TOKEN`)**:
  - `contents: read`
  - `issues: read`
  - `pull-requests: read`
  - Workflow notifikasi **tidak membutuhkan write access** ke kode sumber.

---

## 4. Rekomendasi Proteksi Cabang (Branch Protection Rules)

Disarankan mengaktifkan aturan berikut pada branch default (`main`):
1. **Require pull request reviews before merging**: minimal 1 reviewer independen.
2. **Require status checks to pass before merging**:
   - `validate-agentic-workflow` (dari `agentic-ci.yml`)
   - `build-mobile` (dari `build-mobile.yml`)
3. **Do not allow bypassing the above settings**: menjamin tidak ada perubahan yang masuk secara sepihak.
