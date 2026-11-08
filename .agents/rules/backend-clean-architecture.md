---
trigger: model_decision
description: Aturan dan standar Clean Architecture, Thin Routers (3-5 baris), modular services (app/services/{module}/), dan schemas (app/schemas/{module}/) untuk backend FastAPI di apps/backend.
---

# FastAPI Clean Architecture & Modular Backend Standards

> **Scope:** `apps/backend/api/**`, `apps/backend/workers/**`, `apps/backend/mcp/**`  
> **Tujuan:** Menjamin kode backend selalu menerapkan prinsip *Clean Architecture*, *Single Responsibility Principle* (SRP), *Dependency Injection* (DI), dan pemisahan modular berbasis domain agar setiap route handler sangat bersih (3–5 baris) dan tidak ada lagi *fat controllers* atau duplikasi kode.

---

## 1. Struktur Organisasi Modul (`services/` & `schemas/`)

Seluruh domain bisnis di `apps/backend/api/app` **wajib** dikelompokkan ke dalam paket folder modular:

```text
apps/backend/api/app/
├── api/
│   ├── dependencies.py          # Centralized DI (get_current_user, get_db, service factories)
│   └── routes/                  # Thin Route Handlers (3-5 baris per endpoint)
│       ├── auth.py
│       ├── user.py
│       ├── diaries.py
│       ├── recommendations.py
│       ├── conversations.py
│       ├── call.py
│       ├── dass.py
│       ├── analytics.py
│       └── health.py
├── schemas/                     # Strict Pydantic Contracts per Modul
│   └── {module}/
│       ├── __init__.py          # Barrel export seluruh model request & response
│       ├── requests.py          # Request body & query parameters
│       └── responses.py         # Response models (DTO)
├── services/                    # Domain Logic & Database Orchestration per Modul
│   └── {module}/
│       ├── __init__.py          # Barrel export service classes
│       ├── {name}_service.py    # Implementasi domain service
│       └── ...                  # Sub-komponen pendukung jika modul berat (heavyweight)
└── models/                      # SQLAlchemy Entities (Pure data models & relationships)
```

### Aturan Paket & Barrel Export (`__init__.py`):
1. Setiap subfolder di `app/schemas/{module}/` **wajib** memiliki `__init__.py` yang me-re-export semua class request dan response publik.
2. Setiap subfolder di `app/services/{module}/` **wajib** memiliki `__init__.py` yang me-re-export class service publik.
3. Import di level router harus bersih dan ringkas:
   ```python
   from app.schemas.auth import LoginRequest, TokenResponse
   from app.services.auth import AuthService
   ```

---

## 2. Invariant Thin Router (Maksimal 3–5 Baris per Endpoint)

Router FastAPI (`app/api/routes/*.py`) bertindak murni sebagai **HTTP Transport Controller**.

### ❌ Dilarang Keras di Router Handler:
1. **Dilarang Inline SQL**: Tidak boleh ada query SQLAlchemy (`select()`, `db.execute()`, `db.commit()`, `db.add()`) di dalam router. Seluruh interaksi database wajib di dalam class service.
2. **Dilarang Inline Business Logic / Calculations**: Kalkulasi persentase emosi, DASS scoring, pemrosesan teks, dan validasi krisis dilarang ditulis di router.
3. **Dilarang Raw Dictionary Returns**: Dilarang mengembalikan `dict[str, Any]` tanpa `response_model`. Seluruh endpoint HTTP REST wajib mendeklarasikan `response_model=...` menggunakan Pydantic schema dari `app/schemas/{module}/` (Kecuali streaming SSE yang mengembalikan `StreamingResponse` dan endpoint `@router.websocket`).
4. **Dilarang Menduplikasi `_get_current_user`**: Dilarang membuat fungsi privat `_get_current_user` di dalam file router. Seluruh autentikasi wajib mengimpor `get_current_user` dari `app.api.dependencies`.
5. **Dilarang Instansiasi Manual**: Dilarang memanggil `AsyncSessionLocal()`, `LLMFactory.get_provider()`, atau class service secara manual di dalam router. Gunakan FastAPI `Depends()`.

### ✅ Contoh Standar Thin Route (3–5 Baris):

