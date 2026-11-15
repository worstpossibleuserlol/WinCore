# WinCore 7.0.0 — 50-feature implementation register

This register tracks the 50 features proposed for WinCore 7.0.0. A feature is marked **implemented in source** only when code is added and the build workflow checks it. A successful build does not replace physical-device testing.

## Implemented in the 7.0.0 source patch

1. Selected-container configuration loading — implemented in source; only the selected container's JSON is parsed when opening its detail screen.
2. Background container operation executor — implemented in source; create, duplicate, and remove share a managed executor.
3. Main-thread completion callbacks — implemented in source for container create, duplicate, and remove.
4. Per-container malformed-config isolation — implemented in source; an unreadable config no longer aborts scanning all containers.
5. Invalid container-ID handling — implemented in source; non-numeric and non-positive IDs are skipped.
6. Exact user-supplied navigation drawer logo — implemented in source; copied to the upstream `drawable/logo.png` resource and checked byte-for-byte by CI.
7. Logo aspect fitting — implemented in source; the drawer image uses fit-center scaling.
8. Build-time drawer branding verification — implemented in CI.
9. Container patch-anchor verification — implemented in CI.
10. APK compilation and archive-integrity verification — implemented in CI.

## Remaining proposed features — not yet implemented

11. Container metadata cache.
12. Smart cache invalidation.
13. Lazy tab initialization.
14. Lazy Wine registry access.
15. Asynchronous Wine registry processing.
16. Container-opening progress indicator.
17. Atomic configuration saving.
18. Container search.
19. Custom container sorting.
20. Favorite containers.
21. Recently opened containers.
22. Per-container storage dashboard.
23. Complete container backup.
24. Verified container restoration.
25. Configuration snapshots.
26. Duplicate progress tracking.
27. Bulk backup management.
28. Pre-launch readiness inspection.
29. Missing runtime detector.
30. Wine prefix health check.
31. Per-session log collection.
32. Crash report analyzer.
33. Safe launch mode.
34. Custom executable arguments UI.
35. Configuration comparison UI.
36. Shader cache manager.
37. Local game compatibility catalogue.
38. Controller-first navigation.
39. Quick container actions.
40. Game library search.
41. Game categories.
42. Custom game artwork.
43. Recently played game screen.
44. Improved contextual error messages.
45. Accessibility and focus-navigation audit.
46. Tablet-specific layout.
47. Advanced settings search.
48. Automatic configuration backups.
49. Configuration rollback UI.
50. Container migration assistant.

## Verification still required

- Test opening small and large containers on physical Android devices.
- Test multiple containers where one config is malformed.
- Test create, duplicate, and remove operations repeatedly.
- Verify container settings remain editable and save correctly.
- Verify the drawer logo visually on phone and tablet layouts.
- Confirm no unwanted Winlator logos remain in other screens.
