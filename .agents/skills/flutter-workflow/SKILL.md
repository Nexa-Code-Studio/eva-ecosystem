---
name: flutter-workflow
description: Execute Flutter mobile workflows for Eva Mobile, including switching between Mock data and Live API, running code analysis, unit tests, and automated USB/Emulator runners.
---

# Eva Mobile (Flutter) Workflow Runbook

Runbook for developing, building, and testing `apps/eva_mobile`.

## 1. Quick Makefile Runner (Recommended)

From the repository root:
```bash
# DEFAULT: Local API Stack (Port 8888)
make mobile-usb        # HP fisik via USB (auto adb reverse port 8888 -> 127.0.0.1:8888)
make mobile-emu        # Android Emulator (auto route gateway 10.0.2.2:8888)
make mobile-web        # Chrome Web Simulator (127.0.0.1:8888)
make mobile-mock       # Offline Mock Data (tanpa backend)

# CLOUD: Production Cloud Stack (eva.nexacode.dev)
make mobile-usb-cloud  # HP fisik nembak production cloud
make mobile-emu-cloud  # Android Emulator nembak production cloud
make mobile-web-cloud  # Chrome Web nembak production cloud
make mobile-cloud      # Shortcut alias ke mobile-usb-cloud
```

## 2. Manual Profile Execution

Execute commands from `apps/eva_mobile`:
```bash
cd apps/eva_mobile
```

### Profile A: Mock Mode (Offline / UI Testing)
Uses in-memory fixtures and `Mock*DataSource` without requiring the backend:
```bash
flutter run --dart-define=USE_MOCK_DATA=true
```

### Profile B: Local Backend (Desktop / Web / USB Connected Device)
Connects to local FastAPI backend on `127.0.0.1:8888`:
```bash
# For USB Android device (forward port first):
adb reverse tcp:8888 tcp:8888

# Run with local API flag:
flutter run --dart-define=USE_LOCAL_API=true
```

### Profile C: Android Emulator
Connects to local FastAPI backend on host via `10.0.2.2:8888`:
```bash
flutter run --dart-define=API_BASE_URL="http://10.0.2.2:8888/api/v1"
```

## 3. Code Analysis & Tests

```bash
# Static analysis
flutter analyze

# Unit and widget tests
flutter test
```
