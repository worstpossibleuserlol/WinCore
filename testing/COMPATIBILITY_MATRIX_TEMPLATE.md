# Compatibility matrix template

Copy this page for a test session. Leave unknown values blank and use Not tested when no test was performed.

## Test environment

| Field | Value |
|---|---|
| Test date | |
| WinCore version / commit | |
| APK source (Actions run or release URL) | |
| Device model | |
| SoC / GPU as reported by Android | |
| Android version / build | |
| Available RAM at test start | |
| Controller (if used) | |

## Container configuration

| Field | Value |
|---|---|
| Container label (non-sensitive) | |
| Wine version | |
| Box64 preset | |
| Device profile source (global/container/shortcut) | |
| Renderer / graphics driver | |
| DirectX wrapper and version | |
| Resolution | |
| Audio driver | |

## Application or game

| Field | Value |
|---|---|
| App/game title and version | |
| Installer/source type | |
| Startup arguments (omit private tokens) | |
| Test scenario | |
| Time spent in test | |

## Result

| Check | Result (Pass / Fail / Not tested) | Evidence or notes |
|---|---|---|
| APK installs | Not tested | |
| WinCore opens | Not tested | |
| Container audit | Not tested | |
| Guest process starts | Not tested | |
| Main menu / app screen reached | Not tested | |
| Input works | Not tested | |
| Audio works | Not tested | |
| Graphics render correctly | Not tested | |
| Stable during scenario | Not tested | |
| Exit is clean | Not tested | |

## Notes

Describe reproducible steps, visual/audio issues, crashes, and relevant logs. Do not report a frame rate unless it was measured with a stated method. Do not compare different devices as if test conditions were identical.
