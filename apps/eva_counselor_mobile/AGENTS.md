# Eva Counselor Mobile (Flutter) - Sub-Workspace Rules

> Scope: `apps/eva_counselor_mobile/**`
> Target User Persona: Licensed Clinical Psychologist / Mental Health Counselor

## 1. Clean Architecture & Strict Layer Separation
- **Domain (`lib/features/<feature>/domain`)**:
  - Contains pure Dart entities and abstract repository contracts (e.g. `abstract class IPatientRepository`).
  - ZERO Flutter widget dependencies or network clients in this layer.
- **Data (`lib/features/<feature>/data`)**:
  - DTOs / Models with explicit `fromJson` and `toJson` schemas representing the exact backend API contract.
  - Dual data source implementations are mandatory: `Mock<Feature>DataSource` and `Remote<Feature>DataSource`.
  - Both data sources implement an abstract `<Feature>DataSource` contract.
  - Repository implementation (`<Feature>RepositoryImpl`) coordinates data sources and maps models to domain entities.
- **Presentation (`lib/features/<feature>/presentation`)**:
  - Riverpod providers bind data sources and repositories.
  - **STRICT PROHIBITION**: Widgets and screens must **NEVER** inspect `AppConfig.useMockData` or instantiate data sources directly.

## 2. Mock vs Production Switching
- Switching between local mock data and real backend API is governed strictly at the provider layer via `AppConfig.useMockData`.
- Support `--dart-define=USE_MOCK_DATA=true` or `--dart-define=USE_MOCK_DATA=false`.
- Real backend API points to `AppConfig.apiBaseUrl` (default: `https://eva.nexacode.dev/api/v1/counselor`).

## 3. Design System & Tokens
- Reuses the shared palette:
  - Primary: `0xFF5358CB` (Periwinkle)
  - Secondary: `0xFFE2DAFF` (Soft Lavender)
  - Tertiary: `0xFFA7E6FF` (Sky Blue)
  - Background: `0xFFF8F9FE` (Cool Tint Off-White)
  - Surface: `0xFFFFFFFF`
  - Font: `GoogleFonts.inter()`
