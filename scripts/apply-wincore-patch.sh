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

app = Path(sys.argv[1])
version = sys.argv[2]

if not re.fullmatch(r"\d+\.\d+\.\d+", version):
    raise SystemExit(f"Invalid semantic version: {version}")

major, minor, patch = (int(part) for part in version.split("."))
version_code = major * 10000 + minor * 100 + patch
if version_code < 1:
    raise SystemExit("The Android version code must be positive.")

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

        return "WinCore 0.4.0 compatibility report\\n" +
            "Device: " + Build.MANUFACTURER + " " + Build.MODEL + "\\n" +
            "Android: " + Build.VERSION.RELEASE + " (API " + Build.VERSION.SDK_INT + ")\\n" +
            "SoC / hardware: " + socModel + "\\n" +
            "App process: " + processBitness + "\\n" +
            "CPU cores: " + Runtime.getRuntime().availableProcessors() + "\\n" +
            "Supported ABIs: " + supportedAbis + "\\n" +
            "RAM: " + totalMemory + " total, " + availableMemory + " available\\n" +
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

    private String formatWinCoreMemory(long bytes) {
        return String.format(java.util.Locale.US, "%.1f GB",
            bytes / (1024.0 * 1024.0 * 1024.0));
    }

"""
if "private void configureWinCoreDiagnostics(" not in java_source:
    anchor = "    private void loadGamepadModelSpinner(Spinner sGamepadModel) {\n"
    if java_source.count(anchor) != 1:
        raise SystemExit(f"Could not find the diagnostics method insertion point in {java_path}.")
    java_source = java_source.replace(anchor, diagnostics_methods + anchor, 1)
java_path.write_text(java_source, encoding="utf-8")

print(
    f"WinCore {version} patch applied: app ID, version, provider authority, "
    f"branding, and local device diagnostics ({updated_locales} locale files)."
)
PY
