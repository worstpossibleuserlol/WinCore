# Troubleshooting

This guide covers common WinCore setup and compatibility problems. It does not assume every Windows game can run on every Android device.

## The app does not build

- Clone with recursive submodules.
- Check that the pinned upstream submodule is initialized.
- Use JDK 17 and the SDK/NDK versions listed in INSTALLATION.md.
- Read the first Gradle or patch error, not only the final build-failed line.
- Do not bypass a patch-anchor mismatch; inspect the upstream source before changing patch logic.

## A container does not start

- Run the WinCore container audit.
- Check the RootFS and Wine-prefix findings.
- Confirm that the selected Wine binary and Box64 preset are present.
- Verify the container renderer and DirectX-wrapper selections.
- Test with a backed-up container before rebuilding or changing its files.

## A game opens and then closes

Record the exact stage where it exits: before the launcher, during loading, at the menu, or after entering gameplay. Check available logs and the compatibility report. A successful Android APK build does not validate guest runtime behavior.

## Black screen or rendering errors

Record the renderer, graphics driver, DirectX translation layer, resolution, and whether the problem occurs in more than one game. Change one graphics setting at a time and keep a known-good configuration to restore.

## Poor performance or overheating

Close unrelated workloads, allow the device to return to a normal temperature, and compare one change at a time. Do not interpret a device-family preset as a benchmark result. Stop testing if Android reports severe thermal status or the device becomes unusually hot.

## Reports and logs

A useful report includes the WinCore version, installation source, device model, Android version, chipset as reported by Android, container and game configuration, renderer, DirectX wrapper, reproduction steps, observed result, and relevant error excerpts.

Review logs before sharing. Remove personal paths, usernames, tokens, credentials, and unrelated private information.
