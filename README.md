# WinCore

WinCore is an independent community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

## Version 0.3.0 — graphics capability diagnostics

This release keeps the original Winlator interface and container workflow while extending the WinCore compatibility report.

- Keeps the Winlator containers, shortcuts, settings, and controller UI.
- Uses the separate Android application ID `com.wincore`.
- Adds local Vulkan capability information to the Settings diagnostics panel.
- Reports Android-advertised Vulkan API version and Vulkan hardware feature level when present.
- Retains the device, Android, SoC/hardware, CPU-core, ABI, RAM, and OpenGL ES information from 0.2.0.
- Keeps the **Copy Report** action local; WinCore does not upload the report.
- Sets Android versionName to **0.3.0** and versionCode to **300**.

The Vulkan values come from Android's advertised system feature declarations. They are useful compatibility clues, not a Vulkan runtime test, GPU benchmark, proof of driver quality, or guarantee that a Windows game will run. The actual graphics driver and Winlator translation path still need application-level testing. No performance uplift or game compatibility guarantee is claimed.

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

GitHub Actions builds and validates the debug APK, then uploads it as the **WinCore-0.3.0-debug** artifact.

## Upstream and licensing

WinCore uses the Winlator source as a Git submodule pinned to a specific upstream commit. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream [Winlator repository](https://github.com/brunodev85/winlator) for source and license information. Notices and licenses for third-party components remain applicable.

WinCore is an independent community project. It is not an official Winlator release and is not affiliated with or endorsed by the Winlator maintainers.
