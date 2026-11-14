# Changelog

## 0.4.0 — Diagnostics refresh and sharing

- Added a Refresh button to regenerate the device report and update live memory readings.
- Added a Share Report button using Android's native share sheet.
- Kept sharing user-initiated; WinCore does not automatically upload reports.
- Added app-process 32-bit/64-bit status.
- Added Android app memory-class and large-memory-class values.
- Updated Android versionName to 0.4.0 and versionCode to 400.
- Updated CI to verify the new diagnostics controls and build the 0.4.0 ARM64 debug APK.

### Not included

- No changes to Wine, Box64, Mesa, DXVK, VKD3D, or native execution logic.
- No FPS benchmark, runtime Vulkan probe, automatic tuning, performance uplift, or game compatibility guarantees.

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
