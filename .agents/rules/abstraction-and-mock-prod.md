---
trigger: model_decision
description: Aturan dan standar arsitektur abstraksi untuk switching antara Mock data/services dan Production (API/Cloud) di Flutter mobile dan Backend/AI.
---

# Abstraction & Mock vs Production Architecture Guidelines

Panduan ini mengatur standar arsitektur abstraksi (Dependency Inversion Principle) agar seluruh komponen di monorepo dapat beralih antara lingkungan **Mock (Offline/Local Development)** dan **Production (Live API/Cloud Services)** secara mulus tanpa mengubah kode logika bisnis atau antarmuka pengguna (UI).

---

## 1. Flutter Mobile (`apps/eva_mobile`)

### 1.1 Prinsip Utama: Dependency Inversion
- **UI Agnostic**: Lapisan Presentation (Widget, Screen, Dialog, BottomSheet) **DILARANG KERAS** mengetahui atau memeriksa apakah aplikasi sedang menggunakan data Mock atau Remote API.
- **Anti-Pattern Terlarang**:
  ```dart
  // ❌ ANTI-PATTERN: Dilarang memeriksa useMockData langsung di dalam Widget/Screen
  if (AppConfig.useMockData) {
    return _buildMockList();
  } else {
    return _buildRealList();
  }
  ```
- **Solusi Benar**: UI hanya mengonsumsi Riverpod Provider atau Use Case abstrak.
  ```dart
  // ✅ BENAR: UI murni mengamati provider
  final diariesAsync = ref.watch(diariesProvider);
  return diariesAsync.when(...);
  ```

### 1.2 Struktur Lapisan Abstraksi (Clean Architecture)
Setiap fitur (`lib/features/<feature_name>/`) wajib mengikuti pemisahan interface dan implementasi:
```text
features/<feature>/
├── domain/
│   ├── entities/              # Domain models (murni Dart)
│   └── repositories/          # Abstract contracts / Interfaces
│       └── <feature>_repository.dart
├── data/
│   ├── datasources/
│   │   ├── <feature>_datasource.dart       # Abstract DataSource interface
│   │   ├── mock_<feature>_datasource.dart  # Mock implementation (in-memory/fixtures)
│   │   └── remote_<feature>_datasource.dart# Real HTTP/Dio implementation
│   ├── models/                # DTOs / JSON parsing
│   └── repositories/
│       └── <feature>_repository_impl.dart  # Concrete repository implementing domain contract
└── presentation/
    ├── providers/             # Riverpod DI wiring (Single Point of Switching)
    │   └── <feature>_provider.dart
    └── screens / widgets/
```

### 1.3 Pola Riverpod Dependency Injection (Single Point of Switching)
Pergantian antara Mock dan Real DataSource hanya boleh didefinisikan pada **Provider Definition**:
```dart
// lib/features/diary/presentation/providers/diary_provider.dart
final diaryDataSourceProvider = Provider<DiaryDataSource>((ref) {
  if (AppConfig.useMockData) {
    return MockDiaryDataSource();
  }
  final apiClient = ref.watch(apiClientProvider);
  return RemoteDiaryDataSource(apiClient);
});

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final dataSource = ref.watch(diaryDataSourceProvider);
  return DiaryRepositoryImpl(dataSource);
});
```

### 1.4 Konfigurasi Environment Flag
Pastikan toggle Mock didukung baik secara runtime maupun compile-time:
```dart
// lib/config/app_config.dart
static bool useMockData = const bool.fromEnvironment('USE_MOCK_DATA', defaultValue: false);
```
Eksekusi mode:
- **Mock Mode**: `flutter run --dart-define=USE_MOCK_DATA=true`
- **Local Backend Mode**: `flutter run --dart-define=USE_LOCAL_API=true`
- **Production Mode**: `flutter run`

---

## 2. Backend & AI Engine (`apps/backend` & `packages/ai`)

### 2.1 Interface & Abstract Base Classes (ABCs)
Setiap komponen eksternal (LLM, TTS, STT, Vector Database, Storage) wajib didefinisikan sebagai Abstract Base Class di `packages/ai/interfaces/`:
```python
from abc import ABC, abstractmethod

class BaseLLMProvider(ABC):
    @abstractmethod
    async def generate_response(self, prompt: str, **kwargs) -> str:
        pass

    @abstractmethod
    async def stream_response(self, prompt: str, **kwargs):
        pass
```

### 2.2 Factory Pattern & Graceful Fallback
Instansiasi provider dilakukan terpusat melalui Factory (`packages/ai/factories/`):
- **Development Mode (`APP_ENV=development`)**:
  Jika API Key pihak ketiga (OpenAI, DeepSeek, ElevenLabs) kosong atau bernilai placeholder, Factory otomatis melakukan fallback ke `MockProvider` atau free provider (e.g. `EdgeTTSProvider`) dengan log peringatan terstruktur.
- **Production Mode (`APP_ENV=production`)**:
  Factory wajib memvalidasi ketersediaan kredensial secara ketat (fail-fast di startup) untuk mencegah *silent failure* saat deployment live.

```python
class LLMFactory:
    @classmethod
    def get_provider(cls, provider_type: str | None = None) -> BaseLLMProvider:
        target = (provider_type or settings.LLM_PROVIDER).lower()
        if target == "mock":
            return MockLLMProvider()
        if target == "openai":
            if not settings.LLM_API_KEY and settings.APP_ENV != "production":
                logger.warning("No API key, falling back to MockLLMProvider")
                return MockLLMProvider()
            return OpenAILLMProvider(api_key=settings.LLM_API_KEY)
        ...
```

### 2.3 Dependency Injection di FastAPI Endpoints
Endpoint di `apps/backend/api/app/api/routes` **DILARANG KERAS** menginisialisasi provider atau service konkret secara manual di dalam handler fungsi, dan dilarang mengorkestrasi provider AI/DB langsung di dalam router. Router wajib menginjeksi Domain Service via `Depends()`:
```python
# ✅ BENAR: Menggunakan Domain Service Injection & Pydantic response_model
@router.post("/chat/completions", response_model=ChatCompletionResponse)
async def chat_completion(
    payload: ChatRequest,
    service: ConversationService = Depends(get_conversation_service),
) -> ChatCompletionResponse:
    """Delegasikan prompt generation dan DB logging ke service domain."""
    return await service.generate_chat_reply(payload)
```
> **Catatan Arsitektur:** Provider konkret (`BaseLLMProvider`) diinjeksi ke dalam `ConversationService` melalui factory di `app/api/dependencies.py`, bukan di dalam router handler.

---

## 3. Checklist Verifikasi Saat Menulis / Mengubah Kode

1. [ ] Apakah ada `if (AppConfig.useMockData)` di file UI/Screen? **Jika ada, hapus dan pindahkan ke Riverpod provider.**
2. [ ] Apakah datasource baru memiliki interface abstrak dan implementasi ganda (`Mock*` dan `Remote*`)?
3. [ ] Apakah provider AI di backend mewarisi interface dari `packages/ai/interfaces/`?
4. [ ] Apakah endpoint backend mengandalkan `Depends(...)` untuk service eksternal?
5. [ ] Apakah skenario pengujian unit (unit test) dapat berjalan tanpa koneksi internet dengan memanfaatkan implementasi Mock?
