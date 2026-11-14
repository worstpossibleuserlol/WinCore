# WinCore

WinCore is a community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

## Version 0.1.0 — Foundation prototype

This first prototype establishes a buildable WinCore identity while keeping the original Winlator interface and container workflow.

- Keeps the Winlator containers, shortcuts, settings, and controller UI.
- Uses a separate Android application ID: `com.wincore`.
- Displays the app name as **WinCore**.
- Sets the prototype version to **0.1.0**.
- Includes a GitHub Actions workflow that builds a debug APK from the pinned upstream source.

**Important:** version 0.1.0 does not claim faster emulation or broader game compatibility. The Wine, Box64, graphics, and native runtime components remain upstream components in this foundation prototype. Performance changes will be added and tested in later versions.

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

GitHub Actions also builds the APK and uploads it as the `WinCore-0.1.0-debug` artifact when the workflow succeeds.

## Upstream and licensing

WinCore uses the Winlator source as a Git submodule pinned to a specific upstream commit. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream [Winlator repository](https://github.com/brunodev85/winlator) for source and license information. Notices and licenses for third-party components remain applicable.

WinCore is an independent community project. It is not an official Winlator release and is not affiliated with or endorsed by the Winlator maintainers.
