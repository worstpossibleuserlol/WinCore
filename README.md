# WinCore

WinCore is an independent community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

## Version 3.0.0 — release

WinCore 3.0.0 expands automatic device profiles into a layered system that can be configured globally, per container, and per game shortcut. It adds user-configurable Box64 mappings, optional launch safety, an optional live session monitor, and profile sharing.

### Device profiles

- Automatic detection uses Android SoC, board, hardware, bootloader, and product identifiers. Manufacturer alone is not treated as sufficient evidence.
- Global profile choices: Automatic, Dimensity, Snapdragon, and Exynos.
- Per-container and per-shortcut overrides: Inherit global, Automatic detection, Dimensity, Snapdragon, and Exynos.
- Precedence is per-game shortcut, then container, then global profile.
- Each family can map to any installed Box64 preset, including custom presets.
- Unknown chipsets fall back to the saved container preset.
- Adaptive launch safety, when enabled, chooses the Stability preset for Android low-memory conditions or severe thermal status. It is evaluated at program launch; it does not dynamically rewrite a running game's environment.

### Session monitoring

- Optional in-game overlay reports app CPU time usage, app PSS memory, available system RAM, battery temperature, and Android thermal status.
- The monitor is opt-in and stops updating when its view is detached.
- GPU utilization is displayed as unavailable because a portable public Android API does not expose it consistently.

### Profile and UI customization

- Share a JSON profile containing family-to-Box64 mappings, selected global family, adaptive-launch setting, monitor setting, and appearance preferences.
- Existing accent colors and Compact / Standard / Large interface text sizing remain.
- Reset appearance returns the accent color and text sizing to defaults.
- Existing Winlator settings, containers, shortcuts, CPU affinity, renderers, controllers, and per-game overrides remain in place.

### Compatibility limits

The 100-item [feature register](FEATURES.md) includes new WinCore features and existing Winlator capabilities preserved by this fork; it is not a claim of 100 new engine changes in 3.0.0. The family-to-Box64 mapping is user-configurable and does not claim benchmark-proven optimization. Device family detection may return Unknown on devices that do not expose recognizable Android build identifiers. Adaptive launch checks only Android's system low-memory and thermal status. The optional monitor reports metrics exposed by Android; it does not invent GPU utilization or per-game FPS. Existing container audits validate saved configuration and file presence, not whether a game launches correctly.

## Build

```bash
git clone --recurse-submodules https://github.com/worstpossibleuserlol/WinCore.git
cd WinCore
bash scripts/apply-wincore-patch.sh
cd upstream/app
bash gradlew assembleDebug
```

The Android build requires JDK 17, Android SDK Platform 35, NDK 24.0.8215888, and CMake 3.22.1. The debug APK is written to `upstream/app/app/build/outputs/apk/debug/app-debug.apk`.

GitHub Actions builds and validates the debug APK and uploads it as the **WinCore-3.0.0-release-debug** artifact.

## Upstream and licensing

WinCore uses the Winlator source as a Git submodule pinned to a specific upstream commit. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream [Winlator repository](https://github.com/brunodev85/winlator) for source and license information. WinCore is an independent community project, not an official Winlator release.
