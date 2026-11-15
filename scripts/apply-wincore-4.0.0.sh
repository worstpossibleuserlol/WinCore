#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$REPO_ROOT/upstream"
APP_MODULE="$UPSTREAM_DIR/app/app"
OVERLAY="$REPO_ROOT/overlay"
BRANDING="$REPO_ROOT/assets/branding"
VERSION="$(cat "$REPO_ROOT/VERSION")"

if [[ ! -f "$APP_MODULE/build.gradle" || ! -f "$APP_MODULE/src/main/AndroidManifest.xml" ]]; then
  echo "Winlator app source is missing. Clone WinCore with recursive submodules."
  exit 1
fi
if [[ "$VERSION" != "4.0.0" ]]; then
  echo "This patch is pinned to WinCore 4.0.0; VERSION contains $VERSION."
  exit 1
fi

mkdir -p "$APP_MODULE/src/main/java/com/winlator"
cp "$OVERLAY/src/main/java/com/winlator/WinCoreCompatibilityCenterActivity.java" "$APP_MODULE/src/main/java/com/winlator/"
cp "$OVERLAY/src/main/java/com/winlator/WinCoreSessionTracker.java" "$APP_MODULE/src/main/java/com/winlator/"

# Unpack the exact supplied artwork prepared for Android launcher resources.
mkdir -p "$BRANDING/generated"
unzip -oq "$BRANDING/wincore-branding.zip" -d "$BRANDING/generated"
BRANDING="$BRANDING/generated"

# Keep a high-resolution legacy icon and a proper transparent adaptive foreground.
# Android scales the xxxhdpi resources for lower-density pre-adaptive launchers.
mkdir -p "$APP_MODULE/src/main/res/mipmap-xxxhdpi" \
         "$APP_MODULE/src/main/res/mipmap-anydpi-v26" \
         "$APP_MODULE/src/main/res/drawable-nodpi" \
         "$APP_MODULE/src/main/res/drawable-hdpi"
cp "$BRANDING/ic_launcher.png" "$APP_MODULE/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
cp "$BRANDING/ic_launcher.png" "$APP_MODULE/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png"
cp "$BRANDING/ic_launcher_foreground.png" "$APP_MODULE/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
cp "$BRANDING/wincore_logo.png" "$APP_MODULE/src/main/res/drawable-nodpi/wincore_logo.png"
cp "$BRANDING/logo.png" "$APP_MODULE/src/main/res/drawable-hdpi/logo.png"

cat > "$APP_MODULE/src/main/res/values/wincore_icon_colors.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="wincore_icon_background">#FFFFFF</color>
</resources>
XML

for icon in ic_launcher.xml ic_launcher_round.xml; do
  cat > "$APP_MODULE/src/main/res/mipmap-anydpi-v26/$icon" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/wincore_icon_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
XML
done

python3 - "$APP_MODULE" "$VERSION" <<'PY'
from pathlib import Path
import re
import sys

app = Path(sys.argv[1])
version = sys.argv[2]

def replace_once(path: Path, anchor: str, replacement: str, description: str) -> None:
    source = path.read_text(encoding="utf-8")
    count = source.count(anchor)
    if count != 1:
        raise SystemExit(f"{description}: expected one anchor, found {count} in {path}")
    path.write_text(source.replace(anchor, replacement, 1), encoding="utf-8")

# Keep every translated app-name resource branded consistently.
resource_root = app / "src/main/res"
locale_count = 0
for strings_file in resource_root.glob("values*/strings.xml"):
    source = strings_file.read_text(encoding="utf-8")
    updated, count = re.subn(
        r'(<string\s+name="app_name"[^>]*>)(?:Winlator|WinCore)(</string>)',
        r"\1WinCore\2", source, count=1
    )
    if count:
        strings_file.write_text(updated, encoding="utf-8")
        locale_count += 1
if locale_count == 0:
    raise SystemExit("No app_name string resource was found.")

