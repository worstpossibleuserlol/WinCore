# WinCore 7.0.0 — 50-feature implementation register

This is the 50-feature list proposed for WinCore 7.0.0. Status is explicit: a feature is not marked complete merely because it appears in a roadmap or Compatibility Center label.

## Status by original feature number

1. Instant container selection — **partially implemented**: the workspace can select and search containers, and the main detail screen loads only its selected config; directory enumeration still occurs synchronously in the legacy manager.
2. Background container loading — **implemented in source**: workspace container scans and metadata parsing run on a single background executor.
3. Container metadata cache — **implemented in source**: container JSON metadata is cached using config modification time and file size.
4. Smart cache invalidation — **implemented in source**: the workspace invalidates only metadata-cache keys and preserves favorites, recents, and other user preferences.
5. Lazy tab loading — **implemented in source**: the 7.0 workspace creates each feature group's controls only when that group is expanded.
6. Lazy registry access — **implemented in source**: registry reads use the original file; a temporary copy is created only when a write is requested.
7. Asynchronous registry processing — **implemented in source**: registry file discovery and read checks run on the background executor.
8. Loading progress indicator — **implemented in source**: asynchronous scans, storage measurement, backups, restore and duplicate operations report progress.
9. Corrupted-container isolation — **implemented in source**: one unreadable config is skipped without aborting the remaining scan.
10. Atomic configuration saving — **implemented in source**: standard container saves and workspace-managed writes use Android AtomicFile.
11. Container search — **implemented in source**: container names/IDs and workspace feature names can be searched.
12. Custom sorting — **implemented in source**: container records can be ordered by name, measured storage usage, or recent-use order.
13. Favorite containers — **implemented in source**: favorite IDs are stored separately and can be toggled for the selected container.
14. Recently opened containers — **implemented in source**: the workspace stores and displays a bounded recent-container history.
15. Storage usage dashboard — **implemented in source**: container folders are measured in the background and individual/aggregate sizes are reported.
16. Complete container backup — **implemented in source**: ZIP backups include hidden files and a separate manifest for symbolic links.
17. Verified container restoration — **implemented in source**: archives are extracted to staging, bounded by size/entry limits, path-checked, config-validated and only then swapped into place.
18. Configuration snapshots — **implemented in source**: timestamped .container configuration snapshots are stored per container.
19. Duplicate progress tracking — **implemented in source**: duplicate work runs off the UI thread and displays an active progress state.
20. Bulk backup management — **implemented in source**: one ZIP can contain multiple selected container folders and their symbolic-link metadata.
21. Pre-launch inspection — **implemented in source**: checks the container config, RootFS marker, Wine prefix, system32 folder and selected runtime identifiers.
22. Missing runtime detector — **implemented in source**: reports the presence of expected Wine and Box64 runtime paths.
23. Wine prefix health check — **implemented in source**: inspects key prefix directories, registry files and dosdevices.
24. Per-session log collection — **implemented in source**: captures available Android app/Wine/WinCore logcat lines, subject to Android log access limits.
25. Crash report analyzer — **partially implemented**: identifies common crash/failure patterns from collected logs; it does not provide a full root-cause diagnosis.
26. Safe launch mode — **implemented in source**: saves the Stability Box64 preset and can restore the previous saved preset.
27. Custom executable arguments — **implemented in source**: the workspace can edit the shortcut's existing execArgs metadata.
28. Configuration comparison — **implemented in source**: compares current top-level config values with the latest snapshot.
29. Shader cache manager — **implemented in source**: reports known per-container cache sizes and offers a scoped cache cleanup.
30. Game compatibility catalogue — **partially implemented**: provides diagnostic starting guidance for common game/API groups; it is not a verified compatibility database.
31. Controller-first navigation — **partially implemented**: workspace controls are focusable and controller/keyboard input devices are listed; device-specific navigation still needs physical testing.
32. Quick container actions — **implemented in source**: opens the quick-action sheet for the selected container.
33. Game library search — **implemented in source**: selected-container desktop shortcuts can be searched and inspected.
34. Game categories — **implemented in source**: category metadata can be saved to each shortcut.
35. Custom game artwork — **implemented in source**: image-picker imports are stored as per-game shortcut icons.
36. Recently played games screen — **implemented in source**: shortcut launches are recorded and shown in the recent-games view.
37. Improved contextual error messages — **implemented in source**: feature failures include their operation context and underlying exception message.
38. Accessibility improvements — **implemented in source**: larger text mode, labeled controls, focusable buttons and status announcements are provided in the workspace.
39. Tablet layout — **implemented in source**: wide layouts use a centered maximum-width content column.
40. Advanced settings search — **partially implemented**: feature/command search is provided; it does not yet index every setting on every legacy screen.
41. Automatic configuration backups — **partially implemented**: workspace snapshots can be made on open and before workspace-managed changes; not every upstream setting write is snapshotted.
42. Configuration rollback — **implemented in source**: restores a selected container's previous .container snapshot after creating a before-rollback snapshot.
43. Container migration assistant — **partially implemented**: normalizes missing metadata fields with a pre-migration snapshot; broader historical schema migrations still require test fixtures.
44. Storage cleanup assistant — **implemented in source**: estimates and can clear only the selected container's .cache folder.
45. Container permission repair — **partially implemented**: attempts to restore app-private read/write access; Android filesystem behavior needs device testing.
46. Upstream compatibility checker — **partially implemented**: verifies local RootFS/runtime paths against the pinned source baseline; it does not compare live upstream releases.
47. Automated container tests — **partially implemented**: runs local RootFS, directory, config-JSON and atomic-write smoke checks; full container lifecycle instrumentation remains outstanding.
48. Automated UI tests — **partially implemented**: performs an in-app view-tree accessibility/focus audit; it is not a full Espresso/device interaction suite.
49. APK regression testing — **implemented in CI**: compiles the APK and validates package/version metadata, ZIP integrity and ARM64 library presence.
50. Build diagnostics report — **implemented in source and CI**: exports app/device/container diagnostics, while GitHub Actions retains the build log and APK verification results.

## Additional 7.0.0 bug fixes outside the 50-feature list

- Container create, duplicate, and remove now share a single background executor instead of creating an unclosed executor for every operation.
- Completion callbacks for these operations are posted to the main thread and are run after operation failures as well.

## Branding correction

The exact user-supplied `assets/branding/wincorebanner.png` file is installed as the navigation drawer's `drawable/logo.png`, not as the launcher icon. CI compares the copied image byte-for-byte with the supplied file. The launcher artwork comes only from `assets/branding/old-launcher-icon.png`.

## Verification still required

- Build success does not prove container-opening speed on the user's phone.
- Test opening small and large containers and verify settings can still be edited and saved.
- Test multiple containers with one malformed config.
- Test create, duplicate, and remove operations repeatedly.
- Visually inspect the drawer on device and search other screens for remaining Winlator branding.
