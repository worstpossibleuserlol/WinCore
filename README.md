# WinCore

WinCore is an independent community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

## Version 0.5.0 — storage diagnostics

This release keeps the original Winlator interface and extends the local compatibility report with app-storage capacity.

- Keeps the Winlator containers, shortcuts, settings, and controller UI.
- Uses the separate Android application ID `com.wincore`.
- Adds internal app-storage total and available space.
- Adds external app-specific storage total and available space when Android provides that location.
- Updates storage readings when **Refresh** is pressed.
- Includes storage readings in **Copy Report** and **Share Report**.
- Keeps all diagnostics local until the user explicitly copies or shares the report.
- Sets Android versionName to **0.5.0** and versionCode to **500**.

Storage values describe the app's internal and app-specific external storage locations. They are not a complete measurement of every shared-storage volume or SD card, and free space alone does not guarantee that a game will install or run. Vulkan values remain Android-advertised features rather than a runtime graphics test.

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

GitHub Actions builds and validates the debug APK, then uploads it as the **WinCore-0.5.0-debug** artifact.

## Upstream and licensing

WinCore uses the Winlator source as a Git submodule pinned to a specific upstream commit. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream [Winlator repository](https://github.com/brunodev85/winlator) for source and license information. Notices and licenses for third-party components remain applicable.

WinCore is an independent community project. It is not an official Winlator release and is not affiliated with or endorsed by the Winlator maintainers.
