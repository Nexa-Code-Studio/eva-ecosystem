# SQLCipher Storage Spike & Feature Flags Specification

> **Dokumen Spesifikasi Teknis P0**: Refaktor Luna Local Selective Long-Term Memory (SQLCipher) & Consent-Based Clinical Sharing  
> **Repository**: https://github.com/Nexa-Code-Studio/eva-ecosystem  
> **Tanggal**: 21 November 2026  
> **Status**: Completed (P0 Baseline Technical Spike)

---

## 1. Analisis & Pemilihan Teknologi Penyimpanan Terenkripsi

### 1.1 Evaluasi Opsi SQLCipher untuk Flutter

| Kriteria Evaluasi | Opsi 1: `sqflite_sqlcipher` (Direkomendasikan MVP) | Opsi 2: `drift` + `sqlcipher_flutter_libs` | Opsi 3: Plain `sqflite` / `Hive` / Plaintext JSON |
|---|---|---|---|
| **Kepatuhan Enkripsi at Rest** | ✅ **AES-256 CBC** via native SQLCipher library (OpenSSL build). | ✅ **AES-256 CBC** via SQLCipher native bindings. | ❌ **Ditolak**: Plaintext; rentan diakses via file backup/root/adb. |
| **Kompatibilitas Platform** | ✅ Android (minSdkVersion 21+, NDK C++ STL) & iOS (CocoaPods/Framework). | ✅ Android, iOS, macOS, Windows, Linux. | N/A |
| **Overhead & Footprint** | ✅ Ringan, pola `openDatabase(..., password: key)` sangat mirip dengan implementasi datasource eksisting. | ⚠️ Memerlukan build runner code generation (`drift_dev`), menambah kompleksitas build. | Ringan tapi tidak aman. |
| **Integrasi Bersih (Clean Arch)** | ✅ Mudah dibungkus dalam `EncryptedLocalDatabase` class di `core/storage/`. | ✅ Menghasilkan typed queries. | N/A |

**Keputusan Arsitektur**:
- Gunakan `sqflite_sqlcipher: ^3.1.0` bersama `flutter_secure_storage: ^9.2.2` untuk pengelolaan kunci DEK.
- File database dinamai `eva_local_encrypted.db` di direktori database aplikasi terisolasi (`getDatabasesPath()`).

---

## 2. Arsitektur Manajemen Kunci (Key Management & DEK Wrapping)

```text
┌────────────────────────────────────────────────────────┐
│ Hardware-Backed Storage                                │
│ - Android: Android Keystore (MasterKey AES-256-GCM)    │
│ - iOS: iOS Keychain (kSecAttrAccessibleAfterFirstUnlock)│
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼ (Wrapped / Decrypted in TEE)
┌────────────────────────────────────────────────────────┐
│ 256-bit Data Encryption Key (DEK)                      │
│ - Dihasilkan melalui Random.secure() (32 bytes)        │
│ - Hanya berada di RAM selama database dibuka           │
│ - DILARANG disimpan di SharedPreferences atau Plaintext│
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ SQLCipher SQLite Database                              │
│ - PRAGMA key = '<hex_encoded_dek>';                    │
│ - Mengenkripsi seluruh pages, WAL, dan SHM files       │
└────────────────────────────────────────────────────────┘
```

### 2.1 Siklus Hidup Kunci (`DatabaseKeyService`):
1. **Inisialisasi Pertama**: Klien memeriksa apakah DEK untuk akun tertentu (`eva_dek_{local_account_key}`) sudah ada di `FlutterSecureStorage`.
2. Jika belum ada, buat 32 bytes acak via `Random.secure()`, encode hex/base64, dan simpan ke `FlutterSecureStorage`.
3. **Buka Database**: Ambil DEK dari secure storage dan kirimkan ke parameter `password` pada `openDatabase`.
4. **Logout / Ganti Akun**: Database ditutup secara eksplisit (`db.close()`), referensi objek dihapus dari memori, dan cache DEK di-clear.
5. **Reset Memori / Hapus Akun**: Panggil `deleteDatabase(dbPath)` diikuti penghapusan key di `FlutterSecureStorage` dan `PRAGMA secure_delete = ON`.

