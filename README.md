# WinCore

WinCore is an independent community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

## Version 0.4.0 — diagnostics refresh and sharing

This release keeps the original Winlator interface and extends WinCore's compatibility report workflow.

- Keeps the Winlator containers, shortcuts, settings, and controller UI.
- Uses the separate Android application ID `com.wincore`.
- Adds **Refresh** to update live RAM readings and regenerate the device report.
- Adds **Share Report** using Android's native share sheet. The user chooses whether to share the text and which app receives it.
- Retains **Copy Report**.
- Adds app-process bitness and Android app memory-class information.
- Retains device, Android, SoC/hardware, CPU-core, ABI, RAM, OpenGL ES, and Android-advertised Vulkan details.
- Sets Android versionName to **0.4.0** and versionCode to **400**.

Reports are generated locally. WinCore does not upload them. Sharing is user-initiated through Android's share menu. Memory-class values are Android limits/allowances for the app process, not a measurement of free physical RAM or a guarantee of game performance. Vulkan values are Android-advertised features, not a runtime graphics test.

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

GitHub Actions builds and validates the debug APK, then uploads it as the **WinCore-0.4.0-debug** artifact.

## Upstream and licensing

WinCore uses the Winlator source as a Git submodule pinned to a specific upstream commit. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream [Winlator repository](https://github.com/brunodev85/winlator) for source and license information. Notices and licenses for third-party components remain applicable.

WinCore is an independent community project. It is not an official Winlator release and is not affiliated with or endorsed by the Winlator maintainers.
