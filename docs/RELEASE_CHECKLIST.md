# Release checklist

Use this checklist before publishing a WinCore build. A checked item should have a verifiable result.

## Source and version

- [ ] Confirm the intended commit is on the intended branch.
- [ ] Confirm the upstream Winlator submodule commit is intentional and notices are preserved.
- [ ] Update VERSION, CHANGELOG.md, and Android workflow version values together.
- [ ] Run bash scripts/validate-repository.sh from a recursive clone.
- [ ] Review the full patch diff for upstream anchor changes and accidental edits.

## Build and package

- [ ] Confirm the Android workflow completed successfully.
- [ ] Confirm the artifact is the expected debug or signed release type.
- [ ] Verify package ID is com.wincore.
- [ ] Verify Android versionName and versionCode match the release version.
- [ ] Check APK archive integrity and expected ARM64 native libraries.
- [ ] Record the workflow run URL and artifact name.

## Runtime validation

- [ ] Install the exact artifact on a physical Android device.
- [ ] Open WinCore and inspect existing containers and shortcuts.
- [ ] Run the read-only container audit.
- [ ] Test device-profile precedence and guest launch.
- [ ] Test the optional monitor and profile export if changed.
- [ ] Execute relevant cases in the compatibility test plan.
- [ ] Record device, Android, container, renderer, and application versions.

## Publishing notes

- [ ] Distinguish CI compilation from physical-device runtime testing.
- [ ] Do not claim a game works or runs faster without reproducible device evidence.
- [ ] State known limitations and untested areas.
- [ ] Preserve upstream and third-party license notices.
- [ ] Do not describe WinCore as an official Winlator release.

A workflow artifact named with debug should be described as a debug APK artifact, not as a production-signed release.
