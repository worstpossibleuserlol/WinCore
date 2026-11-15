# Changelog

## 6.0.0 — Automation, Stability, and About-screen cleanup

- Added 50 Automation & Stability Compatibility Center actions: automatic per-game profile workflows, game-file metadata, multiple executable discovery, saved presets, profile history/rollback, renderer and resolution profile notes, graphics capability checks, DXVK/VKD3D variable review, fullscreen checks, RAM/thermal samples, battery baselines, resource readiness estimates, stability and startup history, low-storage checks, log categorization, diagnostic exports, selected-folder filename comparison, recovery profiles, report comparison, categories, covers, favorites, recent profile activity, import/export validation, and a compact dashboard option.
- Added game categories, user-selected cover images, favorites, and recent saved-profile activity using local app preferences.
- Added renderer and resolution profile fields to per-game profile JSON.
- Added pre-change profile snapshots and a conservative recovery profile flow; these save WinCore profile recommendations and do not directly rewrite the active Winlator container.
- Changed Compatibility Center EditText inputs to white entered text with light-gray hint text for readability in the dark UI.
- Removed the old Winlator website row from the About dialog.
- Replaced only the About dialog's top-right image with a dedicated green-on-charcoal WinCore About drawable; left the launcher icon resources untouched.
- Updated Android versionName to 6.0.0 and versionCode to 60000.

### Verification limits

- File version detection displays document name, size, and modified time; it does not decode embedded PE product-version resources.
- Renderer/resolution/graphics environment configuration and recovery settings remain stored advisory profiles, not automatic active-container changes.
- RAM and thermal histories are recorded on user request. Battery impact is a coarse percentage/temperature comparison, not power measurement.
- Startup history measures Compatibility Center UI initialization, not Windows game startup. Storage checks cover the app storage volume only.
- Selected-folder integrity comparison fingerprints scanned filenames only; it does not hash file contents or inspect protected container storage.
- Diagnostic exports are JSON/text; no complete RootFS, container, Wine-prefix, or game-data archive is made.
- No physical-device or game-runtime compatibility test is implied by CI.

## 5.0.0 — Compatibility Suite and supplied WinCore branding

- Added 50 numbered Compatibility Center actions spanning executable/game detection, profile matching, Wine/Box64 and graphics advice, RAM/CPU/thermal snapshots, GTA IV diagnostics, Android controller/audio output inspection, log filtering, missing-DLL pattern detection, folder checks, profile history, backup guidance, and compatibility summaries.
- Added advisory profile matching, Wine/Box64 recommendations, resolution guidance, custom log phrase rules, and a local compatibility database.
- Added GTA IV profile setup and checks for executable, component and save-data filename clues. These inspect files and logs only; they do not launch GTA IV or guarantee compatibility.
- Added per-game controller/audio-device and launch-readiness diagnostics using Android-exposed information.
- Installed the exact supplied green four-panel image as the app icon and logo across all five mipmap density folders, adaptive icon resources, app logo resources, and upstream logo files.
- Added CI checks for all 50 Compatibility Center entries and byte-for-byte identity of every installed icon/logo with the canonical asset.
- Set Android versionName to 5.0.0 and versionCode to 50000.

### Verification limits

- This release adds compatibility inspection and advisory tools; it does not change the underlying Wine/Box64/graphics engine or silently apply profile recommendations.
- Frame-pacing/FPS measurement is not available from this integration. CPU timing is for the WinCore Android app process, not isolated game CPU utilization.
- Android device/audio/controller and folder-presence checks do not prove that a Windows game uses those devices or that its files are valid.
- Preferences backup and migration guidance do not copy RootFS, complete containers, Wine prefixes, or game data.
- Physical-device testing and game-runtime testing are not claimed by CI.

## 4.0.0 — Compatibility Center (retained)

- Added a Compatibility Center for executable inspection, per-game diagnostic profiles, GTA IV checks, profile history, import/export, preference backup/restore, conflict checks, launch-readiness checks, and compatibility reports.
- Added advisory Box64 and graphics-wrapper recommendations without silently changing Winlator runtime settings.
- Added session history using Android app-process CPU time, process PSS, elapsed time, and available RAM.
- Replaced launcher artwork and WinCore logo assets with the supplied green-and-white image across Android density resources.
- Preserved existing Winlator container, shortcut, controller, and graphics workflows.
- Set Android versionName to 4.0.0 and versionCode to 40000.

### Verification limits

- Executable inspection and GTA IV checks are diagnostic only; no game launch or FPS guarantee is made.
- Session metrics are Android app-process/system measurements, not isolated game-engine telemetry.
- The CI artifact remains a debug build even though its filename omits the debug suffix.

## 3.0.0 — release

- Added per-container and per-game CPU device profile override controls.
- Added profile precedence: shortcut, container, global.
- Added configurable Box64 preset mappings for Dimensity, Snapdragon, and Exynos.
- Added safer SoC-family detection using Android hardware/board/product identifiers.
- Added adaptive launch safety for Android low-memory and severe thermal conditions.
- Added optional live session overlay for app CPU time, app PSS, available system RAM, battery temperature, and thermal status.
- Added JSON profile sharing.
- Added appearance reset.
- Retained global automatic/manual profile selection, accent color, text sizing, container audit, and diagnostics.
- Set Android versionName to 3.0.0 and versionCode to 30000.

## 2.0.0

- Added automatic chipset-family detection and launch-time Box64 preset selection.
- Added manual Automatic, Dimensity, Snapdragon, and Exynos choices.
- Added app-wide accent color and interface text density customization.

## 1.0.0

- Isolated each container audit with its own error boundary.
- Added aggregate container audit summary and retained earlier diagnostics.

## 0.9.0

- Added aggregate container audit summary.

## 0.8.0

- Added mapped host path existence and readability checks.

## 0.7.0

- Added display resolution, environment-variable name, and drive mapping validation.

## 0.6.0

- Added read-only RootFS, container, Wine prefix, Wine binary, Box64 preset, renderer, and DirectX wrapper checks.
