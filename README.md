# WinCore

WinCore is an independent community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

## Version 0.2.0 — diagnostics prototype

This release keeps the original Winlator interface and container workflow while adding a small WinCore-specific compatibility tool.

- Keeps the Winlator containers, shortcuts, settings, and controller UI.
- Uses a separate Android application ID: com.wincore.
- Displays the app name as **WinCore**.
- Adds a local device-diagnostics panel near the top of Settings.
- Reports device model, Android release/API, SoC or hardware identifier, CPU core count, supported ABIs, total/available RAM, and OpenGL ES version.
- Adds a **Copy Report** button. The report is copied only when the user presses the button; WinCore does not upload it.
- Sets the prototype version to **0.2.0**.

The diagnostics screen is for compatibility troubleshooting. It is not a benchmark, does not measure FPS, and does not automatically change game settings. Wine, Box64, graphics drivers, and native runtime components remain upstream components in this release. No performance uplift or game compatibility guarantee is claimed.

## Build

Clone the repository with all submodules:

```bash
git clone --recurse-submodules https://github.com/worstpossibleuserlol/WinCore.git
cd WinCore
bash scripts/apply-wincore-patch.sh
cd upstream/app
bash gradlew assembleDebug
```

The Android build requires JDK 17, Android SDK Platform 35, NDK 24.0.8215888, and CMake 3.22.1. The debug APK is written to:

```
upstream/app/app/build/outputs/apk/debug/app-debug.apk
```

GitHub Actions builds the debug APK and uploads it as the **WinCore-0.2.0-debug** artifact when the workflow succeeds.

## Upstream and licensing

WinCore uses the Winlator source as a Git submodule pinned to a specific upstream commit. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream [Winlator repository](https://github.com/brunodev85/winlator) for source and license information. Notices and licenses for third-party components remain applicable.

WinCore is an independent community project. It is not an official Winlator release and is not affiliated with or endorsed by the Winlator maintainers.
