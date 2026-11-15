# WinCore 4.0.0 — compatibility feature register

WinCore 4.0.0 adds a diagnostic Compatibility Center. The features below are implemented as inspection, record-keeping, backup, and recommendation tools. They do not patch game binaries, install graphics drivers, or guarantee that a game will launch.

## Compatibility Center capabilities (1–50)

1. Windows executable selection through Android's document picker.
2. Persistent read permission for the selected executable where the provider supports it.
3. Executable filename and metadata display.
4. DOS MZ header validation.
5. PE signature validation.
6. PE machine/architecture identification.
7. PE optional-header inspection.
8. PE section-table inspection.
9. PE import-table inspection.
10. Imported library name reporting.
11. Bounded executable reading to limit memory use.
12. DirectX-related import and indicator inspection.
13. Game-folder selection through Android's document picker.
14. Persistent game-folder permission where supported.
15. Bounded folder-tree scanning.
16. GTA IV / DirectX 9 diagnostic checklist.
17. Per-game diagnostic profile form.
18. Per-game launch-argument storage.
19. Per-game environment-variable notes.
20. Per-game audio and controller notes.
21. Advisory Box64 preset selection.
22. Advisory graphics-wrapper selection.
23. User-entered compatibility rating.
24. Per-game diagnostic profile persistence.
25. Profile version snapshots.
26. Profile version comparison.
27. Previous-profile rollback.
28. JSON profile export.
29. JSON profile import.
30. WinCore preference backup export.
31. Preference backup restore.
32. Profile conflict inspection.
33. Device and launch-readiness checks.
34. Available-memory reporting.
35. Battery-temperature reporting when Android exposes it.
36. Thermal-status reporting when Android exposes it.
37. Vulkan feature inspection.
38. OpenGL ES feature inspection.
39. WinCore/Winlator diagnostic log capture.
40. Log filtering for relevant diagnostic lines.
41. Redaction of selected sensitive log patterns before report sharing.
42. Compatibility report generation.
43. Compatibility report export through Android's document picker.
44. Compatibility report sharing through Android's share sheet.
45. Session history display.
46. Session elapsed-time recording.
47. Android app-process CPU-time recording.
48. Android app-process PSS memory recording.
49. Available system RAM snapshot at session end.
50. Built-in troubleshooting guidance.

### Important limitations

- PE import inspection is static analysis, not a complete reverse-engineering or runtime compatibility test.
- A detected DirectX indicator does not prove that a particular DirectX feature path will work.
- Box64 and graphics-wrapper choices are advisory in the Compatibility Center. The screen does not silently override the existing Winlator runtime configuration.
- Session CPU/PSS/RAM values describe the Android app process and system state, not isolated game-engine metrics.
- GTA IV checks are diagnostic only. No GTA IV launch, gameplay, or FPS result is claimed.
- The CI build validates compilation and selected integration markers. Physical-device and game-runtime testing remain outstanding.

---

# WinCore — retained 100-feature implementation register

This register counts capabilities that are implemented in WinCore 3.0.0 or already provided by the pinned Winlator base. It does not imply that 100 brand-new engine changes were written in this release. Items marked **WinCore 3.0.0** are new in this release; **WinCore 2.0.0** are retained; **Winlator base** are upstream features preserved by WinCore.

## Device and CPU profiles (1–20)

1. Automatic chipset-family detection — WinCore 2.0.0 / 3.0.0.
2. Manual Automatic profile selection — WinCore 2.0.0.
3. Manual Dimensity profile — WinCore 2.0.0.
4. Manual Snapdragon profile — WinCore 2.0.0.
5. Manual Exynos profile — WinCore 2.0.0.
6. Per-family Box64 preset mapping — WinCore 3.0.0.
7. Custom Box64 preset mapping per family — WinCore 3.0.0.
8. Per-container device-family override — WinCore 3.0.0.
9. Per-game shortcut device-family override — WinCore 3.0.0.
10. Shortcut-over-container-over-global precedence — WinCore 3.0.0.
11. Automatic profile resolution at guest launch — WinCore 2.0.0 / 3.0.0.
12. Unknown-family fallback to saved container preset — WinCore 2.0.0 / 3.0.0.
13. Automatic fallback for unavailable preset IDs — WinCore 3.0.0.
14. Existing Box64 Stability preset — Winlator base.
15. Existing Box64 Conservative preset — Winlator base.
16. Existing Box64 Intermediate preset — Winlator base.
17. Existing Box64 Performance preset — Winlator base.
18. Custom Box64 preset creation and editing — Winlator base.
19. Box64 preset duplication and removal — Winlator base.
20. Per-container Box64 preset — Winlator base.

## CPU and hardware information (21–30)

21. Android SoC model reporting — WinCore 0.3.0.
22. Android hardware and board identifier inspection — WinCore 3.0.0.
23. CPU core count reporting — WinCore 0.2.0.
24. Supported ABI reporting — WinCore 0.2.0.
25. App process bitness reporting — WinCore 0.4.0.
26. Android version and API reporting — WinCore 0.2.0.
27. System RAM total and availability reporting — WinCore 0.2.0.
28. App memory-class reporting — WinCore 0.4.0.
29. Large app memory-class reporting — WinCore 0.4.0.
30. CPU affinity selection for 64-bit and WoW64 processes — Winlator base.

