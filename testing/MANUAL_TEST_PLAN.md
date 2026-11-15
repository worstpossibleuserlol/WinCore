# Manual test plan

**Status:** planned test cases; no result is implied until a tester records evidence.

## A. Installation and app startup

| ID | Test | Expected observation | Result |
|---|---|---|---|
| A-01 | Install the intended debug APK | Android completes installation and WinCore opens | Not tested |
| A-02 | Open Settings | Existing Winlator settings remain accessible | Not tested |
| A-03 | Close and reopen the app | App returns without a startup crash | Not tested |

## B. Diagnostics and container audit

| ID | Test | Expected observation | Result |
|---|---|---|---|
| B-01 | Refresh device diagnostics | Local hardware/software report refreshes | Not tested |
| B-02 | Copy diagnostics | Report is copied when clipboard service is available | Not tested |
| B-03 | Share diagnostics | Android share chooser opens after user action | Not tested |
| B-04 | Audit a valid disposable container | Report shows checks and an aggregate summary | Not tested |
| B-05 | Audit a container with a missing optional path | Finding is reported without modifying container data | Not tested |
| B-06 | Audit several containers, including one malformed configuration | One container error does not prevent others being reported | Not tested |

## C. Device profiles

| ID | Test | Expected observation | Result |
|---|---|---|---|
| C-01 | Select Automatic globally | Detected family or Unknown/fallback is shown | Not tested |
| C-02 | Select a manual family globally | Manual choice is retained | Not tested |
| C-03 | Set a container override | Container setting takes precedence over global | Not tested |
| C-04 | Set a shortcut override | Shortcut setting takes precedence over container | Not tested |
| C-05 | Set an override to inherit | Next less-specific setting is used | Not tested |
| C-06 | Map a family to an installed custom Box64 preset | Selected preset is used at the next guest launch | Not tested |
| C-07 | Enable adaptive launch safety | Low-memory/severe-thermal policy is evaluated at launch | Not tested |

## D. Session monitor and appearance

| ID | Test | Expected observation | Result |
|---|---|---|---|
| D-01 | Enable the optional monitor | Available app/system metrics are shown | Not tested |
| D-02 | Disable the optional monitor | Optional monitor is no longer shown/updated | Not tested |
| D-03 | Change accent and text size | Selected appearance is applied | Not tested |
| D-04 | Reset appearance | Default accent and text size are restored | Not tested |
| D-05 | Export a profile | User-initiated share/export contains a profile document | Not tested |

## E. Guest application and controller behavior

| ID | Test | Expected observation | Result |
|---|---|---|---|
| E-01 | Launch a small known-compatible Windows app | Record whether it reaches its main screen | Not tested |
| E-02 | Exit during guest startup | Record whether the app exits cleanly without corrupting container data | Not tested |
| E-03 | Connect a supported Bluetooth controller | Record whether Android and WinCore detect the controller | Not tested |
| E-04 | Test mapped controls in a supported app | Record working and non-working inputs | Not tested |

## Evidence to attach

For each executed case, record date, WinCore version, device/Android build, container configuration, exact steps, expected result, observed result, and relevant error excerpts. Do not attach credentials or unredacted private files.
