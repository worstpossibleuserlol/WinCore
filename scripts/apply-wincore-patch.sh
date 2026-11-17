#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$REPO_ROOT/upstream"
VERSION="$(cat "$REPO_ROOT/VERSION")"
if [[ "$#" -ge 1 && -n "$1" ]]; then UPSTREAM_DIR="$1"; fi
if [[ "$#" -ge 2 && -n "$2" ]]; then VERSION="$2"; fi
APP_REPO="$UPSTREAM_DIR/app"
APP_MODULE="$APP_REPO/app"

if [[ ! -f "$APP_REPO/gradlew" || ! -f "$APP_MODULE/build.gradle" ]]; then
  echo "Winlator source was not found."
  echo "Clone WinCore with recursive submodules enabled."
  exit 1
fi

python3 - "$APP_MODULE" "$VERSION" <<'PY'
from pathlib import Path
import re
import sys
import os

app = Path(sys.argv[1])
version = sys.argv[2]

if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit(f"Invalid semantic version: {version}")

major, minor, patch = (int(part) for part in version.split("."))
computed_version_code = major * 10000 + minor * 100 + patch
override_version_code = os.environ.get("WINCORE_VERSION_CODE", "").strip()
try:
    version_code = int(override_version_code) if override_version_code else computed_version_code
except ValueError:
    raise SystemExit(f"Invalid WINCORE_VERSION_CODE: {override_version_code!r}")
if version_code < computed_version_code:
    raise SystemExit("WINCORE_VERSION_CODE must not be lower than the semantic-version code.")

def replace_regex_once(relative_path: str, pattern: str, replacement: str) -> None:
    path = app / relative_path
    if not path.is_file():
        raise SystemExit(f"Required upstream file is missing: {path}")
    source = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, source, count=1)
    if count != 1:
        raise SystemExit(
            f"Expected exactly one match for {pattern!r} in {path}, found {count}. "
            "Review the upstream change before applying the WinCore patch."
        )
    path.write_text(updated, encoding="utf-8")

def replace_literal_idempotent(relative_path: str, old: str, new: str) -> None:
    path = app / relative_path
    if not path.is_file():
        raise SystemExit(f"Required upstream file is missing: {path}")
    source = path.read_text(encoding="utf-8")
    old_count = source.count(old)
    new_count = source.count(new)
    if old_count == 0 and new_count == 1:
        return
    if old_count != 1 or new_count != 0:
        raise SystemExit(
            f"Expected one old occurrence or one already-patched occurrence in {path}; "
            f"found old={old_count}, new={new_count}."
        )
    path.write_text(source.replace(old, new, 1), encoding="utf-8")

def insert_once(relative_path: str, anchor: str, addition: str, marker: str) -> None:
    path = app / relative_path
    if not path.is_file():
        raise SystemExit(f"Required upstream file is missing: {path}")
    source = path.read_text(encoding="utf-8")
    if marker in source:
        return
    count = source.count(anchor)
    if count != 1:
        raise SystemExit(
            f"Expected one insertion anchor in {path}, found {count}. "
            "Review the upstream change before applying the WinCore patch."
        )
    path.write_text(source.replace(anchor, anchor + addition, 1), encoding="utf-8")

# Preserve the upstream Java namespace while installing a separate WinCore app.
replace_regex_once(
    "build.gradle",
    r"applicationId\s+['\"][^'\"]+['\"]",
    "applicationId 'com.wincore'",
)
replace_regex_once("build.gradle", r"versionCode\s+\d+", f"versionCode {version_code}")
replace_regex_once("build.gradle", r'versionName\s+"[^"]+"', f'versionName "{version}"')

# Resolve FileProvider using the installed package name.
provider_pattern = (
    r'android:authorities="(?:com\.winlator\.FileProvider|'
    + r'\$' + r'\{applicationId\}\.FileProvider)"'
)
replace_regex_once(
    "src/main/AndroidManifest.xml",
    provider_pattern,
    'android:authorities="' + '$' + '{applicationId}.FileProvider"',
)
replace_literal_idempotent(
    "src/main/java/com/winlator/core/FileUtils.java",
    'FileProvider.getUriForFile(activity, "com.winlator.FileProvider", file)',
    'FileProvider.getUriForFile(activity, activity.getPackageName() + ".FileProvider", file)',
)

# Brand all upstream app-name locales without changing upstream Java packages.
resource_root = app / "src/main/res"
updated_locales = 0
for strings_file in resource_root.glob("values*/strings.xml"):
    source = strings_file.read_text(encoding="utf-8")
    branded, count = re.subn(
        r'(<string\s+name="app_name"[^>]*>)(?:Winlator|WinCore)(</string>)',
        r"\1WinCore\2",
        source,
        count=1,
    )
    if count:
        strings_file.write_text(branded, encoding="utf-8")
        updated_locales += 1
if updated_locales == 0:
    raise SystemExit("Could not find an app_name string to brand as WinCore.")

# Add a compact diagnostics panel to the existing Winlator Settings layout.
diagnostics_layout = """            <FrameLayout
                android:layout_width="match_parent"
                android:layout_height="wrap_content">

                <LinearLayout style="@style/FieldSet">
                    <TextView
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:text="@string/wincore_diagnostics_description" />

                    <TextView
                        android:id="@+id/TVWinCoreDiagnostics"
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="8dp"
                        android:fontFamily="monospace"
                        android:textIsSelectable="true"
                        android:textSize="12sp" />

                    <LinearLayout
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="8dp"
                        android:orientation="horizontal">

                        <Button
                            android:id="@+id/BTRefreshWinCoreDiagnostics"
                            android:layout_width="0dp"
                            android:layout_height="wrap_content"
                            android:layout_weight="1"
                            android:text="@string/refresh_diagnostics" />

                        <Button
                            android:id="@+id/BTCopyWinCoreDiagnostics"
                            android:layout_width="0dp"
                            android:layout_height="wrap_content"
                            android:layout_weight="1"
                            android:text="@string/copy_diagnostics" />
                    </LinearLayout>

                    <Button
                        android:id="@+id/BTShareWinCoreDiagnostics"
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="4dp"
                        android:text="@string/share_diagnostics" />

                    <Button
                        android:id="@+id/BTCheckWinCoreContainers"
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="4dp"
                        android:text="@string/wincore_check_containers" />
                </LinearLayout>

                <TextView
                    style="@style/FieldSetLabel"
                    android:text="@string/wincore_device_diagnostics" />
            </FrameLayout>

"""
insert_once(
    "src/main/res/layout/settings_fragment.xml",
    '            android:padding="16dp">\n',
    diagnostics_layout,
    'android:id="@+id/TVWinCoreDiagnostics"',
)

# Add English strings; other locale folders fall back to values/strings.xml.
strings_path = resource_root / "values" / "strings.xml"
strings_source = strings_path.read_text(encoding="utf-8")
new_strings = """    <string name="wincore_device_diagnostics">WinCore Device Diagnostics</string>
    <string name="wincore_diagnostics_description">Refresh local readings or use the Android share menu to share a report.</string>
    <string name="copy_diagnostics">Copy Report</string>
    <string name="refresh_diagnostics">Refresh</string>
    <string name="share_diagnostics">Share Report</string>
    <string name="wincore_diagnostics_copied">Diagnostics copied</string>
    <string name="wincore_diagnostics_unavailable">Clipboard is unavailable</string>
    <string name="wincore_share_report_title">Share WinCore compatibility report</string>
    <string name="wincore_check_containers">Check Containers</string>
"""
if 'name="wincore_device_diagnostics"' not in strings_source:
    anchor = "<resources>\n"
    if strings_source.count(anchor) != 1:
        raise SystemExit(f"Could not find the resources root in {strings_path}.")
    strings_source = strings_source.replace(anchor, anchor + new_strings, 1)
    strings_path.write_text(strings_source, encoding="utf-8")

# Add imports only when missing, keeping the patch repeatable.
java_path = app / "src/main/java/com/winlator/SettingsFragment.java"
java_source = java_path.read_text(encoding="utf-8")
imports = [
    ("import android.app.Activity;\n", "import android.app.ActivityManager;\n"),
    ("import android.content.Context;\n", "import android.content.ClipData;\nimport android.content.ClipboardManager;\n"),
]
for anchor, addition in imports:
    if addition.splitlines()[0] not in java_source:
        if java_source.count(anchor) != 1:
            raise SystemExit(f"Could not safely add a required import to {java_path}.")
        java_source = java_source.replace(anchor, anchor + addition, 1)

diagnostics_binding = "        configureWinCoreDiagnostics(view, context);\n"
binding_anchor = "        preferences = PreferenceManager.getDefaultSharedPreferences(context);\n"
if diagnostics_binding.strip() not in java_source:
    if java_source.count(binding_anchor) != 1:
        raise SystemExit(f"Could not find the Settings initialization anchor in {java_path}.")
    java_source = java_source.replace(binding_anchor, binding_anchor + diagnostics_binding, 1)

