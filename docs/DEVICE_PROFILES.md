# Device profiles

WinCore device profiles select a Box64 preset for a guest-program launch. They are configuration helpers, not CPU overclocking or GPU-driver controls.

## Profile precedence

A profile can be selected globally, overridden by a container, and overridden again by an individual game shortcut. The most specific setting wins:

1. Game shortcut
2. Container
3. Global setting

A shortcut or container can inherit the next level instead of forcing a family.

## Available choices

- **Automatic:** inspect Android SoC, board, hardware, bootloader, and product identifiers for a recognizable chipset family.
- **Dimensity:** manually select the MediaTek family mapping.
- **Snapdragon:** manually select the Qualcomm family mapping.
- **Exynos:** manually select the Samsung family mapping.

Detection can return Unknown when Android does not expose recognizable identifiers. In that case, WinCore falls back to the saved container preset rather than pretending it identified the chipset.

## Box64 preset mapping

Each family can be mapped to an installed Box64 preset, including a custom preset. A mapping is only a starting configuration. The most stable or fastest option depends on the game, Wine version, graphics translation layer, driver, and device.

For fair comparisons, keep the same container and game version, change one setting at a time, record the selected preset, and repeat after a fresh launch.

## Adaptive launch safety

When enabled, adaptive launch safety can choose the Stability preset when Android reports a low-memory condition or severe thermal status. This is evaluated when a guest program is launched. It does not change a game that is already running, cool the device, or guarantee that a crash will be prevented.

## What profiles do not do

- They do not change physical CPU frequency, voltage, or core count.
- They do not install or replace GPU drivers.
- They do not guarantee a frame rate.
- They do not prove that a Windows game is compatible.
- They do not automatically make a demanding game such as GTA IV run.

For measured results, use a repeatable test procedure and report the device, Android version, container settings, and game build.
