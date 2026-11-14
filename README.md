# WinCore

WinCore is an independent community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

## Version 2.0.0 — automatic device profiles and customizable UI

WinCore 2.0.0 adds automatic launch-time device profiles and app-wide appearance controls while preserving the existing Winlator screens, containers, shortcuts, and controller flow.

- **Automatic CPU compatibility profile:** detects common MediaTek Dimensity, Qualcomm Snapdragon, and Samsung Exynos SoC identifiers from Android build properties.
- **Manual family selection:** choose Automatic, Dimensity, Snapdragon, or Exynos in the existing Settings screen.
- **Automatic launch application:** each guest-program launch resolves the selected profile and supplies the corresponding existing Box64 preset without requiring a separate apply action.
- **Safe unknown-device fallback:** when the SoC family cannot be identified, WinCore retains the preset saved in the selected container.
- **Profile mapping:** Dimensity uses the Intermediate Box64 preset, Snapdragon uses Performance, and Exynos uses Stability. These are starting mappings, not benchmark-verified device optimizations.
- **App-wide accent color:** choose from eight accent colors; the preference is applied to controls across WinCore screens.
- **Interface text density:** choose Compact, Standard, or Large text sizing.
- **Live UI propagation:** appearance settings are applied when the activity resumes and whenever a fragment view is created.
- **No hardware modification:** profiles only choose Box64 environment presets. They do not change CPU frequency, core count, voltage, or GPU driver binaries.
- Retains previous read-only device/storage diagnostics and per-container compatibility auditing.
- Sets Android versionName to **2.0.0** and versionCode **20000**.

The earlier 100-item feature proposal is a roadmap, not a claim that 100 separate engine capabilities have been delivered in this release. WinCore 2.0.0 implements the core automatic-profile and UI-customization functionality; unimplemented items remain future work.

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

GitHub Actions builds and validates the debug APK, then uploads it as the **WinCore-2.0.0-debug** artifact.

## Upstream and licensing

WinCore uses the Winlator source as a Git submodule pinned to a specific upstream commit. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream [Winlator repository](https://github.com/brunodev85/winlator) for source and license information. Notices and licenses for third-party components remain applicable.

WinCore is an independent community project. It is not an official Winlator release and is not affiliated with or endorsed by the Winlator maintainers.
