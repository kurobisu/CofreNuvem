# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

CofreNuvem is a Flutter finance-management app (accounts, transactions, credit cards, investments, shared shopping lists, and family expense sharing) targeting **Windows desktop** as the primary distribution platform, with the standard Flutter mobile/web targets also present. UI strings, comments, and database column/table names are in Portuguese (pt-BR).

The backend is **Supabase** (Postgres + Auth + RLS + RPC) — there is no local SQLite persistence anymore even though `sqflite`/`sqflite_common_ffi` remain in `pubspec.yaml` and stray `.db`/`.b64` files and `test_sqlite*.dart` scripts sit in the repo root as leftovers from an earlier local-DB architecture. Ignore `db1.db`, `db2.db`, `db_maria.sqlite`, `*.b64`, `backup/`, and `scratch/` — they are not part of the live app.

## Commands

```bash
flutter pub get                          # install dependencies
flutter run -d windows                   # run on Windows desktop (primary target)
flutter analyze                          # static analysis (flutter_lints via analysis_options.yaml)
flutter test                             # run all tests
flutter test test/version_helper_test.dart   # run a single test file
```

A `.env` file (git-ignored) is required at the project root before running the app — copy `.env.example` and fill in:
```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...
UPDATE_CHECK_URL=https://raw.githubusercontent.com/kurobisu/CofreNuvem/main/latest.json
```
`.env` is bundled as a Flutter asset (see `pubspec.yaml` → `flutter.assets`) and loaded by `flutter_dotenv` in `main()` — **except** on the web build, where `main()` prefers `SUPABASE_URL`/`SUPABASE_ANON_KEY` passed via `--dart-define` (see below) and never calls `dotenv.load()` if those are present, so the raw `.env` file is never fetched as a public static asset.

### Windows installer / release build

```powershell
.\installer\build_installer.ps1
```
Produces `build\windows\x64\installer\CofreNuvem-Setup-<version>.exe` via Inno Setup. Full release process (version bump, tagging, CI, update-cycle validation) is documented in [installer/UPDATE_CYCLE.md](installer/UPDATE_CYCLE.md) — read it before cutting a release. In short: bump `appVersion` in [lib/utils/app_version.dart](lib/utils/app_version.dart), commit, then push a `vX.Y.Z` tag; [.github/workflows/release_windows.yml](.github/workflows/release_windows.yml) builds the installer, creates the GitHub Release, and updates `latest.json` on `main` (which the running app polls on launch to offer a self-update via `UpdateService`).

### Web deployment (GitHub Pages)

`flutter build web` works and is deployed automatically: [.github/workflows/deploy_web.yml](.github/workflows/deploy_web.yml) runs on every push to `main`, builds with `--base-href "/CofreNuvem/"` and `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` (reusing the same repo secrets as the Windows workflow), and deploys `build/web` to GitHub Pages via `actions/deploy-pages`. It writes an empty placeholder `.env` before building purely to satisfy the asset declared in `pubspec.yaml` — the real values come from the dart-define, never from that placeholder. Requires the one-time repo setting **Settings → Pages → Source = GitHub Actions**. The Windows self-updater (`UpdateService`) and Google Drive sync stub are both already gated to their intended platforms and are silent no-ops on web.

## Git workflow

Per [.agents/rules/github_workflow.md](.agents/rules/github_workflow.md): before starting any fix/update/change, check `git status` and commit + push any pending changes first (unless the user explicitly says not to).

## Architecture

### Data layer — Supabase, not a repository/DAO pattern

