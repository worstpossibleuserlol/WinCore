# Changelog

## 0.5.0 — Storage diagnostics

- Added total and available internal app-storage readings to the compatibility report.
- Added external app-specific storage readings when that storage location is available.
- Storage readings update with the existing Refresh button.
- Included storage capacity in the existing copy and share report actions.
- Kept storage checks read-only and permission-free; unavailable locations are reported as unavailable.
- Updated Android versionName to 0.5.0 and versionCode to 500.
- Updated CI to verify the new storage fields and build the 0.5.0 ARM64 debug APK.

### Not included

- No changes to Wine, Box64, Mesa, DXVK, VKD3D, or native execution logic.
- No storage cleanup, deletion, automatic file movement, FPS benchmark, automatic tuning, performance uplift, or game compatibility guarantees.

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