diagnostics_methods = """    private void configureWinCoreDiagnostics(View view, Context context) {
        final TextView reportView = view.findViewById(R.id.TVWinCoreDiagnostics);
        if (reportView == null) return;

        reportView.setText(buildWinCoreDiagnostics(context));

        view.findViewById(R.id.BTRefreshWinCoreDiagnostics).setOnClickListener((v) ->
            reportView.setText(buildWinCoreDiagnostics(context)));

        view.findViewById(R.id.BTCopyWinCoreDiagnostics).setOnClickListener((v) -> {
            ClipboardManager clipboard = (ClipboardManager)context.getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard == null) {
                AppUtils.showToast(context, R.string.wincore_diagnostics_unavailable);
                return;
            }
            clipboard.setPrimaryClip(ClipData.newPlainText(
                "WinCore device diagnostics",
                reportView.getText().toString()
            ));
            AppUtils.showToast(context, R.string.wincore_diagnostics_copied);
        });

        view.findViewById(R.id.BTShareWinCoreDiagnostics).setOnClickListener((v) -> {
            Intent shareIntent = new Intent(Intent.ACTION_SEND);
            shareIntent.setType("text/plain");
            shareIntent.putExtra(Intent.EXTRA_SUBJECT, "WinCore compatibility report");
            shareIntent.putExtra(Intent.EXTRA_TEXT, reportView.getText().toString());
            context.startActivity(Intent.createChooser(
                shareIntent,
                context.getString(R.string.wincore_share_report_title)
            ));
        });

        view.findViewById(R.id.BTCheckWinCoreContainers).setOnClickListener((v) -> {
            reportView.setText(
                buildWinCoreDiagnostics(context) + "\\n\\n" +
                buildWinCoreContainerAuditWithSummary(context)
            );
        });
    }

    private String buildWinCoreDiagnostics(Context context) {
        ActivityManager activityManager = (ActivityManager)context.getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
        String openGLES = "Unknown";

        if (activityManager != null) {
            activityManager.getMemoryInfo(memoryInfo);
            android.content.pm.ConfigurationInfo configurationInfo =
                activityManager.getDeviceConfigurationInfo();
            if (configurationInfo != null && configurationInfo.getGlEsVersion() != null) {
                openGLES = configurationInfo.getGlEsVersion();
            }
        }

        String socModel = Build.HARDWARE;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            Build.SOC_MODEL != null && !Build.SOC_MODEL.trim().isEmpty()) {
            socModel = Build.SOC_MODEL;
        }

        StringBuilder supportedAbis = new StringBuilder();
        for (String abi : Build.SUPPORTED_ABIS) {
            if (supportedAbis.length() > 0) supportedAbis.append(", ");
            supportedAbis.append(abi);
        }

        String totalMemory = memoryInfo.totalMem > 0 ?
            formatWinCoreMemory(memoryInfo.totalMem) : "Unknown";
        String availableMemory = memoryInfo.availMem > 0 ?
            formatWinCoreMemory(memoryInfo.availMem) : "Unknown";

        int vulkanApi = findWinCoreFeatureVersion(context,
            android.content.pm.PackageManager.FEATURE_VULKAN_HARDWARE_VERSION);
        int vulkanLevel = findWinCoreFeatureVersion(context,
            android.content.pm.PackageManager.FEATURE_VULKAN_HARDWARE_LEVEL);
        String vulkanSupport = vulkanApi >= 0 ? "Advertised by Android" :
            (vulkanLevel >= 0 ? "Hardware level advertised" : "Not advertised");
        String vulkanVersion = vulkanApi >= 0 ?
            formatWinCoreVulkanVersion(vulkanApi) : "Unknown";
        String vulkanHardwareLevel = vulkanLevel >= 0 ?
            "Level " + vulkanLevel : "Not advertised";

        String processBitness = android.os.Process.is64Bit() ? "64-bit" : "32-bit";
        int memoryClassMb = activityManager != null ? activityManager.getMemoryClass() : 0;
        int largeMemoryClassMb = activityManager != null ? activityManager.getLargeMemoryClass() : 0;

        return "WinCore 0.5.0 compatibility report\\n" +
            "Device: " + Build.MANUFACTURER + " " + Build.MODEL + "\\n" +
            "Android: " + Build.VERSION.RELEASE + " (API " + Build.VERSION.SDK_INT + ")\\n" +
            "SoC / hardware: " + socModel + "\\n" +
            "App process: " + processBitness + "\\n" +
            "CPU cores: " + Runtime.getRuntime().availableProcessors() + "\\n" +
            "Supported ABIs: " + supportedAbis + "\\n" +
            "RAM: " + totalMemory + " total, " + availableMemory + " available\\n" +
            "Internal app storage: " + getWinCoreStorageInfo(context.getFilesDir()) + "\\n" +
            "External app storage: " + getWinCoreStorageInfo(context.getExternalFilesDir(null)) + "\\n" +
            "App memory class: " + memoryClassMb + " MB\\n" +
            "Large app memory class: " + largeMemoryClassMb + " MB\\n" +
            "OpenGL ES: " + openGLES + "\\n" +
            "Vulkan: " + vulkanSupport + "\\n" +
            "Vulkan API: " + vulkanVersion + "\\n" +
            "Vulkan hardware level: " + vulkanHardwareLevel;
    }

    private int findWinCoreFeatureVersion(Context context, String featureName) {
        android.content.pm.FeatureInfo[] features =
            context.getPackageManager().getSystemAvailableFeatures();
        if (features == null) return -1;

        for (android.content.pm.FeatureInfo feature : features) {
            if (featureName.equals(feature.name)) return feature.version;
        }
        return -1;
    }

    private String formatWinCoreVulkanVersion(int version) {
        int major = (version >>> 22) & 0x7F;
        int minor = (version >>> 12) & 0x3FF;
        int patch = version & 0xFFF;
        return String.format(java.util.Locale.US, "%d.%d.%d", major, minor, patch);
    }

    private String getWinCoreStorageInfo(File directory) {
        if (directory == null || !directory.exists()) return "Unavailable";

        try {
            android.os.StatFs storage = new android.os.StatFs(directory.getAbsolutePath());
            long totalBytes = storage.getTotalBytes();
            long availableBytes = storage.getAvailableBytes();
            return formatWinCoreStorageBytes(totalBytes) + " total, " +
                formatWinCoreStorageBytes(availableBytes) + " available";
        }
        catch (IllegalArgumentException | SecurityException exception) {
            return "Unavailable";
        }
    }

    private String formatWinCoreStorageBytes(long bytes) {
        final double kib = 1024.0;
        final double mib = kib * 1024.0;
        final double gib = mib * 1024.0;

        if (bytes >= gib) {
            return String.format(java.util.Locale.US, "%.1f GB", bytes / gib);
        }
        if (bytes >= mib) {
            return String.format(java.util.Locale.US, "%.1f MB", bytes / mib);
        }
        return String.format(java.util.Locale.US, "%.1f KB", bytes / kib);
    }

    private String formatWinCoreMemory(long bytes) {
        return String.format(java.util.Locale.US, "%.1f GB",
            bytes / (1024.0 * 1024.0 * 1024.0));
    }

"""
diagnostics_methods = diagnostics_methods.replace("WinCore 0.5.0 compatibility report", "WinCore " + version + " compatibility report")
if "private void configureWinCoreDiagnostics(" not in java_source:
    anchor = "    private void loadGamepadModelSpinner(Spinner sGamepadModel) {\n"
    if java_source.count(anchor) != 1:
        raise SystemExit(f"Could not find the diagnostics method insertion point in {java_path}.")
    java_source = java_source.replace(anchor, diagnostics_methods + anchor, 1)
