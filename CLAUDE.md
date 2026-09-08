# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo at a glance

**PharmacyApp** is a **Flutter desktop** application backed by a **local SQLite database** (Drift). The app is organized by feature folders under `lib/features/`, and shared services/components live under `lib/core/`.

Entry point:
- `lib/main.dart` initializes the database and mounts the app shell (`AppShell`) that switches between feature screens.

## How to run common development tasks

### Install dependencies
```sh
flutter pub get
```

### Run the app
```sh
flutter run
```

### Static analysis / lint
```sh
flutter analyze
```

### Run tests (all)
```sh
flutter test
```

### Run a single Flutter test file
```sh
flutter test test/widget_test.dart
```

### Generate Drift code (if the project uses codegen in your workflow)
```sh
flutter pub run build_runner build
```

## Code architecture (big picture)

### Application shell and navigation
- `lib/main.dart` sets `AppShell` with a `NavigationRail` and an `IndexedStack` of screens.
- Screens are instantiated once and kept alive (so tab state is preserved).

Key screens imported by `main.dart`:
- Dashboard
- Patients
- Billing
- Inventory
- Agency purchase
- Reports
- Maintenance

### Database / persistence
- Database initialization happens in `main()` via `DatabaseProvider.instance.init()`.
- `AppShell` consumes database streams (e.g., low-stock / expiring badges) using `db.watchLowStockMedicines()` and `db.watchExpiringMedicines()`.

Where to start when changing persistence behavior:
- `lib/core/database/` (look for the Drift/DAO wiring and any stream helpers)

### Feature structure
Look under `lib/features/<feature_name>/` for:
- `screens/` (UI entry points)
- likely `widgets/`, `controllers/`, and database/DAO helpers (varies by feature)

Typical flow when debugging a feature:
1. Identify the screen in `lib/features/**/screens/`
2. Trace UI interactions to their controllers/services or repository calls
3. Follow database calls into `lib/core/database/` or feature-specific Drift tables/DAOs
4. If data is reactive, trace the relevant Drift streams back to the screen

## Dev scripts & CI hints

There is a GitHub Actions workflow for Windows builds that runs:
- `flutter test`
- `flutter build windows --release`

If CI breaks for Windows, focus first on:
- `pubspec.yaml` dependency constraints
- platform-specific integration under `windows/`
- any test expectations in `test/`

## Design/UX expectations

This repository’s UI is designed for desktop use with a Material theme and tab switching via `NavigationRail`.

If you need to change styling broadly, start in:
- `lib/core/theme/` (app theme definitions)

## Documentation to consult
- `README.md` (high-level features and getting started)
- `docs/UserGuide.md` (user-facing workflows for each module; useful for matching intended behavior)
