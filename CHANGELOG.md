# Changelog

## 2.0.0

- Added automatic chipset-family detection for common Dimensity, Snapdragon, and Exynos identifiers.
- Added Automatic, Dimensity, Snapdragon, and Exynos profile choices in the existing Winlator Settings screen.
- Applied the selected profile at every guest-program launch through the real Box64 environment setup path.
- Preserved the selected container's saved Box64 preset when device detection returns an unknown family.
- Added app-wide accent color customization with eight selectable colors.
- Added Compact, Standard, and Large interface text sizing.
- Reapplied appearance settings on activity resume and fragment view creation.
- Kept existing Winlator containers, shortcuts, settings, and controller navigation.
- Retained read-only device, storage, graphics capability, and container compatibility diagnostics.
- Set Android versionName to 2.0.0 and versionCode to 20000.
- Documented that the family-to-preset mapping is a baseline and is not benchmark-verified.

## 1.0.0

- Isolated each container audit with its own error boundary so one malformed saved container does not stop the remaining checks.
- Safely handled a missing RootFS object.
- Retained the aggregate container audit summary and earlier diagnostics.
- Kept the audit read-only.

## 0.9.0

- Added aggregate container audit summary counts for checked, clean, review-needed containers, and findings.

## 0.8.0

- Added mapped host path existence and readability checks per saved drive mapping.
- Reported drive letters and statuses without exposing full host paths.

## 0.7.0

- Added display resolution, environment-variable name, and drive mapping validation.

## 0.6.0

- Added read-only structural checks for RootFS, container configuration, Wine prefix, Wine binary, Box64 preset, renderer identifiers, and DirectX wrapper selection.
