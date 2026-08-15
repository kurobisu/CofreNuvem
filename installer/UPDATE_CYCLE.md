# CofreNuvem Windows Update Cycle

## Endpoint (GitHub)
Add `UPDATE_CHECK_URL` to `.env`:

```ini
UPDATE_CHECK_URL=https://raw.githubusercontent.com/kurobisu/CofreNuvem/main/latest.json
```

The file `latest.json` is kept in the repository root and updated automatically by GitHub Actions.

## Flow
1. On startup the app calls `UpdateService().checkForUpdate()`.
2. If `version` is newer than `lib/utils/app_version.dart`, a dialog is shown.
3. User taps **Atualizar agora** → installer is downloaded to `%TEMP%`.
4. `UpdateService().installUpdate()` runs the installer with:
   ```
   /SILENT /SP- /SUPPRESSMSGBOXES /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /NOCANCEL
   ```
5. Inno Setup closes the running app, installs the new version, and restarts it.

## Publishing a new release

1. Update `lib/utils/app_version.dart`:
   ```dart
   const String appVersion = 'v.0.0.31';
   ```
2. Commit and push.
3. Create and push a tag:
   ```bash
   git tag v0.0.31
   git push origin v0.0.31
   ```
4. GitHub Actions will:
   - Build the Flutter Windows release
   - Create the installer with Inno Setup
   - Create a GitHub Release and attach the `.exe`
   - Update `latest.json` in the `main` branch

## Build installer locally
```powershell
.\installer\build_installer.ps1
```

Output: `build\windows\x64\installer\CofreNuvem-Setup-<version>.exe`

## Validate update cycle
1. Install an older build with the installer.
2. Push a new tag or manually edit `latest.json` with a higher version.
3. Launch the app and confirm the update dialog appears.
4. Accept the update; verify the app closes, installs, and restarts on the new version.

## Required GitHub Secrets
Go to **Settings → Secrets and variables → Actions** and add:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

These are written to `.env` during the CI build so the app can connect to Supabase.

## Tests
Run unit tests:

```bash
flutter test test/version_helper_test.dart
```