---

## 3. Isolasi Backup Sistem Operasi (Anti-Data Leakage)

Untuk mematuhi **OWASP MASVS Storage (MASWE-0006)**:
- **Android (`AndroidManifest.xml` & `backup_rules.xml`)**:
  Konfigurasikan agar file database SQLite dan shared preferences token dikecualikan dari Android Cloud Auto-Backup:
  ```xml
  <!-- res/xml/backup_rules.xml -->
  <backup-rules>
      <exclude domain="database" path="eva_local_encrypted.db" />
      <exclude domain="database" path="eva_local_encrypted.db-wal" />
      <exclude domain="database" path="eva_local_encrypted.db-shm" />
  </backup-rules>
  ```
- **iOS**:
  Terapkan flag `NSURLIsExcludedFromBackupKey` pada file database sehingga tidak ikut disinkronkan ke iCloud Backup tanpa enkripsi pengguna.

---

## 4. Konfigurasi Feature Flags & Strategi Default

Seluruh flag didefinisikan dengan default **aman dan fail-closed**:

| Nama Feature Flag | Tipe | Nilai Default | Deskripsi & Aturan Fail-Closed |
|---|---|---|---|
| `LOCAL_ENCRYPTED_MEMORY_ENABLED` | Boolean | `true` | Mengaktifkan penyimpanan LTM lokal terenkripsi di `apps/eva_mobile`. Jika `false`, personalisasi LTM nonaktif. |
| `LOCAL_JOURNAL_ENABLED` | Boolean | `true` | Mengalihkan pembacaan dan penyimpanan jurnal utama ke SQLCipher lokal pasien. |
| `PRIVATE_SESSION_NO_SERVER_PERSIST` | Boolean | `true` | Mematikan penulisan pesan/transkrip/DASS/jurnal ke PostgreSQL server untuk sesi privat. |
| `CLIENT_MEMORY_CONTEXT_V1_ENABLED` | Boolean | `true` | Mengaktifkan pengiriman bounded context via WS `client_context_v1`. |
| `SESSION_ARTIFACTS_V1_ENABLED` | Boolean | `true` | Mengaktifkan finalisasi artefak pasca-sesi via WebSocket. |
| `CLINICAL_SHARE_V1_ENABLED` | Boolean | `true` | Mengaktifkan paket berbagi keluhan & diagnosis profesional berskop ke psikolog. |
| `LEGACY_CROSS_SESSION_READ_ENABLED` | Boolean | `false` | **Default OFF**. Dilarang membaca riwayat pesan lampau dari PostgreSQL untuk sesi `local_private`. |
| `LEGACY_SENSITIVE_WRITE_ENABLED` | Boolean | `false` | **Default OFF**. Dilarang menuliskan transkrip percakapan ke PostgreSQL untuk sesi `local_private`. |

---

## 5. Exit Criteria P0 & Kesiapan Masuk P1

Dengan diselesaikannya keempat dokumen arsitektur P0:
1. `docs/local_memory/current_state_audit.md` (Peta Read/Write Sensitif Server & Client)
2. `docs/local_memory/privacy_data_flow.md` (Klasifikasi Data, Retensi, & Threat Model)
3. `docs/local_memory/api_contract_v1.md` (Spesifikasi Kontrak WebSocket & REST v1)
4. `docs/local_memory/storage_spike_and_feature_flags.md` (Spike SQLCipher & Feature Flags)

Seluruh titik masuk data sensitif telah teridentifikasi, cacat UI default consent telah dipetakan untuk dibenahi, dan fondasi kontrak telah terkunci tanpa asumsi spekulatif. Repositori siap melangkah ke implementasi **P1 — On-Device Encrypted Persistence (Flutter `apps/eva_mobile`)**.
