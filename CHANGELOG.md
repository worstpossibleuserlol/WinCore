# Changelog

## 0.9.0 — Container audit summary

- Added an aggregate summary to the Check Containers report.
- Reports the number of containers checked, clean containers, containers needing review, and total findings.
- Retains all 0.8.0 mapped-drive availability checks and earlier diagnostics.
- The summary is calculated from existing read-only audit results; no container settings or files are changed.
- Updated Android versionName to 0.9.0 and versionCode to 900.
- Updated CI to verify the summary implementation and build the 0.9.0 ARM64 debug APK.

### Scope and limitations

- Summary counts structural findings only; it does not establish whether a Windows game launches or performs well.
- No automatic repairs, performance tuning, or compatibility guarantees are included.


## 0.8.0 — Mapped drive availability checks

- Extended the read-only container audit to check whether each mapped host path exists and is readable at audit time.
- Reports drive letters and path status without exposing full host storage paths.
- Distinguishes directory and file mappings.
- Retains saved display resolution, environment-variable, drive syntax, RootFS, container folder/config, Wine prefix, selected Wine binary, Box64 preset, graphics renderer, and DirectX wrapper checks.
- Does not grant permissions, mount drives, alter settings, or modify files.
- Updated Android versionName to 0.8.0 and versionCode to 800.
- Updated CI to verify mapped-drive availability reporting and build the 0.8.0 ARM64 debug APK.

### Scope and limitations

- Path readability is a point-in-time filesystem check, not a guarantee that Wine can use the path.
- Android scoped-storage rules and removable-storage availability may affect later access.
- No performance or game-compatibility claims are made.

## 0.7.0 — Extended container validation

- Added display-resolution format validation to the read-only container audit.
- Added environment-variable validation for malformed entries and duplicate variable names.
- Added drive-mapping validation for drive letters, duplicate letters, and absolute host paths.
- Retained RootFS, container folder/config, Wine prefix, Windows system folder, selected Wine binary, Box64 preset, graphics renderer, and DirectX wrapper checks.
- Added the new findings to the report used by Copy Report and Share Report.
- Kept validation read-only; it does not alter container settings or files.
- Updated Android versionName to 0.7.0 and versionCode to 700.
- Updated CI to verify the additional validation checks and build the 0.7.0 ARM64 debug APK.

### Scope and limitations

- The audit validates saved formats and file presence only. It does not prove that a game launches or runs.
- Absolute drive paths may still be inaccessible due to Android storage permissions or unavailable storage.
- No automatic correction, installation, cleanup, deletion, FPS benchmark, or performance claims.

## 0.6.0 — Container compatibility checks

- Added a **Check Containers** action to the existing Settings diagnostics panel.
- Audits the RootFS marker and each saved container's folder, config file, Wine prefix, and Windows system folder.
- Checks for the selected Wine binary and selected Box64 preset.
- Validates that saved Vulkan/OpenGL renderer and DirectX wrapper selections use recognized identifiers.
- Adds per-container findings to the compatibility report, which remains local unless the user chooses Copy or Share.
- Keeps the audit read-only; it does not alter container files, environment variables, drivers, or settings.
- Updated Android versionName to 0.6.0 and versionCode to 600.

## 0.5.0 — Storage diagnostics

- Added total and available internal app-storage readings to the compatibility report.
- Added external app-specific storage readings when that storage location is available.
- Storage readings update with the existing Refresh button.
- Included storage capacity in the existing copy and share report actions.
- Kept storage checks read-only and permission-free; unavailable locations are reported as unavailable.
- Updated Android versionName to 0.5.0 and versionCode to 500.

## 0.4.0 — Diagnostics refresh and sharing

- Added a Refresh button to regenerate the device report and update live memory readings.
- Added a Share Report button using Android's native share sheet.
- Kept sharing user-initiated; WinCore does not automatically upload reports.
- Added app-process 32-bit/64-bit status and Android app memory-class values.

## 0.3.0 — Graphics capability diagnostics

- Extended the Settings compatibility report with Android-advertised Vulkan API version.
- Added Vulkan hardware feature-level reporting.
- Distinguished advertised system features from an actual runtime graphics test.

## 0.2.0 — Device diagnostics prototype

- Added the device-diagnostics panel to the existing Winlator Settings screen.
- Added device model, Android release/API, SoC/hardware, CPU cores, supported ABIs, RAM, and OpenGL ES to a local report.
- Added a user-triggered Copy Report action.

## 0.1.0 — Foundation prototype

- Added the pinned Winlator upstream source as a recursive Git submodule.
- Preserved the existing Winlator UI and application workflow.
- Added WinCore app branding and a separate Android application ID.
- Set Android versionName to 0.1.0 and versionCode to 1.
- Added a source patch script and Android debug-build workflow.