container_audit_methods = r"""    private String buildWinCoreContainerAudit(Context context) {
        StringBuilder report = new StringBuilder();
        report.append("Container Compatibility Check\n");
        report.append("This checks saved configuration and required files only; it does not certify game compatibility.\n");

        com.winlator.xenvironment.RootFS rootFS = com.winlator.xenvironment.RootFS.find(context);
        boolean rootFSReady = rootFS != null && rootFS.isValid();
        report.append("RootFS: ").append(rootFSReady ? "Ready" : "Missing or incomplete").append("\n");

        final java.util.ArrayList<com.winlator.container.Container> containers;
        try {
            containers = new com.winlator.container.ContainerManager(context).getContainers();
        }
        catch (RuntimeException exception) {
            report.append("Container scan: Unable to complete safely\n");
            return report.toString();
        }

        report.append("Saved containers: ").append(containers.size()).append("\n");
        if (containers.isEmpty()) {
            report.append("No saved containers were found.\n");
            return report.toString();
        }

        for (com.winlator.container.Container container : containers) {
            try {
            java.util.ArrayList<String> issues = new java.util.ArrayList<>();
            File containerDir = container.getRootDir();
            boolean containerDirectoryReady = containerDir != null && containerDir.isDirectory();
            boolean configReady = containerDirectoryReady &&
                container.getConfigFile().isFile() && container.getConfigFile().length() > 0;
            File winePrefix = containerDirectoryReady ? new File(containerDir, ".wine") : null;
            boolean prefixReady = winePrefix != null && winePrefix.isDirectory();
            boolean windowsDirectoryReady = prefixReady &&
                new File(winePrefix, "drive_c/windows").isDirectory();

            if (!rootFSReady) issues.add("RootFS is missing or incomplete");
            if (!containerDirectoryReady) issues.add("container folder is missing");
            if (!configReady) issues.add("container configuration file is missing or empty");
            if (!prefixReady) issues.add("Wine prefix folder is missing");
            else if (!windowsDirectoryReady) issues.add("Windows system folder is missing");

            String screenSize = container.getScreenSize();
            boolean screenSizeReady = screenSize != null &&
                screenSize.matches("[1-9][0-9]{2,4}x[1-9][0-9]{2,4}");
            if (!screenSizeReady) issues.add("display resolution is malformed");

            String rawEnvVars = container.getEnvVars();
            java.util.ArrayList<String> envTokens = new java.util.ArrayList<>();
            StringBuilder envToken = new StringBuilder();
            boolean envEscape = false;
            if (rawEnvVars != null) {
                for (int charIndex = 0; charIndex < rawEnvVars.length(); charIndex++) {
                    char character = rawEnvVars.charAt(charIndex);
                    if (envEscape) {
                        envToken.append('\\').append(character);
                        envEscape = false;
                    }
                    else if (character == '\\') {
                        envEscape = true;
                    }
                    else if (Character.isWhitespace(character)) {
                        if (envToken.length() > 0) {
                            envTokens.add(envToken.toString());
                            envToken.setLength(0);
                        }
                    }
                    else {
                        envToken.append(character);
                    }
                }
            }
            if (envEscape) envToken.append('\\');
            if (envToken.length() > 0) envTokens.add(envToken.toString());

            java.util.HashSet<String> envNames = new java.util.HashSet<>();
            int validEnvCount = 0;
            boolean envVarsReady = true;
            for (String entry : envTokens) {
                int separator = entry.indexOf('=');
                if (separator <= 0) {
                    envVarsReady = false;
                    continue;
                }
                String variableName = entry.substring(0, separator);
                if (!variableName.matches("[A-Za-z_][A-Za-z0-9_]*")) {
                    envVarsReady = false;
                    continue;
                }
                if (!envNames.add(variableName)) envVarsReady = false;
                validEnvCount++;
            }
            if (!envVarsReady) issues.add("environment variables contain malformed or duplicate entries");

            String rawDrives = container.getDrives();
            java.util.HashSet<String> driveLetters = new java.util.HashSet<>();
            java.util.LinkedHashMap<String, String> driveStatuses = new java.util.LinkedHashMap<>();
            java.util.regex.Matcher driveMatcher = java.util.regex.Pattern
                .compile("([A-Za-z]):(.*?)(?=[A-Za-z]:|$)")
                .matcher(rawDrives != null ? rawDrives.trim() : "");
            int driveCursor = 0;
            boolean drivesReady = rawDrives != null && !rawDrives.trim().isEmpty();
            while (drivesReady && driveMatcher.find()) {
                if (driveMatcher.start() != driveCursor) {
                    drivesReady = false;
                    break;
                }
                String driveLetter = driveMatcher.group(1).toUpperCase(java.util.Locale.US);
                String hostPath = driveMatcher.group(2);
                if (hostPath.isEmpty() || !new File(hostPath).isAbsolute() ||
                    !driveLetters.add(driveLetter)) {
                    drivesReady = false;
                    break;
                }
                File mappedPath = new File(hostPath);
                String pathStatus = !mappedPath.exists() ? "not found" :
                    (!mappedPath.canRead() ? "not readable" :
                    (mappedPath.isDirectory() ? "directory readable" : "file readable"));
                driveStatuses.put(driveLetter, pathStatus);
                if (!mappedPath.exists() || !mappedPath.canRead()) {
                    issues.add("mapped drive " + driveLetter + ": host path is unavailable");
                }
                driveCursor = driveMatcher.end();
            }
            if (driveCursor == 0 || driveCursor != (rawDrives != null ? rawDrives.trim().length() : 0)) {
                drivesReady = false;
            }
            if (!drivesReady) issues.add("drive mappings contain an invalid letter or host path");

            String wineIdentifier = container.getWineVersion();
            File wineBinary;
            if (com.winlator.core.WineInfo.isMainWineVersion(wineIdentifier)) {
                wineBinary = new File(rootFS.getRootDir(), "opt/wine/bin/wine");
            }
            else {
                wineBinary = new File(
                    new File(rootFS.getInstalledWineDir(), wineIdentifier),
                    "bin/wine"
                );
            }
            boolean wineReady = wineBinary.isFile();
            if (!wineReady) issues.add("selected Wine binary was not found");

            String presetId = container.getBox64Preset();
            if (presetId == null || presetId.isEmpty()) presetId = com.winlator.box64.Box64Preset.DEFAULT;
            boolean presetReady;
            try {
                presetReady = com.winlator.box64.Box64PresetManager.getPreset(context, presetId) != null;
            }
            catch (RuntimeException exception) {
                presetReady = false;
            }
            if (!presetReady) issues.add("selected Box64 preset is missing or invalid");

            String rawGraphics = container.getGraphicsDriver();
            String[] graphics = com.winlator.container.GraphicsDrivers.parseIdentifiers(rawGraphics);
            String vulkanId = graphics.length > 0 ? graphics[0] : "";
            String openGLId = graphics.length > 1 ? graphics[1] : "";
            boolean graphicsReady;
            if (rawGraphics == null || rawGraphics.isEmpty()) {
                graphicsReady = true;
            }
            else if (rawGraphics.contains(",")) {
                graphicsReady =
                    com.winlator.container.GraphicsDrivers.isVulkanDriver(vulkanId) &&
                    com.winlator.container.GraphicsDrivers.isOpenGLDriver(openGLId);
            }
            else {
                graphicsReady =
                    com.winlator.container.GraphicsDrivers.isVulkanDriver(rawGraphics) ||
                    com.winlator.container.GraphicsDrivers.isOpenGLDriver(rawGraphics);
            }
            if (!graphicsReady) issues.add("graphics renderer selection is unrecognized");

            String dxWrapper = container.getDXWrapper();
            boolean dxWrapperReady =
                com.winlator.container.DXWrappers.DXVK.equals(dxWrapper) ||
                com.winlator.container.DXWrappers.WINED3D.equals(dxWrapper) ||
                com.winlator.container.DXWrappers.VKD3D.equals(dxWrapper) ||
                com.winlator.container.DXWrappers.CNC_DDRAW.equals(dxWrapper) ||
                com.winlator.container.DXWrappers.D7VK.equals(dxWrapper);
            if (!dxWrapperReady) issues.add("DirectX wrapper selection is unrecognized");

            report.append("\n").append(container.getName()).append(": ")
                .append(issues.isEmpty() ? "No structural issues found" : "Review needed")
                .append("\n");
            report.append("  Display resolution: ").append(screenSize != null ? screenSize : "Unknown")
                .append(screenSizeReady ? " (valid format)" : " (review setting)")
                .append("\n");
            report.append("  Environment variables: ").append(validEnvCount).append(" entries")
                .append(envVarsReady ? " (valid format)" : " (review entries)")
                .append("\n");
            report.append("  Drive mappings: ")
                .append(driveLetters.isEmpty() ? "None" : String.join(", ", driveLetters))
                .append(drivesReady ? " (valid format)" : " (review mappings)")
                .append("\n");
            for (java.util.Map.Entry<String, String> driveStatus : driveStatuses.entrySet()) {
                report.append("    ").append(driveStatus.getKey()).append(": ")
                    .append(driveStatus.getValue()).append("\n");
            }
            report.append("  Mapped drive availability: ")
                .append(driveStatuses.isEmpty() ? "No mappings checked" :
                    (driveStatuses.values().stream().allMatch(status ->
                        status.equals("directory readable") || status.equals("file readable")) ?
                        "All mapped paths readable" : "One or more paths need review"))
                .append("\n");
            report.append("  Container folder/config: ")
                .append(containerDirectoryReady && configReady ? "OK" : "Check")
                .append("\n");
            report.append("  Wine prefix/Windows folder: ")
                .append(prefixReady && windowsDirectoryReady ? "OK" : "Check")
                .append("\n");
            report.append("  Wine version: ").append(wineIdentifier)
                .append(wineReady ? " (binary found)" : " (binary not found)")
                .append("\n");
            report.append("  Box64 preset: ").append(presetId)
                .append(presetReady ? " (preset found)" : " (preset missing/invalid)")
                .append("\n");
            report.append("  Graphics settings: Vulkan ")
                .append(com.winlator.container.GraphicsDrivers.getName(vulkanId))
                .append(" / OpenGL ")
                .append(com.winlator.container.GraphicsDrivers.getName(openGLId))
                .append(graphicsReady ? " (recognized settings)" : " (review selection)")
                .append("\n");
            report.append("  DirectX wrapper: ")
                .append(dxWrapper != null ? com.winlator.container.DXWrappers.getName(dxWrapper) : "Unknown")
                .append(dxWrapperReady ? " (recognized setting)" : " (review selection)")
                .append("\n");

            if (!issues.isEmpty()) {
                report.append("  Findings:\n");
                for (String issue : issues) report.append("  - ").append(issue).append("\n");
            }
            }
            catch (RuntimeException exception) {
                report.append("\nContainer entry: Review needed\n");
                report.append("  Findings:\n");
                report.append("  - audit could not complete safely; saved data may be malformed\n");
            }
        }

        report.append("\nNo container settings were changed. Renderer and wrapper labels show saved selections, not proof that a driver loads or a game runs.\n");
        return report.toString();
    }

"""
if "private String buildWinCoreContainerAudit(" not in java_source:
    anchor = "    private void loadGamepadModelSpinner(Spinner sGamepadModel) {\n"
    if java_source.count(anchor) != 1:
        raise SystemExit(f"Could not find the container audit insertion point in {java_path}.")
    java_source = java_source.replace(anchor, container_audit_methods + anchor, 1)

container_summary_methods = r"""    private String buildWinCoreContainerAuditWithSummary(Context context) {
        String audit = buildWinCoreContainerAudit(context);
        int checked = 0;
        int clean = 0;
        int review = 0;
        int findingCount = 0;

        for (String line : audit.split("\n")) {
            if (line.endsWith(": No structural issues found")) {
                checked++;
                clean++;
            }
            else if (line.endsWith(": Review needed")) {
                checked++;
                review++;
            }
            else if (line.startsWith("  - ")) {
                findingCount++;
            }
        }

        StringBuilder summary = new StringBuilder();
        summary.append("Container Audit Summary\n");
        summary.append("Containers checked: ").append(checked).append("\n");
        summary.append("No structural issues: ").append(clean).append("\n");
        summary.append("Need review: ").append(review).append("\n");
        summary.append("Findings: ").append(findingCount).append("\n\n");
        summary.append(audit);
        return summary.toString();
    }

"""
if "private String buildWinCoreContainerAuditWithSummary(" not in java_source:
    anchor = "    private void loadGamepadModelSpinner(Spinner sGamepadModel) {\n"
    if java_source.count(anchor) != 1:
        raise SystemExit(f"Could not find the container audit summary insertion point in {java_path}.")
    java_source = java_source.replace(anchor, container_summary_methods + anchor, 1)

java_path.write_text(java_source, encoding="utf-8")

print(
    f"WinCore {version} patch applied: app ID, version, provider authority, "
    f"branding, and local device diagnostics ({updated_locales} locale files)."
)
PY


# WinCore 2.0.0: automatic device profiles and app-wide UI customization.
# This second patch stage is deliberately repeatable so CI and local builds
# can apply it more than once without duplicating Java or XML content.
python3 - "$APP_MODULE" <<'PY'
from pathlib import Path
import re
import sys

app = Path(sys.argv[1])

def require_file(relative_path: str) -> Path:
    path = app / relative_path
    if not path.is_file():
        raise SystemExit(f"Required upstream file is missing: {path}")
    return path

def insert_after_once(path: Path, anchor: str, addition: str, marker: str) -> None:
    source = path.read_text(encoding="utf-8")
    if marker in source:
        return
    count = source.count(anchor)
    if count != 1:
        raise SystemExit(f"Expected one insertion anchor in {path}, found {count}.")
    path.write_text(source.replace(anchor, anchor + addition, 1), encoding="utf-8")

def add_import(path: Path, import_line: str) -> None:
    source = path.read_text(encoding="utf-8")
    if import_line in source:
        return
    package_line_end = source.find("\n")
    if package_line_end < 0 or not source.startswith("package "):
        raise SystemExit(f"Cannot locate package declaration in {path}.")
    source = source[:package_line_end + 1] + "\n" + import_line + source[package_line_end + 1:]
    path.write_text(source, encoding="utf-8")