```python
@router.post("/login", response_model=TokenResponse)
async def login(
    payload: LoginRequest,
    service: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    """Otentikasi pengguna dan terbitkan akses token."""
    return await service.login(payload)

@router.post("", response_model=DiaryEntryResponse, status_code=status.HTTP_201_CREATED)
async def create_diary(
    payload: CreateDiaryRequest,
    user: User = Depends(get_current_user),
    service: DiaryService = Depends(get_diary_service),
) -> DiaryEntryResponse:
    """Simpan refleksi harian pengguna."""
    return await service.create_entry(user_id=user.id, payload=payload)
```

### ✅ Contoh Standar Thin WebSocket Route:

```python
@router.websocket("/ws/{session_id}")
async def websocket_call_endpoint(
    websocket: WebSocket,
    session_id: str,
    token: str | None = None,
    voice_mode: str | None = None,
) -> None:
    """Delegasikan seluruh handshake, receive loop, turn handling, dan cleanup ke CallSessionManager."""
    await call_session_manager.handle_connection(
        websocket=websocket,
        session_id=session_id,
        token=token,
        voice_mode=voice_mode,
    )
```

---

## 3. Centralized Dependency Injection (`app/api/dependencies.py`)

Seluruh dependency provider dipusatkan di `app/api/dependencies.py`:

```python
# 1. Database & Security Providers
async def get_db_session() -> AsyncGenerator[AsyncSession, None]: ...
async def get_current_user(...) -> User: ...

# 2. Service Factory Providers
async def get_auth_service(db: AsyncSession = Depends(get_db_session)) -> AuthService:
    return AuthService(db)

async def get_user_service(db: AsyncSession = Depends(get_db_session)) -> UserService:
    return UserService(db)

async def get_diary_service(db: AsyncSession = Depends(get_db_session)) -> DiaryService:
    return DiaryService(db)
```

---

## 4. Pemisahan Modul Berat (*Heavyweight Modules*)

Untuk domain yang memiliki kompleksitas tinggi dan multi-komponen, wajib dipecah menjadi sub-service kolaborator di dalam folder modulnya:

### A. Modul Panggilan Suara & Real-time (`app/services/call/`)
- `session_manager.py`: Mengelola lifecycle WebSocket (`handle_connection`), state call (`idle`, `speaking`, `interrupted`), dan barge-in.
- `persistence.py`: Menangani penyimpanan sesi percakapan, transkrip turn, dan message duration ke database.
- `stream_buffer.py`: Mengelola buffer byte raw mic audio incoming.
- `turn_aggregator.py`: Mengagregasi turn pengguna dan deteksi completion.
- `turn_detector.py`: Evaluasi acoustic energy (RMS) dan sentence completion.

### B. Modul Deteksi Emosi (`app/services/emotion/`)
- `ml_detector.py`: Inferensi machine learning klasifikasi emosi suara/teks.
- `analyzer.py`: Heuristik fallback dan mapper bobot 7-emosi ke UI.

### C. Modul Percakapan & Diary (`app/services/conversation/` & `app/services/diary/`)
- Pisahkan operasi streaming SSE (misal ringkasan LLM token-by-token) ke dalam `summary_stream_service.py`.
- Pisahkan sintesis AI harian ke dalam `diary_generator.py` dan CRUD database ke dalam `diary_service.py`.

---

## 5. Kontrak Data Pydantic (Request & Response)

1. Semua data yang keluar dari API wajib melalui model Pydantic di `app/schemas/{module}/responses.py`.
2. Model Pydantic wajib mengaktifkan `from_attributes = True` jika membaca langsung dari model SQLAlchemy ORM:
   ```python
   class ConfigDict:
       from_attributes = True
   ```
3. Naming convention:
   - Request models berakhiran `Request` (contoh: `CreateDiaryRequest`, `RegisterRequest`).
   - Response models berakhiran `Response` atau `Item` (contoh: `DiaryEntryResponse`, `TokenResponse`, `MessageItem`).
   - Query filter models berakhiran `Filter` atau `Params` (contoh: `ConversationQueryParams`).

---

## 6. Protokol Verifikasi & Anti-Regression

Sebelum menyatakan pekerjaan refaktor atau pembuatan API baru selesai:
1. Jalankan `make test-backend` untuk memastikan semua endpoint lolos uji integritas.
2. Pastikan tidak ada `dict[str, Any]` yang tersisa sebagai tipe return di fungsi router.
3. Jalankan `make lint` dan `make format` untuk menjamin kerapian kode sesuai standar Ruff.
