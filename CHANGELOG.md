# Changelog

## 0.3.0 — Graphics capability diagnostics

- Extended the Settings compatibility report with Android-advertised Vulkan API version.
- Added Vulkan hardware feature-level reporting.
- Added explicit labels distinguishing advertised system features from a runtime graphics test.
- Kept the diagnostics report local and user-copied only.
- Updated Android versionName to 0.3.0 and versionCode to 300.
- Updated CI to build and validate the 0.3.0 ARM64 debug APK.

### Not included

- No changes to Wine, Box64, Mesa, DXVK, VKD3D, or native execution logic.
- No Vulkan runtime probe, FPS benchmark, automatic tuning, performance uplift, or game compatibility guarantees.

## 0.2.0 — Device diagnostics prototype

- Added the device-diagnostics panel to the existing Winlator Settings screen.
- Added device model, Android release/API, SoC/hardware, CPU cores, supported ABIs, RAM, and OpenGL ES to a local report.
- Added a user-triggered Copy Report action.
- Kept diagnostics local; no report is sent over the network.

## 0.1.0 — Foundation prototype

- Added the pinned Winlator upstream source as a recursive Git submodule.
- Preserved the existing Winlator UI and application workflow.
- Added WinCore app branding and a separate Android application ID.
- Set Android versionName to 0.1.0 and versionCode to 1.
- Added a source patch script and Android debug-build workflow.
