# Shahid Finance — Build Notes (v1.0.0+1)

## Identity
- Package: namespace AND applicationId = `com.shahid.finance`
- `MainActivity.kt`: `package com.shahid.finance`, extends `FlutterFragmentActivity` (local_auth requirement; also the Hisab launch-crash lesson)
- App label: "Shahid Finance" · Launcher icons generated from the final emerald-S icon into all mipmap densities

## Architecture
- Flutter 3.47.5 / Dart 3.13.4, single font: **Plus Jakarta Sans** (static TTFs bundled in `assets/fonts/`, declared in pubspec — no runtime fetching, works fully offline)
- `lib/theme.dart` — design tokens exactly per master spec B (canvas #F1F7EE, brand #0E9F5A, deep #076B3A, hero gradient #12B76A→#076B3A→#043D21, expense #E5484D, warningText #7A5410, green-tinted shadows only; gradient only on hero/CTA/FAB)
- `lib/data/` — Hive local-first (boxes: wallets, transactions, budgets, categories, settings), hand-written TypeAdapters, balances always DERIVED from transactions. Seeds: 12 categories, 4 wallets (Cash/Easypaisa/JazzCash/Meezan, Easypaisa default) with ZERO balances, cycle start day = 1
- `lib/utils/format.dart` — Pakistani digit grouping (Rs 1,28,450), cycle math (start-day setting incl. last-day), pacing (nearest Rs 10), percent
- Screens (9): Onboarding (3 slides + setup + PIN set/skip) → PIN lock (salted SHA-256, 5 attempts, 30 s lockout, biometric via local_auth) → Home / Add Transaction / Transactions (search, §1.8 filter sheet, swipe + Undo, detail sheet) / Wallets (+ detail, transfer, adjust, archive) / Budgets (cycle stepper, pacing, on-track/near/over) / Reports (fl_chart bars + donut + insight) / Settings (profile, cloud backup, security, CSV export, cycle sheet)
- Amounts: whole rupees, tabular figures, shared right edge — per specs

## Cloud backup (user requirement)
- firebase_core + firebase_auth (Google + Email/Password) + cloud_firestore
- Snapshot = single doc `users/{uid}/backup/data` (all boxes as JSON + updatedAt); Back up now / Restore (confirm dialog) in Settings; auto-restore prompt after sign-in when local data is empty
- `Firebase.initializeApp()` is wrapped in try/catch: **the app runs perfectly with NO google-services.json** — the backup section then shows "not configured in this build"
- ⚠️ Before CI can exercise real Firebase: commit the real `google-services.json` to `android/app/` and register the release SHA-1 (9B:5D:84:36:B2:5E:22:5A:3C:21:BE:05:C5:DF:DA:10:AA:9B:28:2E) in the Firebase console. The google-services Gradle plugin is intentionally NOT applied yet — add it together with the json.

## CI (`.github/workflows/`)
- `build-apk.yml` — release APK; restores keystore from secret **`SHAHID_FINANCE_KEYSTORE_BASE64`** → `android/app/shahid-finance-release.keystore`, generates `key.properties` from **`SHAHID_FINANCE_KEYSTORE_PASSWORD`** (alias `shahidfinance`, PKCS12). Falls back to debug signing when secrets are absent.
- `smoke-test.yml` — build → Android 34 emulator boot → install/launch `com.shahid.finance/.MainActivity` → artifact **`shahid-finance-boot-test`** (screenshot, logcat, crash extract, pid)

## Local verification (2026-10-24)
- `flutter analyze` — **No issues found** (clean)
- `flutter test` — **3/3 pass**: Pakistani grouping formatter + cycle math unit tests; headless widget smoke test (temp-dir Hive → real app pumps → onboarding slide 1 renders, seed invariants asserted)
- No local APK build attempted (Gradle cannot run in this sandbox — by design; CI is the build route)

## Deviations / decisions the parent should know
1. **Budgets are standing per-category limits** in the data layer (`Budget{categoryId, limitAmount}`, no cycle key, no separate overall-budget record). The Budgets screen's overall card therefore AGGREGATES all category budgets vs total cycle spending; past cycles are view-only via the stepper.
2. **Delete account**: BackupService has no cloud-delete API, so the flow wipes local boxes, overwrites the cloud doc with the fresh empty snapshot, then signs out.
3. Dock tab 4 is labelled "Profile" in the shipped dock widget and hosts the Settings screen.
4. Settings footer uses the brief's exact text: "Shahid Finance · Version 1.0" / "Har rupay ka saaf hisaab."
5. Local git repo initialised + committed here; remote push (deploy key `~/.ssh/shahid_finance_deploy`) and CI secret creation are the parent's next steps.
