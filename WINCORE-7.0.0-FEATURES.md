# WinCore 7.0.0 — 50-feature implementation register

This is the 50-feature list proposed for WinCore 7.0.0. Status is explicit: a feature is not marked complete merely because it appears in a roadmap or Compatibility Center label.

## Status by original feature number

1. Instant container selection — **partially implemented**: opening an existing container now loads only that container's configuration, but directory enumeration is still synchronous.
2. Background container loading — **not implemented**.
3. Container metadata cache — **not implemented**.
4. Smart cache invalidation — **not implemented**.
5. Lazy tab loading — **not implemented**.
6. Lazy registry access — **implemented in source**: registry reads use the original file; a temporary copy is created only when a write is requested.
7. Asynchronous registry processing — **not implemented**.
8. Loading progress indicator — **not implemented**.
9. Corrupted-container isolation — **implemented in source**: one unreadable config is skipped without aborting the remaining scan.
10. Atomic configuration saving — **not implemented**.
11. Container search — **not implemented**.
12. Custom sorting — **not implemented**.
13. Favorite containers — **not implemented**.
14. Recently opened containers — **not implemented**.
15. Storage usage dashboard — **not implemented**.
16. Complete container backup — **not implemented**.
17. Verified container restoration — **not implemented**.
18. Configuration snapshots — **not implemented**.
19. Duplicate progress tracking — **not implemented**.
20. Bulk backup management — **not implemented**.
21. Pre-launch inspection — **not implemented**.
22. Missing runtime detector — **not implemented**.
23. Wine prefix health check — **not implemented**.
24. Per-session log collection — **not implemented**.
25. Crash report analyzer — **not implemented**.
26. Safe launch mode — **not implemented**.
27. Custom executable arguments — **not implemented as a new 7.0.0 feature**.
28. Configuration comparison — **not implemented as a new 7.0.0 feature**.
29. Shader cache manager — **not implemented**.
30. Game compatibility catalogue — **not implemented**.
31. Controller-first navigation — **not implemented**.
32. Quick container actions — **not implemented**.
33. Game library search — **not implemented**.
34. Game categories — **not implemented as a new 7.0.0 feature**.
35. Custom game artwork — **not implemented as a new 7.0.0 feature**.
36. Recently played games screen — **not implemented as a new 7.0.0 feature**.
37. Improved contextual error messages — **partially implemented** for container config read failures; other errors still need work.
38. Accessibility improvements — **not implemented**.
39. Tablet layout — **not implemented**.
40. Advanced settings search — **not implemented**.
41. Automatic configuration backups — **not implemented**.
42. Configuration rollback — **not implemented**.
43. Container migration assistant — **not implemented**.
44. Storage cleanup assistant — **not implemented**.
45. Container permission repair — **not implemented**.
46. Upstream compatibility checker — **not implemented**.
47. Automated container tests — **not implemented as runtime tests**.
48. Automated UI tests — **not implemented**.
49. APK regression testing — **partially implemented** through CI source assertions, compilation, package metadata, and archive checks.
50. Build diagnostics report — **partially implemented** through GitHub Actions build logs; no in-app report exporter is added here.

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