There is a single access point, [lib/database/supabase_helper.dart](lib/database/supabase_helper.dart):
- `SupabaseHelper.instance` exposes table-name constants (`tableUsuarios`, `tableTransacoes`, etc.) and `SupabaseHelper.instance.client` (the raw `SupabaseClient`).
- `OnlineProxy` wraps `SupabaseClient` with a `query`/`insert`/`update`/`delete` API shaped like the old `sqflite` interface (a migration shim from the previous local-DB version). Its `query()` only understands a small hardcoded set of `where`/`whereArgs` patterns (e.g. `usuario_id =`, `parent_id is null`) — it is **not** a general SQL translator. New code generally talks to `SupabaseHelper.instance.client` directly with the Supabase query builder (`.from(table).select(...).eq(...)`) rather than going through `OnlineProxy`, especially for anything needing joins/embeds (see `dashboard_provider.dart`).
- `delete()` is a **soft delete**: it sets `deleted_at`, never removes rows. All reads must filter `deleted_at is null` (already done inside `OnlineProxy.query`, but raw `client.from(...)` calls elsewhere add `.filter('deleted_at', 'is', null)` manually — remember to do the same in new raw queries).
- `CaseInsensitiveMap` wraps every row returned from Supabase because callers historically expect PascalCase keys (`Valor`, `Tipo`, `Data`) from the old SQLite schema while Postgres returns snake_case/lowercase (`valor`, `tipo`, `data`). Expect `row['Foo'] ?? row['foo']`-style lookups throughout provider/screen code — this is intentional, not a bug to "clean up".

`google_auth_client.dart` / `SyncService` ([lib/services/sync_service.dart](lib/services/sync_service.dart)) are a **mocked/disabled** leftover Google Drive sync path — `google_sign_in` has no Windows support, so `SyncService` on this platform is a no-op stub. Don't build on it without checking platform support first.

### State management — Riverpod

`flutter_riverpod` (v3) is used throughout via `ProviderScope` in `main.dart`. Common patterns in [lib/providers/](lib/providers/):
- `FutureProvider` for one-shot async fetches (e.g. `dashboardDataProvider` in [lib/providers/dashboard_provider.dart](lib/providers/dashboard_provider.dart), which aggregates balances, category spend, recent transactions, and credit-card usage from a single `transacoes` fetch with embedded joins).
- `NotifierProvider` / `AsyncNotifierProvider` for local persisted UI state backed by `shared_preferences` (e.g. `hideBalanceProvider`, `settingsProvider`).
- Providers query Supabase directly rather than going through a repository layer — screens `ref.watch`/`ref.read` providers that themselves call `SupabaseHelper.instance.client`.

### Auth & family sharing

Auth is Supabase email/password (`signInWithPassword`, `signUp`, `resetPasswordForEmail` in [lib/screens/login_screen.dart](lib/screens/login_screen.dart)). `main.dart`'s `AuthWrapper` listens to `Supabase.instance.client.auth.onAuthStateChange` and switches between `LoginScreen` and `MainScreen`.

Multi-user "family" sharing (inviting other accounts to share data) is implemented entirely through **Postgres RPC functions** (`get_pending_invites`, `reject_family_invite`, an accept-invite RPC, etc. — see [lib/screens/family_screen.dart](lib/screens/family_screen.dart)), backed by `SECURITY DEFINER` functions rather than direct table access. The `familias`/`familia_membros` tables have RLS enabled with a deny-all-direct-access policy — all reads/writes to those tables must go through RPCs, never `client.from('familias')`. See [scripts/supabase_security_fixes.sql](scripts/supabase_security_fixes.sql) for the RLS/grant setup this depends on (apply manually in the Supabase SQL Editor; it's not run by any migration tooling).

### Navigation

No named-route-per-screen setup beyond a handful of routes registered in `main.dart` (`/manage_categories`, `/manage_accounts`, `/manage_users`, `/history`). Primary navigation is an `IndexedStack`-less bottom `NavigationBar` in [lib/screens/main_screen.dart](lib/screens/main_screen.dart) switching between Dashboard, Shopping List, Investments, and Settings tabs; other screens are pushed with `Navigator.push(MaterialPageRoute(...))`.

### In-app update mechanism (Windows)

[lib/services/update_service.dart](lib/services/update_service.dart) polls `UPDATE_CHECK_URL` (→ `latest.json` in this repo, served raw from GitHub) on launch, compares versions via [lib/utils/version_helper.dart](lib/utils/version_helper.dart) against `appVersion` in `app_version.dart`, and if newer, downloads and silently runs the Inno Setup installer with `/CLOSEAPPLICATIONS /RESTARTAPPLICATIONS`, then `exit(0)`s so Inno Setup can take over. This is Windows-only (`installUpdate` throws `UnsupportedError` elsewhere).
