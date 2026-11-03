# Eva Mobile (Flutter) - Sub-Workspace Rules

> Scope: `apps/eva_mobile/**`

## 1. Clean Architecture & Layering Rules
- **Domain (`lib/features/<feature>/domain`)**:
  - Contains pure Dart entities and abstract repository contracts (e.g. `abstract class IChatRepository`).
  - No Flutter widget dependencies or network clients in this layer.
- **Data (`lib/features/<feature>/data`)**:
  - Dual data source implementations are mandatory: `Mock<Feature>DataSource` and `Remote<Feature>DataSource`.
  - Both data sources must implement an abstract `<Feature>DataSource` contract.
  - Repository implementation (`<Feature>RepositoryImpl`) coordinates data sources and maps models to domain entities.
- **Presentation (`lib/features/<feature>/presentation`)**:
  - Riverpod providers bind data sources and repositories.
  - **STRICT PROHIBITION**: Widgets and screens must **NEVER** inspect `AppConfig.useMockData` or instantiate data sources directly.

## 2. Riverpod & State Management
- Prefer pure Dart models with explicit `fromJson`, `toJson`, and `copyWith` methods.
- Define providers in `presentation/providers/`.
- Use `AsyncValue` (`when`, `maybeWhen`) to handle loading, error, and data states in widgets cleanly.

## 3. Mock vs Production Execution
- Configure mock mode strictly at the provider layer using `AppConfig.useMockData`.
- Support compile-time define `--dart-define=USE_MOCK_DATA=true`.
- Local API testing: `--dart-define=USE_LOCAL_API=true` (`127.0.0.1:8888` or `10.0.2.2:8888` for emulator).

## 4. Component Cohesion & Natural Boundaries
- Keep screen files cohesive as **Layout Coordinators**: do not over-fragment small private layout helpers that belong exclusively to the screen.
- Extract components when they cross natural boundaries:
  - Complex custom rendering (`CustomPainter` classes).
  - Independent lifecycles (`Timer`, breath pacer, separate `TickerProvider`).
  - Multi-step interactive modals or bottom sheets.
  - Reusable loaders (skeleton shimmer) and buttons.
- Place extracted widgets into `features/<feature>/presentation/widgets/`.
