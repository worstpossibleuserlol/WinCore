# Changelog

## 4.0.0 — Compatibility Center

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