# A device-family selector maps to existing, upstream Box64 presets. Detection
# is based on Android's SoC/hardware identifiers, not on benchmark assumptions.
profile_java = r'''package com.winlator;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;

import androidx.preference.PreferenceManager;

import com.winlator.box64.Box64Preset;
import com.winlator.box64.Box64PresetManager;

import java.util.Locale;
import java.util.regex.Pattern;

public final class WinCoreDeviceProfile {
    public static final String AUTO = "AUTO";
    public static final String DIMENSITY = "DIMENSITY";
    public static final String SNAPDRAGON = "SNAPDRAGON";
    public static final String EXYNOS = "EXYNOS";
    public static final String UNKNOWN = "UNKNOWN";

    private static final Pattern MEDIATEK_SOC = Pattern.compile("(^|[^a-z0-9])mt[0-9]{4,}");
    private static final Pattern QUALCOMM_SOC = Pattern.compile("(^|[^a-z0-9])sm[0-9]{4,}");
    private static final Pattern EXYNOS_SOC = Pattern.compile("(^|[^a-z0-9])s5e[0-9]+");

    private WinCoreDeviceProfile() {}

    public static String detectFamily() {
        String soc = "";
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && Build.SOC_MODEL != null) {
            soc = Build.SOC_MODEL;
        }
        String hardware = Build.HARDWARE != null ? Build.HARDWARE : "";
        String manufacturer = Build.MANUFACTURER != null ? Build.MANUFACTURER : "";
        String combined = (soc + " " + hardware + " " + manufacturer).toLowerCase(Locale.US);

        if (combined.contains("exynos") || EXYNOS_SOC.matcher(combined).find()) {
            return EXYNOS;
        }
        if (combined.contains("dimensity") || combined.contains("mediatek") ||
            MEDIATEK_SOC.matcher(combined).find()) {
            return DIMENSITY;
        }
        if (combined.contains("snapdragon") || combined.contains("qualcomm") ||
            combined.contains("qcom") || QUALCOMM_SOC.matcher(combined).find()) {
            return SNAPDRAGON;
        }
        return UNKNOWN;
    }

    public static String getSelectedProfile(Context context) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        String selected = preferences.getString("wincore_cpu_profile", AUTO);
        return selected != null ? selected : AUTO;
    }

    public static String resolveFamily(Context context) {
        String selected = getSelectedProfile(context);
        return AUTO.equals(selected) ? detectFamily() : selected;
    }

    public static String getBox64Preset(String family) {
        if (DIMENSITY.equals(family)) return Box64Preset.INTERMEDIATE;
        if (SNAPDRAGON.equals(family)) return Box64Preset.PERFORMANCE;
        if (EXYNOS.equals(family)) return Box64Preset.STABILITY;
        return null;
    }

    public static String resolveBox64Preset(Context context, String containerPreset) {
        String family = resolveFamily(context);
        String profilePreset = getBox64Preset(family);
        return profilePreset != null ? profilePreset : containerPreset;
    }

    public static String getDisplayName(String family) {
        if (DIMENSITY.equals(family)) return "MediaTek Dimensity";
        if (SNAPDRAGON.equals(family)) return "Qualcomm Snapdragon";
        if (EXYNOS.equals(family)) return "Samsung Exynos";
        return "Unknown";
    }

    public static String getSummary(Context context) {
        String selected = getSelectedProfile(context);
        String detected = detectFamily();
        String active = AUTO.equals(selected) ? detected : selected;
        String preset = getBox64Preset(active);
        StringBuilder summary = new StringBuilder();
        summary.append("Detected chipset family: ").append(getDisplayName(detected)).append("\n");
        summary.append("Selected profile: ").append(AUTO.equals(selected) ? "Automatic" : getDisplayName(selected)).append("\n");
        if (preset != null) {
            summary.append("Launch-time Box64 preset: ").append(preset).append("\n");
            summary.append("This profile is selected automatically each time a guest program starts.");
        }
        else {
            summary.append("No supported family was identified. Each container's saved Box64 preset will be used.");
        }
        summary.append("\nProfile presets are starting points, not benchmark-verified optimizations. They do not change CPU frequency, cores, or hardware.");
        return summary.toString();
    }
}
'''
profile_path = app / "src/main/java/com/winlator/WinCoreDeviceProfile.java"
profile_path.parent.mkdir(parents=True, exist_ok=True)
if not profile_path.exists():
    profile_path.write_text(profile_java, encoding="utf-8")
else:
    existing = profile_path.read_text(encoding="utf-8")
    if "public final class WinCoreDeviceProfile" not in existing:
        raise SystemExit(f"Refusing to overwrite unrelated file: {profile_path}")

appearance_java = r'''package com.winlator;

import android.app.Activity;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.ColorStateList;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.ProgressBar;
import android.widget.Spinner;
import android.widget.TextView;

import androidx.preference.PreferenceManager;

import com.google.android.material.floatingactionbutton.FloatingActionButton;

import java.util.Collections;
import java.util.Map;
import java.util.WeakHashMap;

public final class WinCoreAppearance {
    public static final int DEFAULT_ACCENT = 0xff0288d1;
    private static final Map<TextView, Float> ORIGINAL_TEXT_SIZES =
        Collections.synchronizedMap(new WeakHashMap<TextView, Float>());

    private WinCoreAppearance() {}

    public static float getTextScale(Context context) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        String density = preferences.getString("wincore_ui_density", "STANDARD");
        if ("COMPACT".equals(density)) return 0.92f;
        if ("LARGE".equals(density)) return 1.08f;
        return 1.0f;
    }

    public static void apply(Activity activity) {
        if (activity == null || activity.getWindow() == null) return;
        apply(activity.getWindow().getDecorView(), activity);
    }

    public static void apply(View root, Context context) {
        if (root == null || context == null) return;
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        int accent = preferences.getInt("wincore_ui_accent", DEFAULT_ACCENT);
        apply(root, accent, getTextScale(context));
    }

    public static void apply(View root, int accent, float textScale) {
        if (root == null) return;
        ColorStateList tint = ColorStateList.valueOf(accent);

        if (root instanceof TextView) {
            TextView textView = (TextView)root;
            Float originalSize = ORIGINAL_TEXT_SIZES.get(textView);
            if (originalSize == null) {
                originalSize = textView.getTextSize();
                ORIGINAL_TEXT_SIZES.put(textView, originalSize);
            }
            textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, originalSize * textScale);
        }

        if (root instanceof CompoundButton) {
            ((CompoundButton)root).setButtonTintList(tint);
        }
        if (root instanceof ProgressBar) {
            ProgressBar progressBar = (ProgressBar)root;
            progressBar.setProgressTintList(tint);
            progressBar.setIndeterminateTintList(tint);
        }
        if (root instanceof Button || root instanceof FloatingActionButton ||
            root instanceof Spinner || root instanceof EditText ||
            root instanceof androidx.appcompat.widget.Toolbar) {
            root.setBackgroundTintList(tint);
        }

        if (root instanceof ViewGroup) {
            ViewGroup group = (ViewGroup)root;
            for (int i = 0; i < group.getChildCount(); i++) {
                apply(group.getChildAt(i), accent, textScale);
            }
        }
    }
}
'''
appearance_path = app / "src/main/java/com/winlator/WinCoreAppearance.java"
appearance_path.parent.mkdir(parents=True, exist_ok=True)
if not appearance_path.exists():
    appearance_path.write_text(appearance_java, encoding="utf-8")
else:
    existing = appearance_path.read_text(encoding="utf-8")
    if "public final class WinCoreAppearance" not in existing:
        raise SystemExit(f"Refusing to overwrite unrelated file: {appearance_path}")

# Resolve the selected device profile in the real guest launch path. The saved
# container preset remains untouched and is used if the SoC family is unknown.
launcher_path = require_file("src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java")
launcher_source = launcher_path.read_text(encoding="utf-8")
launcher_import = "import com.winlator.WinCoreDeviceProfile;\n"
if launcher_import not in launcher_source:
    anchor = "import com.winlator.box64.Box64Preset;\n"
    if launcher_source.count(anchor) != 1:
        raise SystemExit("Could not locate the guest-launcher import anchor.")
    launcher_source = launcher_source.replace(anchor, anchor + launcher_import, 1)
old_preset = "        envVars.putAll(Box64PresetManager.getEnvVars(context, box64Preset));"
new_preset = """        String effectivePreset = WinCoreDeviceProfile.resolveBox64Preset(context, box64Preset);
        envVars.putAll(Box64PresetManager.getEnvVars(context, effectivePreset));"""
if old_preset in launcher_source:
    launcher_source = launcher_source.replace(old_preset, new_preset, 1)
elif new_preset not in launcher_source:
    raise SystemExit("Could not safely patch the Box64 guest-launch preset selection.")
launcher_path.write_text(launcher_source, encoding="utf-8")

# Add profile and appearance controls to the existing Winlator Settings screen.
layout_path = require_file("src/main/res/layout/settings_fragment.xml")
layout_source = layout_path.read_text(encoding="utf-8")
profile_ui = """            <FrameLayout
                android:layout_width="match_parent"
                android:layout_height="wrap_content">

                <LinearLayout style="@style/FieldSet">
                    <TextView
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:text="@string/wincore_profile_description" />

                    <TextView
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:text="@string/wincore_cpu_profile" />

                    <Spinner
                        style="@style/ComboBox"
                        android:id="@+id/SWinCoreDeviceProfile"
                        android:layout_width="match_parent" />

                    <TextView
                        android:id="@+id/TVWinCoreDeviceProfileStatus"
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="8dp"
                        android:textSize="12sp"
                        android:textIsSelectable="true" />

                    <View style="@style/FieldSeparator" />

                    <TextView
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:text="@string/wincore_ui_accent" />

                    <com.winlator.widget.ColorPickerView
                        android:id="@+id/CPVWinCoreAccent"
                        android:layout_width="match_parent"
                        android:layout_height="48dp" />

                    <TextView
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="8dp"
                        android:text="@string/wincore_ui_density" />

                    <Spinner
                        style="@style/ComboBox"
                        android:id="@+id/SWinCoreUIDensity"
                        android:layout_width="match_parent" />

                    <TextView
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="8dp"
                        android:text="@string/wincore_ui_save_note"
                        android:textSize="12sp" />
                </LinearLayout>

                <TextView
                    style="@style/FieldSetLabel"
                    android:text="@string/wincore_customization" />
            </FrameLayout>

"""
layout_anchor = '                <TextView\n                    style="@style/FieldSetLabel"\n                    android:text="@string/wincore_device_diagnostics" />\n            </FrameLayout>\n'
if 'android:id="@+id/SWinCoreDeviceProfile"' not in layout_source:
    if layout_source.count(layout_anchor) != 1:
        raise SystemExit("Could not find the WinCore diagnostics layout anchor.")
    layout_source = layout_source.replace(layout_anchor, layout_anchor + profile_ui, 1)
layout_path.write_text(layout_source, encoding="utf-8")

# Add fallback English strings without disturbing any upstream translations.
strings_path = require_file("src/main/res/values/strings.xml")
strings_source = strings_path.read_text(encoding="utf-8")
strings = """    <string name="wincore_customization">WinCore 2.0.0</string>
    <string name="wincore_profile_description">Choose a device family profile. Automatic mode detects the chipset and selects a Box64 preset whenever a guest program launches.</string>
    <string name="wincore_cpu_profile">CPU compatibility profile</string>
    <string name="wincore_profile_auto">Automatic</string>
    <string name="wincore_profile_dimensity">Dimensity</string>
    <string name="wincore_profile_snapdragon">Snapdragon</string>
    <string name="wincore_profile_exynos">Exynos</string>
    <string name="wincore_ui_accent">Accent color</string>
    <string name="wincore_ui_density">Interface text size</string>
    <string name="wincore_density_compact">Compact</string>
    <string name="wincore_density_standard">Standard</string>
    <string name="wincore_density_large">Large</string>
    <string name="wincore_ui_save_note">The existing Confirm button saves the appearance settings. Device profiles are saved immediately and applied automatically on the next launch.</string>
"""
if 'name="wincore_customization"' not in strings_source:
    end = "</resources>"
    if strings_source.count(end) != 1:
        raise SystemExit("Could not find the end of the default strings resource.")
    strings_source = strings_source.replace(end, strings + end, 1)
