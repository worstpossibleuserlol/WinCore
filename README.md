# WinCore

WinCore is an independent community modification of [Winlator](https://github.com/brunodev85/winlator), an Android compatibility environment for running Windows applications and games with Wine and Box86/Box64.

WinCore adds configurable device profiles, per-container and per-game settings, launch safety options, session monitoring, profile sharing, and a Compatibility Center for executable inspection, game profiles, diagnostics, and backups while preserving the core Winlator workflow.

**Current version: 4.0.0**

## Installation

1. Open the [WinCore GitHub repository](https://github.com/worstpossibleuserlol/WinCore).
2. Open **Actions** and select the successful build workflow for the version you want.
3. Download the available APK artifact from the workflow run. The current 4.0.0 CI artifact is named `WinCore-4.0.0`.
4. Extract the downloaded ZIP file and locate the APK.
5. Install the APK on your Android device. Android may ask you to allow installation from the app or browser you used to download it.
6. Open WinCore and create or select a container.

The CI artifact is a **debug build**, not a production-signed release. The APK filename intentionally omits a `-debug` suffix, but that does not change its build type or signing status. Only install builds from a source you trust.

## Useful Tips

- Start with Automatic device detection if you are unsure which device profile to use.
- Change one graphics, driver, or Box64 setting at a time so you can identify which change affects compatibility.
- Use the per-container or per-game profile options when a setting helps one game but causes problems in another.
- Back up important containers and game data before making major changes.
- Keep enough free storage for the game, container files, shader caches, and temporary data.
- Close demanding background apps if Android is reporting low memory.
- Monitor temperature during long sessions and allow the device to cool if it becomes unusually hot.
- Record the settings that work for each game; different games can need different configurations.
- Not every Windows game is compatible with every Android device. Performance depends on the device, drivers, game, and configuration.

## Troubleshooting

### The APK will not install
- Make sure the ZIP artifact has been extracted and that you are opening the APK, not the ZIP file.
- Check that the APK download completed successfully.
- Android may require permission for the browser or file manager to install apps.
- If Android reports a package or signature conflict, check whether another build of the same app is already installed. Back up anything important before changing installations.

### WinCore opens but a game does not launch
- Confirm that the container is configured and that the game files are present.
- Check the selected Wine version, graphics settings, Box64 preset, and device profile.
- Restore the last known working settings if the issue began after a configuration change.
- Check the available logs and diagnostic information before changing several settings at once.

### A game crashes or performs poorly
- Test a conservative/stability-oriented configuration first.
- Reduce demanding in-game graphics options where available.
- Check Android memory and thermal conditions.
- Try a different supported graphics or Box64 configuration only when you can compare the result against the previous settings.

### A device profile is detected as Unknown
- Some Android devices do not expose chipset identifiers in a format that can be recognized reliably.
- Use the manual profile or saved container preset instead of assuming the automatic result is correct.

### The session monitor does not show GPU usage or FPS
- The monitor reports metrics exposed by Android, such as app CPU time, memory, battery temperature, and thermal status.
- GPU utilization and per-game FPS are not reported when the required reliable system data is unavailable.

If the problem continues, open an issue in the repository and include your Android device model, WinCore version, container configuration, the steps to reproduce the problem, and relevant logs. Remove personal information from logs before sharing them.

## Credits

- **Winlator project and upstream contributors** — WinCore is based on the open-source [Winlator project](https://github.com/brunodev85/winlator).
- **WinCore contributors** — for the community modifications, integration, documentation, testing, and maintenance.
- **Open-source libraries and tools** — see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and the upstream project for applicable licenses and notices.

WinCore is an independent community project. It is not affiliated with, endorsed by, or an official release of the Winlator project.

## Build

To build from source:

```bash
git clone --recurse-submodules https://github.com/worstpossibleuserlol/WinCore.git
cd WinCore
bash scripts/apply-wincore-patch.sh
cd upstream/app
bash gradlew assembleDebug
```

The Android build requires JDK 17, Android SDK Platform 35, NDK 24.0.8215888, and CMake 3.22.1. The debug APK is written to `upstream/app/app/build/outputs/apk/debug/app-debug.apk`.

GitHub Actions builds and validates the debug APK and uploads it as the **WinCore-4.0.0** artifact.

## More Information

- [Feature register](FEATURES.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [WinCore repository](https://github.com/worstpossibleuserlol/WinCore)
- [Upstream Winlator repository](https://github.com/brunodev85/winlator)
