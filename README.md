# WinCore

WinCore is an independent community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

## Version 1.0.0 — first stable release

WinCore 1.0.0 consolidates the existing diagnostics and hardens container auditing so a single malformed saved container does not prevent the remaining containers from being checked.

- Isolates each container audit with its own error boundary and reports a review finding if that entry cannot be checked safely.
- Handles an unavailable RootFS object without crashing the audit.
- Retains the 0.9.0 aggregate audit summary and all earlier device, storage, graphics-capability, configuration, and mapped-drive checks.
- Keeps the audit read-only. It does not repair, rewrite, delete, or change containers, settings, environment variables, or drive mappings.
- Sets Android versionName to **1.0.0** and versionCode to **10000**.

The stable milestone does not claim that a container can launch a particular game, that a renderer initializes, or that performance is improved. A successful APK build confirms compilation and package integrity, not on-device game compatibility.

## Previous version: 0.9.0 — container audit summary

- Added a summary of containers checked, containers with no structural findings, containers needing review, and total findings.
- Retained the read-only per-container report and mapped-drive availability checks.

## Previous version: 0.8.0 — mapped drive availability checks



This release extends the read-only container audit to check whether each saved mapped host path currently exists and is readable.

- Keeps the Winlator containers, shortcuts, settings, and controller UI.
- Uses the separate Android application ID `com.wincore`.
- Adds display-resolution format validation.
- Checks environment-variable entry names, malformed entries, and duplicate names without applying or changing any values.
- Checks drive mapping syntax, duplicate drive letters, absolute host paths, and whether each mapped host path currently exists and is readable. The report shows only drive letters and status, not full host paths.
- Retains the 0.6.0 RootFS, container folder/config, Wine prefix, selected Wine binary, Box64 preset, graphics renderer, and DirectX wrapper checks.
- Adds the new findings to the local compatibility report, available through the existing Copy Report and Share Report actions.
- Keeps all checks read-only. No container files, environment variables, drive mappings, or settings are changed.
- Sets Android versionName to **0.8.0** and versionCode to **800**.

These checks validate saved settings and basic file structure only. They do not launch a game, execute a renderer test, benchmark performance, or guarantee compatibility. A readable path check is only a point-in-time filesystem check; Android storage permissions, removable storage state, and later changes can still affect access.

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

GitHub Actions builds and validates the debug APK, then uploads it as the **WinCore-1.0.0-debug** artifact.

## Upstream and licensing

WinCore uses the Winlator source as a Git submodule pinned to a specific upstream commit. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream [Winlator repository](https://github.com/brunodev85/winlator) for source and license information. Notices and licenses for third-party components remain applicable.

WinCore is an independent community project. It is not an official Winlator release and is not affiliated with or endorsed by the Winlator maintainers.