strings_path.write_text(strings_source, encoding="utf-8")

# Bind controls in SettingsFragment and persist UI customization with the
# existing Confirm action. Profile selection itself is persisted immediately.
settings_path = require_file("src/main/java/com/winlator/SettingsFragment.java")
settings_source = settings_path.read_text(encoding="utf-8")
binding = "        configureWinCoreDiagnostics(view, context);\n"
new_binding = binding + "        configureWinCoreV2Settings(view, context);\n"
if "configureWinCoreV2Settings(view, context);" not in settings_source:
    if settings_source.count(binding) != 1:
        raise SystemExit("Could not find the WinCore diagnostics binding.")
    settings_source = settings_source.replace(binding, new_binding, 1)

confirm_anchor = "            SharedPreferences.Editor editor = preferences.edit();\n            editor.putString(\"soundfont\", sSoundFont.getSelectedItem().toString());"
confirm_addition = """            SharedPreferences.Editor editor = preferences.edit();
            ColorPickerView cpvWinCoreAccent = view.findViewById(R.id.CPVWinCoreAccent);
            Spinner sWinCoreUIDensity = view.findViewById(R.id.SWinCoreUIDensity);
            String[] winCoreDensityValues = {"COMPACT", "STANDARD", "LARGE"};
            int densityPosition = Math.max(0, Math.min(sWinCoreUIDensity.getSelectedItemPosition(), winCoreDensityValues.length - 1));
            editor.putInt("wincore_ui_accent", cpvWinCoreAccent.getColor());
            editor.putString("wincore_ui_density", winCoreDensityValues[densityPosition]);
            editor.putString("soundfont", sSoundFont.getSelectedItem().toString());"""
if "editor.putInt(\"wincore_ui_accent\"" not in settings_source:
    if settings_source.count(confirm_anchor) != 1:
        raise SystemExit("Could not find the existing Settings Confirm save block.")
    settings_source = settings_source.replace(confirm_anchor, confirm_addition, 1)

commit_anchor = "            if (editor.commit()) {\n"
commit_addition = "            if (editor.commit()) {\n                WinCoreAppearance.apply(getActivity());\n"
if "WinCoreAppearance.apply(getActivity());" not in settings_source:
    if settings_source.count(commit_anchor) != 1:
        raise SystemExit("Could not find the existing Settings save completion block.")
    settings_source = settings_source.replace(commit_anchor, commit_addition, 1)

settings_methods = r'''    private void configureWinCoreV2Settings(View view, Context context) {
        Spinner profileSpinner = view.findViewById(R.id.SWinCoreDeviceProfile);
        TextView profileStatus = view.findViewById(R.id.TVWinCoreDeviceProfileStatus);
        String[] profileIds = {
            WinCoreDeviceProfile.AUTO,
            WinCoreDeviceProfile.DIMENSITY,
            WinCoreDeviceProfile.SNAPDRAGON,
            WinCoreDeviceProfile.EXYNOS
        };
        String[] profileLabels = {
            getString(R.string.wincore_profile_auto),
            getString(R.string.wincore_profile_dimensity),
            getString(R.string.wincore_profile_snapdragon),
            getString(R.string.wincore_profile_exynos)
        };
        profileSpinner.setAdapter(new ArrayAdapter<>(
            context, android.R.layout.simple_spinner_dropdown_item, profileLabels
        ));

        String selectedProfile = WinCoreDeviceProfile.getSelectedProfile(context);
        int selectedPosition = 0;
        for (int i = 0; i < profileIds.length; i++) {
            if (profileIds[i].equals(selectedProfile)) selectedPosition = i;
        }
        profileSpinner.setSelection(selectedPosition, false);
        profileStatus.setText(WinCoreDeviceProfile.getSummary(context));
        profileSpinner.setOnItemSelectedListener(new android.widget.AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(android.widget.AdapterView<?> parent, View selectedView, int position, long id) {
                preferences.edit().putString("wincore_cpu_profile", profileIds[position]).apply();
                profileStatus.setText(WinCoreDeviceProfile.getSummary(context));
            }

            @Override
            public void onNothingSelected(android.widget.AdapterView<?> parent) {}
        });

        ColorPickerView accentPicker = view.findViewById(R.id.CPVWinCoreAccent);
        accentPicker.setPalette(
            0x0288d1, 0x651fff, 0x009688, 0xff9800,
            0xe91e63, 0x607d8b, 0x8bc34a, 0x9c27b0
        );
        accentPicker.setColor(preferences.getInt(
            "wincore_ui_accent", WinCoreAppearance.DEFAULT_ACCENT
        ));

        Spinner densitySpinner = view.findViewById(R.id.SWinCoreUIDensity);
        String[] densityLabels = {
            getString(R.string.wincore_density_compact),
            getString(R.string.wincore_density_standard),
            getString(R.string.wincore_density_large)
        };
        densitySpinner.setAdapter(new ArrayAdapter<>(
            context, android.R.layout.simple_spinner_dropdown_item, densityLabels
        ));
        String density = preferences.getString("wincore_ui_density", "STANDARD");
        int densityPosition = "COMPACT".equals(density) ? 0 : ("LARGE".equals(density) ? 2 : 1);
        densitySpinner.setSelection(densityPosition, false);

        WinCoreAppearance.apply(view, context);
    }

'''
if "private void configureWinCoreV2Settings(" not in settings_source:
    anchor = "    private void loadGamepadModelSpinner(Spinner sGamepadModel) {\n"
    if settings_source.count(anchor) != 1:
        raise SystemExit("Could not find SettingsFragment method insertion point.")
    settings_source = settings_source.replace(anchor, settings_methods + anchor, 1)
settings_path.write_text(settings_source, encoding="utf-8")

# Apply the selected accent and text scale to each app screen, including
# fragments created after the activity's first launch.
main_path = require_file("src/main/java/com/winlator/MainActivity.java")
main_source = main_path.read_text(encoding="utf-8")
view_import = "import android.view.View;\n"
if view_import not in main_source:
    anchor = "import android.view.MenuItem;\n"
    if main_source.count(anchor) != 1:
        raise SystemExit("Could not locate MainActivity's Android view imports.")
    main_source = main_source.replace(anchor, anchor + view_import, 1)

fragment_hook = """        getSupportFragmentManager().registerFragmentLifecycleCallbacks(
            new FragmentManager.FragmentLifecycleCallbacks() {
                @Override
                public void onFragmentViewCreated(
                    @NonNull FragmentManager fragmentManager,
                    @NonNull Fragment fragment,
                    @NonNull View fragmentView,
                    @Nullable Bundle savedInstanceState
                ) {
                    WinCoreAppearance.apply(fragmentView, MainActivity.this);
                }
            },
            true
        );

"""
activity_anchor = "        setContentView(R.layout.main_activity);\n"
if "registerFragmentLifecycleCallbacks(" not in main_source:
    if main_source.count(activity_anchor) != 1:
        raise SystemExit("Could not find MainActivity content view initialization.")
    main_source = main_source.replace(activity_anchor, activity_anchor + "\n" + fragment_hook, 1)

resume_hook = """    @Override
    protected void onResume() {
        super.onResume();
        WinCoreAppearance.apply(getWindow().getDecorView(), this);
    }

"""
if "protected void onResume()" not in main_source:
    anchor = "    @Override\n    protected void attachBaseContext(Context newBase) {\n"
    if main_source.count(anchor) != 1:
        raise SystemExit("Could not find MainActivity lifecycle insertion point.")
    main_source = main_source.replace(anchor, resume_hook + anchor, 1)
main_path.write_text(main_source, encoding="utf-8")

print("WinCore 2.0.0 automatic device profiles and customizable app-wide UI patch applied.")
PY


# WinCore 3.0.0: per-container and per-game profile system, adaptive launch,
# live session monitoring, and expanded profile sharing/customization.
python3 - "$APP_MODULE" <<'PY'
from pathlib import Path
import sys

app = Path(sys.argv[1])

def required(relative):
    path = app / relative
    if not path.is_file():
        raise SystemExit(f"Required upstream file missing: {path}")
    return path

def add_import(path, anchor, value):
    source = path.read_text(encoding="utf-8")
    if value.strip() in source:
        return source
    if source.count(anchor) != 1:
        raise SystemExit(f"Import anchor mismatch in {path}: {anchor!r}")
    source = source.replace(anchor, anchor + value, 1)
    path.write_text(source, encoding="utf-8")
    return source