## Graphics and game-specific configuration (31–50)

31. Vulkan renderer selection — Winlator base.
32. OpenGL renderer selection — Winlator base.
33. Default graphics driver selection — Winlator base.
34. Vortek graphics configuration — Winlator base.
35. VirGL graphics configuration — Winlator base.
36. DXVK configuration — Winlator base.
37. WineD3D configuration — Winlator base.
38. VKD3D configuration — Winlator base.
39. Per-game graphics renderer override — Winlator base.
40. Per-game graphics configuration override — Winlator base.
41. Per-game DirectX wrapper override — Winlator base.
42. Per-game DirectX wrapper configuration — Winlator base.
43. Per-game screen resolution override — Winlator base.
44. Per-game audio driver override — Winlator base.
45. Per-game audio driver configuration — Winlator base.
46. Per-game Windows component override — Winlator base.
47. Per-game environment variable override — Winlator base.
48. Per-game forced fullscreen setting — Winlator base.
49. Per-game startup workaround selection — Winlator base.
50. Per-game Box64 preset override — Winlator base.

## Game shortcuts and controls (51–60)

51. Per-game input controls profile — Winlator base.
52. Per-game DirectInput mapper selection — Winlator base.
53. Per-game executable arguments — Winlator base.
54. Shortcut naming and rename — Winlator base.
55. Shortcut settings persistence — Winlator base.
56. Shortcut icon loading — Winlator base.
57. Per-container controller profile management — Winlator base.
58. Gamepad model selection — Winlator base.
59. Multi-player gamepad mapping — Winlator base.
60. Shortcut-level CPU device profile override — WinCore 3.0.0.

## Memory, adaptive launch, and live monitoring (61–75)

61. Android low-memory state detection — WinCore 3.0.0.
62. Adaptive launch Stability fallback under low-memory state — WinCore 3.0.0.
63. Android thermal status detection — WinCore 3.0.0.
64. Adaptive launch Stability fallback at severe thermal status — WinCore 3.0.0.
65. Optional live session monitor — WinCore 3.0.0.
66. App process CPU-time utilization estimate — WinCore 3.0.0.
67. App process PSS memory display — WinCore 3.0.0.
68. Available system RAM display — WinCore 3.0.0.
69. Battery temperature display — WinCore 3.0.0.
70. Android thermal status display — WinCore 3.0.0.
71. Explicit GPU utilization unavailable status — WinCore 3.0.0.
72. Existing frame-rate HUD modes — Winlator base.
73. Existing GPU information HUD mode — Winlator base.
74. Per-container HUD selection — Winlator base.
75. Optional monitor can be enabled or disabled — WinCore 3.0.0.

## Diagnostics and compatibility (76–90)

76. Vulkan API feature reporting — WinCore 0.3.0.
77. Vulkan hardware level reporting — WinCore 0.3.0.
78. OpenGL ES reporting — WinCore 0.2.0.
79. Internal app storage reporting — WinCore 0.5.0.
80. External app storage reporting — WinCore 0.5.0.
81. RootFS validity check — WinCore 0.6.0.
82. Container directory/config check — WinCore 0.6.0.
83. Wine prefix and Windows folder check — WinCore 0.6.0.
84. Selected Wine binary check — WinCore 0.6.0.
85. Selected Box64 preset validation — WinCore 0.6.0.
86. Graphics renderer identifier validation — WinCore 0.6.0.
87. DirectX wrapper identifier validation — WinCore 0.6.0.
88. Display resolution format validation — WinCore 0.7.0.
89. Environment variable name and duplicate validation — WinCore 0.7.0.
90. Drive letter/path syntax validation — WinCore 0.7.0.

## Storage and reports (91–95)

91. Mapped drive host path existence check — WinCore 0.8.0.
92. Mapped drive host path readability check — WinCore 0.8.0.
93. Aggregate container audit summary — WinCore 0.9.0.
94. Per-container malformed-data error isolation — WinCore 1.0.0.
95. Copy/share compatibility report — WinCore 0.4.0 onward.

## UI, profile management, and usability (96–100)

96. App-wide accent color customization — WinCore 2.0.0.
97. Compact, Standard, and Large interface text sizing — WinCore 2.0.0.
98. Appearance reset — WinCore 3.0.0.
99. Shareable JSON device profile export — WinCore 3.0.0.
100. Original Winlator navigation, container, shortcut, and controller workflows preserved — WinCore.

## Verification scope

The CI build checks source patch application, selected feature markers, APK compilation, package ID/version, APK archive integrity, and ARM64 library presence. It does not run games, benchmark performance, validate a GPU driver on physical hardware, or prove GTA IV compatibility. The live monitor is an Android app-process/system monitor, not a game-engine profiler.