# Add a direct entry to the Compatibility Center without changing the existing settings controls.
layout = resource_root / "layout/settings_fragment.xml"
anchor = '            android:padding="16dp">'
button = '''
            <Button
                android:id="@+id/BTWinCoreCompatibilityCenter"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginBottom="8dp"
                android:text="@string/wincore_compatibility_center"
                android:textAllCaps="false" />
'''
replace_once(layout, anchor, anchor + button, "Settings Compatibility Center button")

strings_path = resource_root / "values/strings.xml"
strings = strings_path.read_text(encoding="utf-8")
if 'name="wincore_compatibility_center"' not in strings:
    marker = "</resources>"
    replace_once(strings_path, marker,
        '    <string name="wincore_compatibility_center">WinCore Compatibility Center 4.0.0</string>\n' + marker,
        "Compatibility Center string")

# Register the new Activity in the app manifest.
manifest = app / "src/main/AndroidManifest.xml"
activity_anchor = '        <activity android:name="com.winlator.XServerDisplayActivity"'
activity_decl = '''        <activity
            android:name="com.winlator.WinCoreCompatibilityCenterActivity"
            android:theme="@style/AppThemeDark"
            android:exported="false"
            android:screenOrientation="sensor"
            android:configChanges="keyboard|keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize|density|navigation" />

'''
replace_once(manifest, activity_anchor, activity_decl + activity_anchor, "Compatibility Center Activity registration")

replace_once(manifest, 'android:icon="@mipmap/ic_launcher"',
    'android:icon="@mipmap/ic_launcher"' + chr(10) + '        android:roundIcon="@mipmap/ic_launcher_round"',
    "round launcher icon attribute")

# Wire the settings entry point to the new Activity.
settings = app / "src/main/java/com/winlator/SettingsFragment.java"
settings_anchor = '        preferences = PreferenceManager.getDefaultSharedPreferences(context);'
settings_addition = '''
        view.findViewById(R.id.BTWinCoreCompatibilityCenter).setOnClickListener(v ->
            startActivity(new Intent(context, WinCoreCompatibilityCenterActivity.class)));
'''
replace_once(settings, settings_anchor, settings_anchor + settings_addition, "SettingsFragment Compatibility Center click listener")

# Record the actual XServer session lifecycle for launch history and session summaries.
xserver = app / "src/main/java/com/winlator/XServerDisplayActivity.java"
start_anchor = "        ForegroundService.startSession(this);"
replace_once(xserver, start_anchor,
    start_anchor + "\n        WinCoreSessionTracker.onSessionStart(this);",
    "XServer session start tracking")
end_anchor = """    @Override
    protected void onDestroy() {
        winHandler.stop();
        if (environment != null) environment.stopEnvironmentComponents();
        ForegroundService.stopSession(this);
        super.onDestroy();
    }"""
replace_once(xserver, end_anchor,
    """    @Override
    protected void onDestroy() {
        winHandler.stop();
        if (environment != null) environment.stopEnvironmentComponents();
        WinCoreSessionTracker.onSessionEnd(this);
        ForegroundService.stopSession(this);
        super.onDestroy();
    }""",
    "XServer onDestroy session tracking")

print(f"WinCore {version}: Compatibility Center, session tracking, and green branding applied ({locale_count} app-name locales).")
PY

# Verify the exact branding and Activity files exist before Gradle starts.
test -s "$APP_MODULE/src/main/java/com/winlator/WinCoreCompatibilityCenterActivity.java"
test -s "$APP_MODULE/src/main/java/com/winlator/WinCoreSessionTracker.java"
test -s "$APP_MODULE/src/main/res/drawable-nodpi/wincore_logo.png"
test -s "$APP_MODULE/src/main/res/drawable-hdpi/logo.png"
test -s "$APP_MODULE/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
test -s "$APP_MODULE/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png"
test -s "$APP_MODULE/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
test -s "$APP_MODULE/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
test -s "$APP_MODULE/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml"