# Replace the 2.0 family resolver with an extensible, safe launch resolver.
profile_path = app / "src/main/java/com/winlator/WinCoreDeviceProfile.java"
profile_path.parent.mkdir(parents=True, exist_ok=True)
profile_java = r'''package com.winlator;

import android.app.ActivityManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.PowerManager;

import androidx.preference.PreferenceManager;

import com.winlator.box64.Box64Preset;
import com.winlator.box64.Box64PresetManager;

import java.util.Locale;
import java.util.regex.Pattern;

public final class WinCoreDeviceProfile {
    public static final String GLOBAL = "GLOBAL";
    public static final String AUTO = "AUTO";
    public static final String DIMENSITY = "DIMENSITY";
    public static final String SNAPDRAGON = "SNAPDRAGON";
    public static final String EXYNOS = "EXYNOS";
    public static final String UNKNOWN = "UNKNOWN";

    private static final Pattern MEDIATEK = Pattern.compile("(^|[^a-z0-9])(mt[0-9]{4,}|mtk)([^a-z0-9]|$)");
    private static final Pattern QUALCOMM = Pattern.compile("(^|[^a-z0-9])(sm[0-9]{4,}|msm[0-9]*|sdm[0-9]*|qcom|apq[0-9]*)([^a-z0-9]|$)");
    private static final Pattern EXYNOS_SOC = Pattern.compile("(^|[^a-z0-9])(s5e[0-9]+|universal[0-9]+)([^a-z0-9]|$)");

    private WinCoreDeviceProfile() {}

    public static String detectFamily() {
        StringBuilder identifiers = new StringBuilder();
        append(identifiers, Build.HARDWARE);
        append(identifiers, Build.BOARD);
        append(identifiers, Build.BOOTLOADER);
        append(identifiers, Build.PRODUCT);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) append(identifiers, Build.SOC_MODEL);

        String values = identifiers.toString().toLowerCase(Locale.US);
        if (values.contains("exynos") || EXYNOS_SOC.matcher(values).find()) return EXYNOS;
        if (values.contains("dimensity") || values.contains("mediatek") ||
            MEDIATEK.matcher(values).find()) return DIMENSITY;
        if (values.contains("snapdragon") || values.contains("qualcomm") ||
            values.contains("qcom") || QUALCOMM.matcher(values).find()) return SNAPDRAGON;

        // Manufacturer alone is deliberately not enough: several manufacturers
        // ship devices with more than one chipset family.
        return UNKNOWN;
    }

    private static void append(StringBuilder target, String value) {
        if (value == null || value.trim().isEmpty()) return;
        if (target.length() > 0) target.append(' ');
        target.append(value.trim());
    }

    public static String getSelectedProfile(Context context) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        String selected = preferences.getString("wincore_cpu_profile", AUTO);
        return selected != null ? selected : AUTO;
    }

    public static String resolveFamily(Context context, String requestedProfile) {
        String selection = requestedProfile;
        if (selection == null || selection.isEmpty() || GLOBAL.equals(selection)) {
            selection = getSelectedProfile(context);
        }
        if (AUTO.equals(selection)) return detectFamily();
        if (DIMENSITY.equals(selection) || SNAPDRAGON.equals(selection) || EXYNOS.equals(selection)) {
            return selection;
        }
        return UNKNOWN;
    }

    public static String resolveBox64Preset(Context context, String containerPreset) {
        return resolveBox64Preset(context, containerPreset, GLOBAL);
    }

    public static String resolveBox64Preset(Context context, String containerPreset, String requestedProfile) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        String family = resolveFamily(context, requestedProfile);
        String preset = containerPreset;

        if (DIMENSITY.equals(family)) {
            preset = preferences.getString("wincore_box64_preset_dimensity", Box64Preset.INTERMEDIATE);
        }
        else if (SNAPDRAGON.equals(family)) {
            preset = preferences.getString("wincore_box64_preset_snapdragon", Box64Preset.PERFORMANCE);
        }
        else if (EXYNOS.equals(family)) {
            preset = preferences.getString("wincore_box64_preset_exynos", Box64Preset.STABILITY);
        }

        boolean selectedPresetValid = false;
        try {
            selectedPresetValid = preset != null && Box64PresetManager.getPreset(context, preset) != null;
        }
        catch (RuntimeException exception) {
            selectedPresetValid = false;
        }
        if (!selectedPresetValid) {
            preset = containerPreset;
            try {
                selectedPresetValid = preset != null && Box64PresetManager.getPreset(context, preset) != null;
            }
            catch (RuntimeException exception) {
                selectedPresetValid = false;
            }
        }
        if (!selectedPresetValid) preset = Box64Preset.DEFAULT;

        if (preferences.getBoolean("wincore_adaptive_launch", false) && isUnderSystemPressure(context)) {
            return Box64Preset.STABILITY;
        }
        return preset;
    }

    public static boolean isUnderSystemPressure(Context context) {
        ActivityManager manager = (ActivityManager)context.getSystemService(Context.ACTIVITY_SERVICE);
        if (manager != null) {
            ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
            manager.getMemoryInfo(memoryInfo);
            if (memoryInfo.lowMemory) return true;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            PowerManager powerManager = (PowerManager)context.getSystemService(Context.POWER_SERVICE);
            if (powerManager != null) {
                return powerManager.getCurrentThermalStatus() >= PowerManager.THERMAL_STATUS_SEVERE;
            }
        }
        return false;
    }

    public static String getBox64Preset(Context context, String family) {
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);
        if (DIMENSITY.equals(family)) {
            return preferences.getString("wincore_box64_preset_dimensity", Box64Preset.INTERMEDIATE);
        }
        if (SNAPDRAGON.equals(family)) {
            return preferences.getString("wincore_box64_preset_snapdragon", Box64Preset.PERFORMANCE);
        }
        if (EXYNOS.equals(family)) {
            return preferences.getString("wincore_box64_preset_exynos", Box64Preset.STABILITY);
        }
        return null;
    }

    public static String getDisplayName(String family) {
        if (DIMENSITY.equals(family)) return "MediaTek Dimensity";
        if (SNAPDRAGON.equals(family)) return "Qualcomm Snapdragon";
        if (EXYNOS.equals(family)) return "Samsung Exynos";
        return "Unknown chipset";
    }

    public static String getSummary(Context context) {
        String selected = getSelectedProfile(context);
        String detected = detectFamily();
        String active = AUTO.equals(selected) ? detected : selected;
        String preset = getBox64Preset(context, active);
        SharedPreferences preferences = PreferenceManager.getDefaultSharedPreferences(context);

        StringBuilder summary = new StringBuilder();
        summary.append("Detected chipset: ").append(getDisplayName(detected)).append("\n");
        summary.append("Global profile: ").append(AUTO.equals(selected) ? "Automatic" : getDisplayName(selected)).append("\n");
        summary.append("Active Box64 preset: ").append(preset != null ? preset : "Container preset fallback").append("\n");
        summary.append("Adaptive launch safety: ").append(preferences.getBoolean("wincore_adaptive_launch", false) ? "On" : "Off");
        summary.append("\nProfiles are launch-time Box64 configurations, not CPU overclocking or benchmark guarantees.");
        return summary.toString();
    }
}
'''
profile_path.write_text(profile_java, encoding="utf-8")

# Selector shared by container and per-game shortcut settings. GLOBAL inherits
# the next level; AUTO performs a fresh SoC detection on each guest launch.
controls_path = app / "src/main/java/com/winlator/WinCoreProfileControls.java"
controls_java = r'''package com.winlator;

import android.content.Context;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;

public final class WinCoreProfileControls {
    private static final String[] VALUES = {
        WinCoreDeviceProfile.GLOBAL,
        WinCoreDeviceProfile.AUTO,
        WinCoreDeviceProfile.DIMENSITY,
        WinCoreDeviceProfile.SNAPDRAGON,
        WinCoreDeviceProfile.EXYNOS
    };

    private WinCoreProfileControls() {}

    public static Spinner addProfileSelector(Context context, LinearLayout parent, String selectedValue) {
        TextView label = new TextView(context);
        label.setText("WinCore CPU device profile override");
        label.setTextSize(14);
        label.setPadding(0, dp(context, 8), 0, dp(context, 4));
        parent.addView(label, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ));

        String[] labels = {
            "Inherit global profile",
            "Automatic device detection",
            "Dimensity",
            "Snapdragon",
            "Exynos"
        };
        Spinner spinner = new Spinner(context);
        spinner.setAdapter(new ArrayAdapter<>(
            context, android.R.layout.simple_spinner_dropdown_item, labels
        ));
        spinner.setTag(VALUES.clone());
        spinner.setMinimumHeight(dp(context, 42));
        spinner.setPadding(dp(context, 8), 0, dp(context, 8), 0);
        int selected = 0;
        if (selectedValue != null) {
            for (int i = 0; i < VALUES.length; i++) {
                if (VALUES[i].equals(selectedValue)) selected = i;
            }
        }
        spinner.setSelection(selected, false);
        parent.addView(spinner, new LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ));
        return spinner;
    }

    public static String getSelectedProfile(Spinner spinner) {
        if (spinner == null) return WinCoreDeviceProfile.GLOBAL;
        Object tag = spinner.getTag();
        if (!(tag instanceof String[])) return WinCoreDeviceProfile.GLOBAL;
        String[] values = (String[])tag;
        int position = spinner.getSelectedItemPosition();
        return position >= 0 && position < values.length ?
            values[position] : WinCoreDeviceProfile.GLOBAL;
    }

    private static int dp(Context context, int value) {
        return (int)(value * context.getResources().getDisplayMetrics().density + 0.5f);
    }
}
'''
controls_path.write_text(controls_java, encoding="utf-8")

# Live optional game-session monitor: process CPU time, app PSS, system RAM,
# battery temperature, and Android thermal status. GPU utilization is not
# exposed by a portable public Android API and is explicitly not fabricated.
overlay_path = app / "src/main/java/com/winlator/WinCorePerformanceOverlay.java"
overlay_java = r'''package com.winlator;

import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.BatteryManager;
import android.os.Build;
import android.os.Debug;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.os.Process;
import android.os.SystemClock;
import android.view.Gravity;
import android.widget.TextView;

import androidx.preference.PreferenceManager;

import java.util.Locale;

public final class WinCorePerformanceOverlay extends TextView {
    private final Handler handler = new Handler(Looper.getMainLooper());
    private long lastWallTime;
    private long lastCpuTime;
    private final Runnable updater = new Runnable() {
        @Override
        public void run() {
            refreshMetrics();
            handler.postDelayed(this, 2000);
        }
    };

    public WinCorePerformanceOverlay(Context context) {
        super(context);
        setTextColor(Color.WHITE);
        setTextSize(11);
        setGravity(Gravity.START);
        int padding = dp(9);
        setPadding(padding, padding, padding, padding);
        setClickable(false);
        setFocusable(false);

        GradientDrawable background = new GradientDrawable();
        background.setColor(0xdd15191f);
        background.setCornerRadius(dp(8));
        int accent = PreferenceManager.getDefaultSharedPreferences(context)
            .getInt("wincore_ui_accent", WinCoreAppearance.DEFAULT_ACCENT);
        background.setStroke(dp(2), accent);
        setBackground(background);
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        handler.removeCallbacks(updater);
        handler.post(updater);
    }

    @Override
    protected void onDetachedFromWindow() {
        handler.removeCallbacks(updater);
        super.onDetachedFromWindow();
    }

    private void refreshMetrics() {
        long now = SystemClock.elapsedRealtime();
        long cpuNow = Process.getElapsedCpuTime();
        float cpuPercent = -1.0f;
        if (lastWallTime > 0 && now > lastWallTime) {
            long elapsedWall = now - lastWallTime;
            long elapsedCpu = Math.max(0, cpuNow - lastCpuTime);
            int cores = Math.max(1, Runtime.getRuntime().availableProcessors());
            cpuPercent = Math.min(100.0f, (elapsedCpu * 100.0f) / (elapsedWall * cores));
        }
        lastWallTime = now;
        lastCpuTime = cpuNow;

        float processRamMb = Debug.getPss() / 1024.0f;
        ActivityManager manager = (ActivityManager)getContext().getSystemService(Context.ACTIVITY_SERVICE);
        ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
        String availableRam = "Unknown";
        if (manager != null) {
            manager.getMemoryInfo(memoryInfo);
            availableRam = String.format(Locale.US, "%.2f GB",
                memoryInfo.availMem / (1024.0 * 1024.0 * 1024.0));
        }

        String thermal = "Not available";
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            PowerManager powerManager = (PowerManager)getContext().getSystemService(Context.POWER_SERVICE);
            if (powerManager != null) thermal = thermalLabel(powerManager.getCurrentThermalStatus());
        }

        String batteryTemperature = "Not available";
        Intent battery = getContext().registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if (battery != null && battery.hasExtra(BatteryManager.EXTRA_TEMPERATURE)) {
            batteryTemperature = String.format(Locale.US, "%.1f C",
                battery.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) / 10.0f);
        }

        String cpu = cpuPercent >= 0 ? String.format(Locale.US, "%.1f%%", cpuPercent) : "Sampling";
        setText("WinCore live monitor\n" +
            "App CPU: " + cpu + "\n" +
            "App memory (PSS): " + String.format(Locale.US, "%.0f MB", processRamMb) + "\n" +
            "Available system RAM: " + availableRam + "\n" +
            "Battery temperature: " + batteryTemperature + "\n" +
            "Thermal status: " + thermal + "\n" +
            "GPU utilization: not exposed by Android");
    }

    private String thermalLabel(int status) {
        switch (status) {
            case PowerManager.THERMAL_STATUS_NONE: return "Normal";
            case PowerManager.THERMAL_STATUS_LIGHT: return "Light";
            case PowerManager.THERMAL_STATUS_MODERATE: return "Moderate";
            case PowerManager.THERMAL_STATUS_SEVERE: return "Severe";
            case PowerManager.THERMAL_STATUS_CRITICAL: return "Critical";
            case PowerManager.THERMAL_STATUS_EMERGENCY: return "Emergency";
            case PowerManager.THERMAL_STATUS_SHUTDOWN: return "Shutdown";
            default: return "Unknown";
        }
    }

    private int dp(int value) {
        return (int)(value * getResources().getDisplayMetrics().density + 0.5f);
    }
}
'''
overlay_path.write_text(overlay_java, encoding="utf-8")

