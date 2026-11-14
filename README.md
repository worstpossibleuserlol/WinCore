# WinCore

WinCore is an independent community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

## Version 0.6.0 — container compatibility checks

This release adds a read-only audit for saved containers while keeping the original Winlator interface and launch workflow.

- Keeps the Winlator containers, shortcuts, settings, and controller UI.
- Uses the separate Android application ID `com.wincore`.
- Adds **Check Containers** to the existing Settings diagnostics panel.
- Checks the RootFS marker, saved container folder/configuration, Wine prefix and Windows system folder.
- Checks whether each selected Wine binary and Box64 preset can be found.
- Checks whether saved Vulkan/OpenGL renderer and DirectX wrapper selections are recognized.
- Adds findings to the local report, which can then be copied or explicitly shared using Android's share menu.
- Keeps the audit read-only: it does not modify containers, install components, delete files, or change settings.
- Sets Android versionName to **0.6.0** and versionCode to **600**.

The audit validates saved configuration and the presence of selected files only. A renderer name being recognized does not prove that its native driver loads, and a structurally valid container does not guarantee that a particular game will launch or run well. Vulkan capability values remain Android-advertised feature data, not a runtime graphics test.

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

GitHub Actions builds and validates the debug APK, then uploads it as the **WinCore-0.6.0-debug** artifact.

## Upstream and licensing

WinCore uses the Winlator source as a Git submodule pinned to a specific upstream commit. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream [Winlator repository](https://github.com/brunodev85/winlator) for source and license information. Notices and licenses for third-party components remain applicable.

WinCore is an independent community project. It is not an official Winlator release and is not affiliated with or endorsed by the Winlator maintainers.
