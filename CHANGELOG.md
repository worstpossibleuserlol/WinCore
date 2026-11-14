# Changelog

## 0.2.0 — Device diagnostics prototype

- Added a device-diagnostics panel to the existing Winlator Settings screen.
- Added a local compatibility report with device model, Android release/API, SoC or hardware identifier, CPU core count, supported ABIs, total/available RAM, and OpenGL ES version.
- Added a user-triggered Copy Report action.
- Kept diagnostics local; no report is sent over the network.
- Made the source patch script safe to run repeatedly.
- Updated Android versionName to 0.2.0 and versionCode to 200.
- Improved CI checks to validate the package ID, version, APK integrity, and arm64-v8a output.

### Not included

- No changes to Wine, Box64, Mesa, DXVK, VKD3D, or native execution logic.
- No FPS benchmark, automatic tuning, performance uplift, or game compatibility guarantees.

## 0.1.0 — Foundation prototype

- Added the pinned Winlator upstream source as a recursive Git submodule.
- Preserved the existing Winlator UI and application workflow.
- Added WinCore app branding and a separate Android application ID.
- Set Android versionName to 0.1.0 and versionCode to 1.
- Added a source patch script and an Android debug-build workflow.