# Launch-time device profile resolver is now aware of the container/shortcut
# override selected by the user.
launcher_path = required("src/main/java/com/winlator/xenvironment/components/GuestProgramLauncherComponent.java")
launcher_source = launcher_path.read_text(encoding="utf-8")
if "import com.winlator.WinCoreDeviceProfile;" not in launcher_source:
    anchor = "import com.winlator.box64.Box64Preset;\n"
    if launcher_source.count(anchor) != 1:
        raise SystemExit("Guest launcher import anchor was not unique.")
    launcher_source = launcher_source.replace(anchor, anchor + "import com.winlator.WinCoreDeviceProfile;\n", 1)
if "private String winCoreDeviceProfile" not in launcher_source:
    anchor = "    private String box64Preset = Box64Preset.CONSERVATIVE;\n"
    if launcher_source.count(anchor) != 1:
        raise SystemExit("Guest launcher field anchor was not unique.")
    launcher_source = launcher_source.replace(anchor, anchor + "    private String winCoreDeviceProfile = WinCoreDeviceProfile.GLOBAL;\n", 1)
    setter = """    public void setWinCoreDeviceProfile(String profile) {
        this.winCoreDeviceProfile = profile != null ? profile : WinCoreDeviceProfile.GLOBAL;
    }

"""
    anchor = "    private int execGuestProgram() {\n"
    if launcher_source.count(anchor) != 1:
        raise SystemExit("Guest launcher method anchor was not unique.")
    launcher_source = launcher_source.replace(anchor, setter + anchor, 1)
launcher_source = launcher_source.replace(
    "String effectivePreset = WinCoreDeviceProfile.resolveBox64Preset(context, box64Preset);",
    "String effectivePreset = WinCoreDeviceProfile.resolveBox64Preset(context, box64Preset, winCoreDeviceProfile);"
)
if "WinCoreDeviceProfile.resolveBox64Preset(context, box64Preset, winCoreDeviceProfile)" not in launcher_source:
    raise SystemExit("Guest launcher profile resolution was not updated.")
launcher_path.write_text(launcher_source, encoding="utf-8")

# Container-level profile override in the existing Advanced tab.
container_path = required("src/main/java/com/winlator/ContainerDetailFragment.java")
container_source = container_path.read_text(encoding="utf-8")
container_anchor = "        createDrivesTab(view);\n"
if "sWinCoreDeviceProfile" not in container_source:
    if container_source.count(container_anchor) != 1:
        raise SystemExit("Container detail profile selector anchor was not unique.")
    container_source = container_source.replace(
        container_anchor,
        container_anchor + """        final Spinner sWinCoreDeviceProfile = WinCoreProfileControls.addProfileSelector(
            context,
            view.findViewById(R.id.LLTabAdvanced),
            isEditMode() ? container.getExtra("wincore_cpu_profile", WinCoreDeviceProfile.GLOBAL) : WinCoreDeviceProfile.GLOBAL
        );
""",
        1
    )
save_anchor = "                    container.setBox64Preset(box64Preset);\n"
if "container.putExtra(\"wincore_cpu_profile\"" not in container_source:
    if container_source.count(save_anchor) != 1:
        raise SystemExit("Container edit save profile anchor was not unique.")
    container_source = container_source.replace(
        save_anchor,
        save_anchor + """                    String selectedWinCoreProfile = WinCoreProfileControls.getSelectedProfile(sWinCoreDeviceProfile);
                    container.putExtra("wincore_cpu_profile",
                        WinCoreDeviceProfile.GLOBAL.equals(selectedWinCoreProfile) ? null : selectedWinCoreProfile);
""",
        1
    )
callback_anchor = """                        if (container != null) {
                            this.container = container;
                            saveWineRegistryKeys(view);
                        }
"""
callback_addition = """                        if (container != null) {
                            this.container = container;
                            String selectedWinCoreProfile = WinCoreProfileControls.getSelectedProfile(sWinCoreDeviceProfile);
                            container.putExtra("wincore_cpu_profile",
                                WinCoreDeviceProfile.GLOBAL.equals(selectedWinCoreProfile) ? null : selectedWinCoreProfile);
                            container.saveData();
                            saveWineRegistryKeys(view);
                        }
"""
if callback_anchor in container_source:
    container_source = container_source.replace(callback_anchor, callback_addition, 1)
elif "container.putExtra(\"wincore_cpu_profile\"" not in container_source:
    raise SystemExit("New container callback profile save anchor was not found.")
container_path.write_text(container_source, encoding="utf-8")

# Per-game shortcut-level override: more specific than container/global profile.
shortcut_path = required("src/main/java/com/winlator/contentdialog/ShortcutSettingsDialog.java")
shortcut_source = shortcut_path.read_text(encoding="utf-8")
for shortcut_import in (
    "import com.winlator.WinCoreDeviceProfile;\n",
    "import com.winlator.WinCoreProfileControls;\n"
):
    if shortcut_import.strip() not in shortcut_source:
        shortcut_import_anchor = "import com.winlator.ContainerDetailFragment;\n"
        if shortcut_source.count(shortcut_import_anchor) != 1:
            raise SystemExit("Could not add WinCore profile imports to ShortcutSettingsDialog.")
        shortcut_source = shortcut_source.replace(
            shortcut_import_anchor,
            shortcut_import_anchor + shortcut_import,
            1
        )
box64_anchor = "        Box64PresetManager.loadSpinner(sBox64Preset, shortcut.getExtra(\"box64Preset\", shortcut.container.getBox64Preset()));\n"
if "sWinCoreDeviceProfile" not in shortcut_source:
    if shortcut_source.count(box64_anchor) != 1:
        raise SystemExit("Shortcut profile selector insertion anchor was not unique.")
    shortcut_source = shortcut_source.replace(
        box64_anchor,
        box64_anchor + """        final Spinner sWinCoreDeviceProfile = WinCoreProfileControls.addProfileSelector(
            context,
            findViewById(R.id.LLTabAdvanced),
            shortcut.getExtra("wincore_cpu_profile", WinCoreDeviceProfile.GLOBAL)
        );
""",
        1
    )
shortcut_save_anchor = '            shortcut.putExtra("box64Preset", !box64Preset.equals(shortcut.container.getBox64Preset()) ? box64Preset : null);\n'
if 'shortcut.putExtra("wincore_cpu_profile"' not in shortcut_source:
    if shortcut_source.count(shortcut_save_anchor) != 1:
        raise SystemExit("Shortcut profile save anchor was not unique.")
    shortcut_source = shortcut_source.replace(
        shortcut_save_anchor,
        shortcut_save_anchor + """            String selectedWinCoreProfile = WinCoreProfileControls.getSelectedProfile(sWinCoreDeviceProfile);
            shortcut.putExtra("wincore_cpu_profile",
                WinCoreDeviceProfile.GLOBAL.equals(selectedWinCoreProfile) ? null : selectedWinCoreProfile);
""",
        1
    )
shortcut_path.write_text(shortcut_source, encoding="utf-8")

# Select the most specific profile on each real game launch.
display_path = required("src/main/java/com/winlator/XServerDisplayActivity.java")
display_source = display_path.read_text(encoding="utf-8")
if "import android.view.Gravity;" not in display_source:
    display_source = add_import(display_path, "import android.view.FrameLayout;\n" if "import android.view.FrameLayout;\n" in display_source else "import android.view.View;\n", "import android.view.Gravity;\n")
if "setWinCoreDeviceProfile(selectedWinCoreProfile)" not in display_source:
    anchor = '            guestProgramLauncherComponent.setBox64Preset(shortcut != null ? shortcut.getExtra("box64Preset", container.getBox64Preset()) : container.getBox64Preset());\n'
    if display_source.count(anchor) != 1:
        raise SystemExit("Game launch profile setter anchor was not unique.")
    display_source = display_source.replace(
        anchor,
        anchor + """            String selectedWinCoreProfile = shortcut != null ?
                shortcut.getExtra("wincore_cpu_profile", container.getExtra("wincore_cpu_profile", WinCoreDeviceProfile.GLOBAL)) :
                container.getExtra("wincore_cpu_profile", WinCoreDeviceProfile.GLOBAL);
            guestProgramLauncherComponent.setWinCoreDeviceProfile(selectedWinCoreProfile);
""",
        1
    )
monitor_anchor = """        if (container != null && container.getHUDMode() != FrameRating.Mode.DISABLED.ordinal()) {
            frameRating = new FrameRating(this);
            frameRating.setMode(FrameRating.Mode.values()[container.getHUDMode()]);
            frameRating.setVisibility(View.GONE);
            rootView.addView(frameRating);
        }
"""
monitor_addition = monitor_anchor + """
        if (preferences.getBoolean("wincore_live_monitor", false)) {
            WinCorePerformanceOverlay monitor = new WinCorePerformanceOverlay(this);
            FrameLayout.LayoutParams monitorParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP | Gravity.END
            );
            int monitorMargin = (int)(8 * getResources().getDisplayMetrics().density + 0.5f);
            monitorParams.setMargins(monitorMargin, monitorMargin, monitorMargin, monitorMargin);
            rootView.addView(monitor, monitorParams);
        }
"""
if "new WinCorePerformanceOverlay(this)" not in display_source:
    if display_source.count(monitor_anchor) != 1:
        raise SystemExit("XServer live monitor insertion anchor was not unique.")
    display_source = display_source.replace(monitor_anchor, monitor_addition, 1)
