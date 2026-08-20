# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

CofreNuvem is a Flutter finance-management app (accounts, transactions, credit cards, investments, financial goals, shared shopping lists with a family product catalog, and family expense sharing) targeting **Windows desktop** as the primary distribution platform, with the standard Flutter mobile/web targets also present. UI strings, comments, and database column/table names are in Portuguese (pt-BR).

The backend is **Supabase** (Postgres + Auth + RLS + RPC) — there is no local SQLite persistence anymore even though `sqflite`/`sqflite_common_ffi` remain in `pubspec.yaml` and stray `.db`/`.b64` files and `test_sqlite*.dart` scripts sit in the repo root as leftovers from an earlier local-DB architecture. Ignore `db1.db`, `db2.db`, `db_maria.sqlite`, `*.b64`, `backup/`, and `scratch/` — they are not part of the live app.

There is no migration tool — every schema change ships as a standalone SQL file in [scripts/](scripts/) that a human runs manually in the Supabase SQL Editor. See [Manual SQL migrations](#manual-sql-migrations) below for the full inventory. **When you add a new column/table, write the accompanying script, tell the user to run it, and make the Dart code degrade gracefully (try/catch, no crash) for the window before they do** — this is the established pattern throughout the codebase (see e.g. `ListasComprasRepo.concluirLista`'s retry-without-the-new-column fallback).

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

### Local web testing (live, against real Supabase data)

`.claude/launch.json` defines two dev-server configs:
- `cofrenuvem-web` (port 8765) — real `flutter run -d web-server` with hot reload.
- `cofrenuvem-web-release` (port 8766) — `scripts/serve_web.ps1` serving a **static, pre-built** `build/web` folder. It does **not** rebuild on its own — after editing Dart code you must run `flutter build web` yourself, then just reload the browser tab (no cache headers on that server, a plain navigate/reload is enough).

These two are **different origins**, so a Supabase auth session (browser localStorage, per-origin) does not carry over between them. If the user has already logged in on the 8766 tab in-session, prefer the rebuild-and-reload-8766 workflow over switching to 8765 (which would need a fresh login — never enter credentials yourself).

### Windows installer / release build

```powershell
.\installer\build_installer.ps1
```
Produces `build\windows\x64\installer\CofreNuvem-Setup-<version>.exe` via Inno Setup. Full release process (version bump, tagging, CI, update-cycle validation) is documented in [installer/UPDATE_CYCLE.md](installer/UPDATE_CYCLE.md) — read it before cutting a release. In short: bump `appVersion` in [lib/utils/app_version.dart](lib/utils/app_version.dart), commit, then push a `vX.Y.Z` tag; [.github/workflows/release_windows.yml](.github/workflows/release_windows.yml) builds the installer, creates the GitHub Release, and updates `latest.json` on `main` (which the running app polls on launch to offer a self-update via `UpdateService`). **Only bump the version / push a tag when the user explicitly asks for a release** — a plain "push the changes" means a normal commit to `main`, not a version bump (that triggers CI and auto-updates every running Windows install).

### Web deployment (GitHub Pages)

`flutter build web` works and is deployed automatically: [.github/workflows/deploy_web.yml](.github/workflows/deploy_web.yml) runs on every push to `main`, builds with `--base-href "/CofreNuvem/"` and `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` (reusing the same repo secrets as the Windows workflow), and deploys `build/web` to GitHub Pages via `actions/deploy-pages`. It writes an empty placeholder `.env` before building purely to satisfy the asset declared in `pubspec.yaml` — the real values come from the dart-define, never from that placeholder. Requires the one-time repo setting **Settings → Pages → Source = GitHub Actions**. The Windows self-updater (`UpdateService`) and Google Drive sync stub are both already gated to their intended platforms and are silent no-ops on web.

## Git workflow

Per [.agents/rules/github_workflow.md](.agents/rules/github_workflow.md): before starting any fix/update/change, check `git status` and commit + push any pending changes first (unless the user explicitly says not to). Never commit or push without the user explicitly asking in that specific moment, even mid-session — a general "go ahead and build this" is not standing permission to also push it.

## Architecture

### Data layer — Supabase, not a repository/DAO pattern

There is a single access point, [lib/database/supabase_helper.dart](lib/database/supabase_helper.dart):
- `SupabaseHelper.instance` exposes table-name constants (`tableUsuarios`, `tableTransacoes`, etc.) and `SupabaseHelper.instance.client` (the raw `SupabaseClient`).
- `OnlineProxy` wraps `SupabaseClient` with a `query`/`insert`/`update`/`delete` API shaped like the old `sqflite` interface (a migration shim from the previous local-DB version). Its `query()` only understands a small hardcoded set of `where`/`whereArgs` patterns (e.g. `usuario_id =`, `parent_id is null`), matched by checking whether the `where` **string** contains one of those substrings — and **the whole matching block is skipped entirely whenever `whereArgs` is null or empty**, even if `where` looks like a complete SQL condition. Concretely, `db.query(tableCategorias, where: "Nome = 'Mercado'")` (no `whereArgs`) applies **no filter at all** and silently returns every row — this shipped as a real bug once (see `lista_detalhe_screen.dart` git history). The fix is always to pass the value through `whereArgs` in the exact supported shape (`where: 'nome =', whereArgs: ['Mercado']`), or better, skip `OnlineProxy` and call `SupabaseHelper.instance.client.from(table).select(...).eq(...)` directly — this is what all new code should do, especially anything needing joins/embeds, multi-column filters, or `.order()` (see `dashboard_provider.dart`, `listas_compras_provider.dart`).
- `delete()` is a **soft delete**: it sets `deleted_at`, never removes rows. All reads must filter `deleted_at is null` (already done inside `OnlineProxy.query`, but raw `client.from(...)` calls elsewhere add `.filter('deleted_at', 'is', null)` manually — remember to do the same in new raw queries).
- `CaseInsensitiveMap` wraps every row returned from Supabase because callers historically expect PascalCase keys (`Valor`, `Tipo`, `Data`) from the old SQLite schema while Postgres returns snake_case/lowercase (`valor`, `tipo`, `data`). Expect `row['Foo'] ?? row['foo']`-style lookups throughout provider/screen code — this is intentional, not a bug to "clean up". **This wrapping only happens inside `OnlineProxy`** — rows read via the raw `client.from(...)` (bypassing `OnlineProxy`) come back as plain maps with whatever casing Postgres actually uses (always lowercase snake_case for every table in this schema), so use lowercase keys directly (`row['valor']`, not `row['Valor']`) when you skip the shim.

`google_auth_client.dart` / `SyncService` ([lib/services/sync_service.dart](lib/services/sync_service.dart)) are a **mocked/disabled** leftover Google Drive sync path — `google_sign_in` has no Windows support, so `SyncService` on this platform is a no-op stub. Don't build on it without checking platform support first.

### State management — Riverpod

`flutter_riverpod` (v3) is used throughout via `ProviderScope` in `main.dart`. Common patterns in [lib/providers/](lib/providers/):
- `FutureProvider` for one-shot async fetches (e.g. `dashboardDataProvider` in [lib/providers/dashboard_provider.dart](lib/providers/dashboard_provider.dart), which aggregates balances, category spend, recent transactions, and credit-card usage from a single `transacoes` fetch with embedded joins).
- `NotifierProvider` / `AsyncNotifierProvider` for local persisted UI state backed by `shared_preferences` (e.g. `hideBalanceProvider`, `settingsProvider`).
- Providers query Supabase directly rather than going through a repository layer — screens `ref.watch`/`ref.read` providers that themselves call `SupabaseHelper.instance.client`.
- **Plain (non-`.autoDispose`) `FutureProvider`/`FutureProvider.family` instances cache their last value for the life of the app session**, not just while a widget is watching them. Concretely: `listaInfoProvider(listaId)` (see below) keeps serving a stale `status: 'Ativa'` after the list is concluded elsewhere unless something explicitly calls `ref.invalidate(listaInfoProvider(listaId))` right after the mutation. Any time you mutate data that a cached provider already returned once this session, invalidate that exact provider instance — don't assume a fresh screen instance means fresh data.

### Auth & family sharing

Auth is Supabase email/password (`signInWithPassword`, `signUp`, `resetPasswordForEmail` in [lib/screens/login_screen.dart](lib/screens/login_screen.dart)). `main.dart`'s `AuthWrapper` listens to `Supabase.instance.client.auth.onAuthStateChange` and switches between `LoginScreen` and `MainScreen`.

Multi-user "family" sharing (inviting other accounts to share data) is implemented entirely through **Postgres RPC functions** (`get_pending_invites`, `reject_family_invite`, an accept-invite RPC, etc. — see [lib/screens/family_screen.dart](lib/screens/family_screen.dart)), backed by `SECURITY DEFINER` functions rather than direct table access. The `familias`/`familia_membros` tables have RLS enabled with a deny-all-direct-access policy — all reads/writes to those tables must go through RPCs, never `client.from('familias')`. See [scripts/supabase_security_fixes.sql](scripts/supabase_security_fixes.sql) for the RLS/grant setup this depends on.

Most other family-shared tables (including everything in the Compras module below) use a simpler, uniform RLS shape instead of RPCs — a `get_my_family_auth_ids()` helper function, checked directly in each table's policy:
```sql
using (auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid())
with check (auth_id in (select get_my_family_auth_ids()) or auth_id = auth.uid())
```
New family-shared tables should follow this pattern (see `scripts/add_shopping_lists_catalog.sql` / `scripts/add_produto_marcas.sql`) unless there's a specific reason to add another RPC-gated table like `familias`.

### Compras — shopping lists + family product catalog

The biggest subsystem in the app. Entry point is the **Compras** bottom-nav tab → [lib/screens/listas_screen.dart](lib/screens/listas_screen.dart) (`ListasScreen`, shows active lists). This whole module was rebuilt from a flat single shopping list into multi-list + shared catalog; read this section before touching any of it.

**Data model** (all family-shared via the RLS shape above, all soft-deleted via `deleted_at`):
- `listas_compras` — one row per named list (`nome`, `status`: `'Ativa'` | `'Concluida'`, `mercado` — free-text store name, `transacao_id` — set once when the list is finalized, links to the `transacoes` row it created).
- `lista_compras` — **the pre-existing legacy items table**, repurposed as "items in a list" (`lista_id`, `produto_id`, `marca_id`, `nome`, `preco`, `quantidade`, `unidade`, `comprado`). Its name is easy to confuse with `listas_compras` — always double check which constant you're using (`SupabaseHelper.tableListaCompras` = items, `tableListasCompras` = the lists themselves).
- `produtos_catalogo` — the shared family product catalog (`nome`, `emoji`, `categoria_id` — **NOT NULL**, `tags[]`, `unidade_padrao`). `auth_id` null = system-seeded product visible to everyone; set = family-custom product.
- `categorias_produtos` — fixed taxonomy (`nome`, `grupo`, `emoji`, `ordem`), **read-only from the client** (RLS only grants `select`) — new categories can only be added by running SQL manually, never from app code. Includes a sentinel `"Sem categoria"` row (`scripts/add_sem_categoria.sql`) used as the fallback for `produtos_catalogo.categoria_id` when a user creates a product without picking a category (that column is NOT NULL, so the app always needs a valid id in hand — see `CatalogoRepo.categoriaSemCategoriaId()`).
- `produto_marcas` — brand variants of a catalog product (e.g. "Café" → "NesCafé" / "São Braz" as two rows, same `produto_id`). **There is no separate price-history table for brands** — `lista_compras.preco` already tracks price history per `produto_id`; adding `marca_id` to both `lista_compras` and the history lookup widens the same mechanism to a `(produto_id, marca_id)` composite key instead of building a parallel system. See `chaveProdutoMarca()` in `listas_compras_provider.dart` and the brand-aware `buscarEmojiEHistorico()` in `produto_item_sheet.dart`.

**Screens** (all under [lib/screens/](lib/screens/) unless noted):
- `ListasScreen` — home tab, active lists + "Criar lista" + a "Catálogo" entry point in the AppBar (reachable even with zero lists) + a history icon to `HistoricoListasScreen`.
- `ListaDetalheScreen` — items inside one list. **Reused for both `'Ativa'` and `'Concluida'` lists** (a concluded list is fully editable, not read-only — see below); reads `status` via `listaInfoProvider` to decide whether to show a "Concluída" badge and hide "Finalizar compra" from the kebab menu.
- `CatalogoScreen` (+ `CategoriaProdutosScreen` for one category/tag drill-down) — browse/search the shared catalog, 3 tabs: Popular (top 15 most-added products), Catálogo (by category), Relatórios (`ComprasRelatoriosTab`, in [lib/widgets/relatorios_compras.dart](lib/widgets/relatorios_compras.dart) — spending by category, most-frequent products, monthly spend, with a Mercado filter). `listaId` is **nullable** here: opened from `ListasScreen` with no list context, browsing/Relatórios still work, but tapping "add to list" shows a "Crie uma Lista de Compras primeiro" snackbar instead of crashing.
- `HistoricoListasScreen` — concluded lists, cards show `mercado` + total `valorTotal` directly (no need to open the list). Card kebab menu: "Copiar itens" (duplicates into a new active list) and "Excluir lista" (triple confirmation, see below).
- [lib/widgets/produto_item_sheet.dart](lib/widgets/produto_item_sheet.dart) `showProdutoItemSheet(...)` — the add/edit-item bottom sheet, by far the most complex widget in the module: name autocomplete against the catalog, brand chip selector (auto-fills price from that brand's own history when selected), price-vs-last-time diff display, unit/quantity steppers, and on Salvar either creates a new catalog product (defaulting to "Sem categoria") or updates the existing one, then upserts the `lista_compras` row. `editarCatalogo: true` additionally shows an icon/tags editor and "Excluir produto do catálogo" (double confirmation, soft-delete — existing list items keep their name/price, they just stop being suggested).

**Finalizar compra → linked transação, and editing after conclusion**: `ListaDetalheScreen._finalizarCompra` totals the checked (`comprado`) items, resolves (or creates) a `"Mercado"` transaction category — matched by `nome = 'Mercado' and parent_id is null`, not just by name, because production data has **two duplicate root-level "Mercado" categorias** (see the `TransactionFormScreen._updateCategoriasAtivas` name-based fallback match for the other half of this fix) — then pushes `TransactionFormScreen`, and only on an actual save (`Navigator.pop(context, insertedTransacaoId)`, not a bare `true`) calls `ListasComprasRepo.concluirLista(listaId, transacaoId: ...)`, which flips `status` **and** stamps `listas_compras.transacao_id` in one update. Because the list stays editable afterward, every mutation on a concluded list (toggle comprado, save an item, remove an item, "marcar/desmarcar todos") also calls `ListasComprasRepo.sincronizarTransacaoDaLista(listaId)`, which recomputes `sum(preco*quantidade)` over the current `comprado=true` items and pushes it to `transacoes.valor` — skipped (no-op, not an error) if the transação turns out to be part of an installment group (`parcela_total > 1`), since a per-installment total can't be safely redistributed automatically. Deleting a **concluded** list (`ListasComprasRepo.excluirConcluida`) cascades to soft-delete the linked transação too (the whole `grupo_parcela_id` group if it was parceled) — deleting an **active** list does not, since there's nothing to unlink.

**Verifying "which transação is linked, and for how much"** always goes through `ListasComprasRepo.valorTransacaoVinculada(listaId)` (a real query against `listas_compras.transacao_id` → `transacoes.valor`) — never approximate it from the list's own item total, which can drift from the transação's real value if sync ever failed (e.g. before the `transacao_id` column existed) and is misleading to show as "the linked transaction's amount" in a delete-confirmation dialog.

### Financial goals (metas)

Small, self-contained feature inside the Investments tab. [lib/utils/goal_projection.dart](lib/utils/goal_projection.dart) is a pure calculation class (`GoalProjection`: `progress`, `monthsToReach`, `requiredMonthlyContribution`) with its own unit tests in `test/goal_projection_test.dart`. [lib/providers/goals_provider.dart](lib/providers/goals_provider.dart) exposes `netWorthProvider` and `goalsProvider` (reads the `metas` table, `scripts/add_metas_financeiras.sql`). UI is [lib/widgets/goals_section.dart](lib/widgets/goals_section.dart), embedded in `InvestmentsScreen`.

### Per-screen help: guided tutorials + field help icons

Modeled on the same pattern built for the sibling app `menuvem_lojista`. There is **no global first-run tour** — each screen teaches itself, in the context where the explanation actually makes sense, via two independent mechanisms:

**1. Per-screen spotlight tutorial.** [lib/providers/tutorial_provider.dart](lib/providers/tutorial_provider.dart): `TutorialController` (a `Notifier<TutorialState>`) steps through a `List<TutorialStep>` ([lib/utils/tutorial_step.dart](lib/utils/tutorial_step.dart): `title`, `description`, optional `targetKey`) that always belongs to **one screen** — the controller never navigates between routes. [lib/widgets/tutorial_overlay.dart](lib/widgets/tutorial_overlay.dart) is mounted once at the root (`MaterialApp.builder` in `main.dart`) and draws the pulsing spotlight + bubble whenever a tutorial is active; a step with no `targetKey` (or a target not yet mounted) falls back to a centered card instead of failing. [lib/widgets/tutorial_button.dart](lib/widgets/tutorial_button.dart)'s `TutorialButton(screen: ...)` goes in each screen's `AppBar.actions`: it reopens that screen's tutorial on tap, and auto-starts once per screen on first visit (`TutorialSeenRepository`, key `tutorial_<screen>_seen` in `shared_preferences` — independent per screen, unlike the old single `tutorial_completed` flag). Content lives in [lib/utils/tutorial_content.dart](lib/utils/tutorial_content.dart) (`TutorialScreens` ids + `tutorialStepsFor(screen)`); target `GlobalKey`s are centralized in [lib/utils/tutorial_keys.dart](lib/utils/tutorial_keys.dart) so content doesn't depend on where a screen declares its widgets.

**2. Field help icons.** [lib/widgets/help_icon_button.dart](lib/widgets/help_icon_button.dart): `HelpIconButton` (a "?" icon — use as `suffixIcon`/`prefixIcon` on a field's `InputDecoration`) and `LabelWithHelp` (a label row with the "?" next to it, for a group of fields that isn't a single `TextField`) each open a dialog with a plain-language explanation and an optional concrete example, for form fields whose naming is confusing (e.g. "Preço" being a per-unit price, not the total).

**Coverage so far is Compras only** (`TutorialScreens.listas` / `.listaDetalhe` / `.catalogo` in `ListasScreen`, `ListaDetalheScreen`, `CatalogoScreen`; help icons on the Preço, Unidade/Quantidade, and Marca fields in `produto_item_sheet.dart`) — it is the newest and most complex module. Other screens (Dashboard, Investimentos, Ajustes, gestão de contas/categorias/usuários, Família) have no tutorial yet; extend by adding a `TutorialScreens` id, its steps in `tutorial_content.dart`, any new `GlobalKey`s in `tutorial_keys.dart`, and a `TutorialButton` in that screen's `AppBar.actions`, following the Compras screens as the reference implementation.

`currentTabProvider` (drives `MainScreen`'s bottom-nav index) lives in [lib/providers/navigation_provider.dart](lib/providers/navigation_provider.dart) — split out from `tutorial_provider.dart` when the tutorial system was rebuilt, since it has nothing to do with tutorials.

### Navigation

No named-route-per-screen setup beyond a handful of routes registered in `main.dart` (`/manage_categories`, `/manage_accounts`, `/manage_users`, `/history`). Primary navigation is a bottom `NavigationBar` in [lib/screens/main_screen.dart](lib/screens/main_screen.dart) that swaps `_pages[currentIndex]` directly (no `IndexedStack`, so inactive tabs lose their scroll/local state) across Dashboard, **Compras** (→ `ListasScreen`, see above), Investimentos, and Ajustes; other screens are pushed with `Navigator.push(MaterialPageRoute(...))`.

### In-app update mechanism (Windows)

[lib/services/update_service.dart](lib/services/update_service.dart) polls `UPDATE_CHECK_URL` (→ `latest.json` in this repo, served raw from GitHub) on launch, compares versions via [lib/utils/version_helper.dart](lib/utils/version_helper.dart) against `appVersion` in `app_version.dart`, and if newer, downloads and silently runs the Inno Setup installer with `/CLOSEAPPLICATIONS /RESTARTAPPLICATIONS`, then `exit(0)`s so Inno Setup can take over. This is Windows-only (`installUpdate` throws `UnsupportedError` elsewhere).

## Manual SQL migrations

Everything in [scripts/](scripts/) is applied by hand in the Supabase SQL Editor — there's no tracking of what's already been run beyond the Dart code's own defensive try/catch fallbacks, so **when in doubt, ask the user whether a given script has been applied** rather than assuming.

**Schema (apply to any new/other Supabase project this app points at, roughly in this order):**
| Script | Adds |
|---|---|
| `add_shopping_lists_catalog.sql` | `listas_compras`, `categorias_produtos`, `produtos_catalogo`; `lista_id`/`produto_id`/`unidade` on `lista_compras`; seeds categories + starter products |
| `add_sem_categoria.sql` | the `"Sem categoria"` fallback row in `categorias_produtos` |
| `add_marca_e_mercado.sql` | `produtos_catalogo.marca` (legacy free-text, superseded — see `produto_marcas` above) and `listas_compras.mercado` |
| `add_listas_compras_transacao_id.sql` | `listas_compras.transacao_id` (concluded-list ↔ transação link) |
| `add_produto_marcas.sql` | `produto_marcas` table + `lista_compras.marca_id` — the real brand-variant system |
| `add_metas_financeiras.sql` | `metas` (financial goals) table |
| `supabase_security_fixes.sql`, `fix_usuarios_family_isolation.sql` | RLS/grant setup for family sharing RPCs |

**One-off data repair (already applied to prod once, incident-specific — not needed on a fresh environment, kept only for reference):** `diagnose_orphaned_antonio.sql`, `restore_antonio.sql`, `restore_vinicius_and_sweep.sql`, `delete_duplicate_antonio.sql`, `inspect_duplicate_antonio_data.sql`, `merge_duplicate_antonio.sql`.
