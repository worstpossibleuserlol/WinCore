# Installing and building WinCore

WinCore is an independent community modification of Winlator. The root repository contains the WinCore patch and metadata; upstream Winlator is included as a pinned Git submodule.

## Get the source

~~~bash
git clone --recurse-submodules https://github.com/worstpossibleuserlol/WinCore.git
cd WinCore
~~~

For an existing clone, initialize the pinned source with:

~~~bash
git submodule update --init --recursive
~~~

## Build a debug APK

The documented build environment is JDK 17, Android SDK Platform 35, Build Tools 35.0.0, NDK 24.0.8215888, and CMake 3.22.1.

~~~bash
bash scripts/apply-wincore-patch.sh
cd upstream/app
bash gradlew --no-daemon assembleDebug
~~~

The APK is written to upstream/app/app/build/outputs/apk/debug/app-debug.apk.

GitHub Actions also builds a debug APK workflow artifact. An Actions artifact is not the same thing as a signed, published GitHub Release APK.

## Before installing

1. Keep a backup of important container data.
2. Confirm that the APK came from the intended WinCore repository workflow.
3. Check the Android package identity and installation prompt.
4. Install only on a device you control.
5. Start with a disposable test container before relying on an existing setup.

## Build troubleshooting

- **Winlator source was not found:** clone recursively or run the submodule update command above.
- **Patch anchor mismatch:** do not force the patch. Inspect the failure and upstream diff first.
- **SDK or NDK missing:** install the exact versions listed above.
- **Gradle/JDK errors:** confirm that Gradle is using JDK 17.
- **APK builds but a game fails:** compilation and packaging do not prove game compatibility.