display_path.write_text(display_source, encoding="utf-8")

# Settings screen: user-configurable mapping per chipset, adaptive launch mode,
# optional session monitor, reset appearance, and export a compact profile.
layout_path = required("src/main/res/layout/settings_fragment.xml")
layout_source = layout_path.read_text(encoding="utf-8")
density_anchor = """                    <Spinner
                        style="@style/ComboBox"
                        android:id="@+id/SWinCoreUIDensity"
                        android:layout_width="match_parent" />
"""
extra_controls = """                    <View style="@style/FieldSeparator" />

                    <TextView
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:text="@string/wincore_preset_dimensity" />
                    <Spinner
                        style="@style/ComboBox"
                        android:id="@+id/SWinCorePresetDimensity"
                        android:layout_width="match_parent" />

                    <TextView
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:text="@string/wincore_preset_snapdragon" />
                    <Spinner
                        style="@style/ComboBox"
                        android:id="@+id/SWinCorePresetSnapdragon"
                        android:layout_width="match_parent" />

                    <TextView
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:text="@string/wincore_preset_exynos" />
                    <Spinner
                        style="@style/ComboBox"
                        android:id="@+id/SWinCorePresetExynos"
                        android:layout_width="match_parent" />

                    <CheckBox
                        android:id="@+id/CBWinCoreAdaptiveLaunch"
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="8dp"
                        android:text="@string/wincore_adaptive_launch" />

                    <CheckBox
                        android:id="@+id/CBWinCoreLiveMonitor"
                        android:layout_width="wrap_content"
                        android:layout_height="wrap_content"
                        android:layout_marginTop="4dp"
                        android:text="@string/wincore_live_monitor" />

                    <LinearLayout
                        android:layout_width="match_parent"
                        android:layout_height="wrap_content"
                        android:orientation="horizontal"
                        android:gravity="center_vertical">

                        <Button
                            android:id="@+id/BTWinCoreResetAppearance"
                            style="@style/ButtonNeutral"
                            android:layout_width="0dp"
                            android:layout_height="wrap_content"
                            android:layout_weight="1"
                            android:text="@string/wincore_reset_appearance" />

                        <Button
                            android:id="@+id/BTWinCoreShareProfile"
                            style="@style/ButtonNeutral"
                            android:layout_width="0dp"
                            android:layout_height="wrap_content"
                            android:layout_weight="1"
                            android:text="@string/wincore_share_profile" />
                    </LinearLayout>
"""
if 'android:id="@+id/SWinCorePresetDimensity"' not in layout_source:
    if layout_source.count(density_anchor) != 1:
        raise SystemExit("Settings layout density spinner anchor was not unique.")
    layout_source = layout_source.replace(density_anchor, density_anchor + extra_controls, 1)
layout_path.write_text(layout_source, encoding="utf-8")

strings_path = required("src/main/res/values/strings.xml")
strings_source = strings_path.read_text(encoding="utf-8")
more_strings = """    <string name="wincore_preset_dimensity">Dimensity Box64 preset</string>
    <string name="wincore_preset_snapdragon">Snapdragon Box64 preset</string>
    <string name="wincore_preset_exynos">Exynos Box64 preset</string>
    <string name="wincore_adaptive_launch">Adaptive launch safety (low-memory / severe thermal)</string>
    <string name="wincore_live_monitor">Show live session monitor while playing</string>
    <string name="wincore_reset_appearance">Reset appearance</string>
    <string name="wincore_share_profile">Share profile</string>
    <string name="wincore_profile_shared">WinCore profile ready to share</string>
"""
if 'name="wincore_preset_dimensity"' not in strings_source:
    if strings_source.count("</resources>") != 1:
        raise SystemExit("Default strings resource end marker was not unique.")
    strings_source = strings_source.replace("</resources>", more_strings + "</resources>", 1)
strings_path.write_text(strings_source, encoding="utf-8")

settings_path = required("src/main/java/com/winlator/SettingsFragment.java")
settings_source = settings_path.read_text(encoding="utf-8")
if "configureWinCoreV3Settings(view, context);" not in settings_source:
    anchor = "        configureWinCoreV2Settings(view, context);\n"
    if settings_source.count(anchor) != 1:
        raise SystemExit("SettingsFragment WinCore v2 binder anchor was not unique.")
    settings_source = settings_source.replace(anchor, anchor + "        configureWinCoreV3Settings(view, context);\n", 1)

new_save_anchor = '            editor.putString("wincore_ui_density", winCoreDensityValues[densityPosition]);\n'
new_save = new_save_anchor + """            editor.putString("wincore_box64_preset_dimensity", Box64PresetManager.getSpinnerSelectedId((Spinner)view.findViewById(R.id.SWinCorePresetDimensity)));
            editor.putString("wincore_box64_preset_snapdragon", Box64PresetManager.getSpinnerSelectedId((Spinner)view.findViewById(R.id.SWinCorePresetSnapdragon)));
            editor.putString("wincore_box64_preset_exynos", Box64PresetManager.getSpinnerSelectedId((Spinner)view.findViewById(R.id.SWinCorePresetExynos)));
            editor.putBoolean("wincore_adaptive_launch", ((CheckBox)view.findViewById(R.id.CBWinCoreAdaptiveLaunch)).isChecked());
            editor.putBoolean("wincore_live_monitor", ((CheckBox)view.findViewById(R.id.CBWinCoreLiveMonitor)).isChecked());
"""
if 'editor.putBoolean("wincore_adaptive_launch"' not in settings_source:
    if settings_source.count(new_save_anchor) != 1:
        raise SystemExit("Settings profile map save anchor was not unique.")
    settings_source = settings_source.replace(new_save_anchor, new_save, 1)

v3_methods = r'''    private void configureWinCoreV3Settings(View view, Context context) {
        Spinner dimensity = view.findViewById(R.id.SWinCorePresetDimensity);
        Spinner snapdragon = view.findViewById(R.id.SWinCorePresetSnapdragon);
        Spinner exynos = view.findViewById(R.id.SWinCorePresetExynos);
        Box64PresetManager.loadSpinner(dimensity,
            preferences.getString("wincore_box64_preset_dimensity", Box64Preset.INTERMEDIATE));
        Box64PresetManager.loadSpinner(snapdragon,
            preferences.getString("wincore_box64_preset_snapdragon", Box64Preset.PERFORMANCE));
        Box64PresetManager.loadSpinner(exynos,
            preferences.getString("wincore_box64_preset_exynos", Box64Preset.STABILITY));

        CheckBox adaptive = view.findViewById(R.id.CBWinCoreAdaptiveLaunch);
        adaptive.setChecked(preferences.getBoolean("wincore_adaptive_launch", false));
        CheckBox monitor = view.findViewById(R.id.CBWinCoreLiveMonitor);
        monitor.setChecked(preferences.getBoolean("wincore_live_monitor", false));

        view.findViewById(R.id.BTWinCoreResetAppearance).setOnClickListener((v) -> {
            preferences.edit()
                .putInt("wincore_ui_accent", WinCoreAppearance.DEFAULT_ACCENT)
                .putString("wincore_ui_density", "STANDARD")
                .apply();
            ((ColorPickerView)view.findViewById(R.id.CPVWinCoreAccent)).setColor(WinCoreAppearance.DEFAULT_ACCENT);
            ((Spinner)view.findViewById(R.id.SWinCoreUIDensity)).setSelection(1);
            WinCoreAppearance.apply(getActivity());
        });

        view.findViewById(R.id.BTWinCoreShareProfile).setOnClickListener((v) -> {
            try {
                org.json.JSONObject profile = new org.json.JSONObject();
                profile.put("format", "wincore-profile-v1");
                profile.put("deviceProfile", WinCoreDeviceProfile.getSelectedProfile(context));
                profile.put("dimensityPreset", Box64PresetManager.getSpinnerSelectedId(dimensity));
                profile.put("snapdragonPreset", Box64PresetManager.getSpinnerSelectedId(snapdragon));
                profile.put("exynosPreset", Box64PresetManager.getSpinnerSelectedId(exynos));
                profile.put("adaptiveLaunch", adaptive.isChecked());
                profile.put("liveMonitor", monitor.isChecked());
                profile.put("accentColor", ((ColorPickerView)view.findViewById(R.id.CPVWinCoreAccent)).getColor());
                int selectedDensity = ((Spinner)view.findViewById(R.id.SWinCoreUIDensity)).getSelectedItemPosition();
                profile.put("uiDensity", selectedDensity == 0 ? "COMPACT" : (selectedDensity == 2 ? "LARGE" : "STANDARD"));

                Intent share = new Intent(Intent.ACTION_SEND);
                share.setType("application/json");
                share.putExtra(Intent.EXTRA_SUBJECT, "WinCore device profile");
                share.putExtra(Intent.EXTRA_TEXT, profile.toString(2));
                startActivity(Intent.createChooser(share, getString(R.string.wincore_profile_shared)));
            }
            catch (org.json.JSONException exception) {
                AppUtils.showToast(context, R.string.wincore_profile_shared);
            }
        });
    }

'''
if "private void configureWinCoreV3Settings(" not in settings_source:
    anchor = "    private void loadGamepadModelSpinner(Spinner sGamepadModel) {\n"
    if settings_source.count(anchor) != 1:
        raise SystemExit("SettingsFragment V3 method insertion anchor was not unique.")
    settings_source = settings_source.replace(anchor, v3_methods + anchor, 1)
settings_path.write_text(settings_source, encoding="utf-8")


# Preserve WinCore's container-level device profile when the user duplicates a container.
container_manager_path = required("src/main/java/com/winlator/container/ContainerManager.java")
container_manager_source = container_manager_path.read_text(encoding="utf-8")
container_duplicate_anchor = "        dstContainer.setDesktopTheme(srcContainer.getDesktopTheme());\n"
if 'dstContainer.putExtra("wincore_cpu_profile"' not in container_manager_source:
    if container_manager_source.count(container_duplicate_anchor) != 1:
        raise SystemExit("Container duplicate profile copy anchor was not unique.")
    container_manager_source = container_manager_source.replace(
        container_duplicate_anchor,
        container_duplicate_anchor + '        dstContainer.putExtra("wincore_cpu_profile", srcContainer.getExtra("wincore_cpu_profile", null));\n',
        1
    )
container_manager_path.write_text(container_manager_source, encoding="utf-8")

print("WinCore 3.0.0 profile overrides, adaptive launch safety, export, UI controls, and live monitor patch applied.")
PY
