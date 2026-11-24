# IDCOLDA Android — Tide Flow Motion

Native Flutter application source for the existing IDCOLDA ASP.NET Core MVC backend. API: https://idcoldrs.com/api/v1. Existing Android application ID: com.techninxa.idcolda_ms. No separate database or backend.

## Windows build

Install Flutter 3.35.7, JDK 17 and Android Studio SDK. Run flutter doctor -v and flutter doctor --android-licenses. From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-android.ps1 -BuildDebug
```

Linux: bash setup-android.sh --build-debug. Setup restores only missing Gradle wrapper files from a temporary Flutter scaffold; it preserves the existing runner and package identity. It resolves dependencies, formats sources, runs static analysis and tests, and builds a debug APK when requested. After success: build/app/outputs/flutter-apk/app-debug.apk. Use flutter run with a connected device. The Flutter package name is idcolda; Android application ID remains com.techninxa.idcolda_ms.

## Java / Gradle compatibility on Windows

The verified CI toolchain is Flutter 3.35.7, JDK 17, Gradle 8.12, AGP 8.9.1 and Kotlin 2.1.0. Java 25 cannot run Gradle 8.12. Do not upgrade the Gradle wrapper alone.

Install JDK 17 if missing:

```powershell
winget install --id Microsoft.OpenJDK.17 --exact
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup-android.ps1 -ConfigureJdkOnly
flutter doctor -v
flutter clean
flutter pub get
flutter run
```

Setup discovers installed JDK 17 or accepts an explicit installation root through -JdkDir. It configures Flutter's user-level JDK setting (affects other Flutter projects), without uninstalling newer Java installations or committing machine-specific paths. Use the -BuildDebug switch for the full analyzer, tests and debug APK pipeline. If a custom Gradle user property overrides the JVM, review that local setting separately.

## Architecture

- lib/api.dart: HTTPS transport, rotating JWT sessions, secure storage, workspace tickets, JSON/form/multipart requests; no automatic write replay.
- lib/main.dart: animated splash, branded authentication, invitation flow, workspace selection, role-aware navigation, dashboard.
- lib/theme.dart: ocean-blue Tide Flow theme, curved backgrounds, animated solar illustration, company colors, Night mode.
- lib/catalog.dart and assets/routes.json: 151 route definitions and access-aware module metadata.
- lib/operations.dart: live operational lists, details, forms, uploads, hierarchy, inventory, client records, installation and sales.
- lib/copy.dart: partial Bengali localization.
- test/api_test.dart: mocked HTTP/route contract tests, not production requests.
- docs/api_parity_audit.md: MVC route audit and design mapping.

## Verification and safety

Backend baseline 08e53d4fc91a87abe4a12bd07a6d71bc8eb8f319; MVC draft PR #54 adds optional installer verification metadata, not deployed. Existing production API is used directly. The app does not contain server signing keys, passwords or database credentials. The server is the authority for all company access and permissions. Production mutations require explicit confirmation. Never use real customer records for destructive testing.

This is a source implementation candidate. Do not publish until GitHub Actions analyzer, unit tests and debug APK build pass, then test on real devices with designated accounts and test records. Route catalog completeness does not establish end-to-end feature parity. Full visual parity with every approved preview frame, Bengali copy, invitation App Links, installer SMS verification and release signing remain acceptance work. No inverter telemetry exists in the audited MVC baseline. Production SQL integration certification is not complete. Use the separate MVC repository for backend changes.
