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

## 5. Component Reuse & Design System Invariant
- **Reuse Existing Components First**: Before building custom UI elements or writing inline styling, ALWAYS check and reuse standard widgets in `lib/widgets/`:
  - `AppBackButton`: Standardized frosted circular back button across all screens.
  - `GlassCard`: Frosted glass container with rounded corners and gradient borders.
  - `AppSnackBar`: Standardized snackbar notification banners.
  - `SkeletonShimmer`: Standardized loading placeholder animations.
  - `CustomButton` & `CustomTextField`: Standardized input elements.
  - `StaggeredEntrance`: Fluid entrance animation wrapper.
- **No Inline Duplication**: Do not declare manual inline back buttons (`IconButton`, custom `BoxShape.circle`, etc.) directly inside screens. Always consume `AppBackButton`.
