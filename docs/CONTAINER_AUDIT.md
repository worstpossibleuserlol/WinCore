# Container compatibility audit

The WinCore container audit is a read-only inspection of saved container configuration and selected files. It helps identify common setup problems before troubleshooting a game.

## Areas inspected

Depending on the saved container configuration, the report can include:

- RootFS and container directory/configuration presence
- Wine prefix and Windows directory presence
- Selected Wine binary and Box64 preset references
- Recognized renderer and DirectX-wrapper identifiers
- Display-resolution syntax
- Environment-variable entry names and duplicate names
- Drive-letter and mapped-path syntax
- Mapped host-path existence and readability
- Per-container findings and an aggregate summary

## Interpret results carefully

A passing audit means the inspected structure and values passed the checks. It does not mean Wine can start every program, a graphics driver supports every required API, DXVK or VKD3D works correctly, a game will reach its menu, or performance is acceptable.

A host path can also change after the audit. Treat the report as a point-in-time snapshot.

## Safe troubleshooting sequence

1. Read the complete finding and identify the affected container.
2. Confirm that the container is the one used by the game shortcut.
3. Check that the selected Wine binary, Box64 preset, renderer, and wrapper are installed and intended.
4. Confirm that mapped paths still exist and are accessible to the app.
5. Back up container data before making manual changes.
6. Re-run the audit after a correction.

The audit inspects saved data. It is not designed to repair, delete, mount, or rewrite container files automatically.

## Sharing a report

Review a report before posting it publicly. Remove personal information from extra logs or screenshots. Do not post credentials, private files, or unrelated personal data.
