#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$REPO_ROOT/upstream"
APP_MODULE="$UPSTREAM_DIR/app/app"
OVERLAY="$REPO_ROOT/overlay"
BRANDING="$REPO_ROOT/assets/branding"
ICON="$BRANDING/wincore-app-icon.png"
VERSION="$(cat "$REPO_ROOT/VERSION")"

if [[ ! -f "$APP_MODULE/build.gradle" || ! -f "$APP_MODULE/src/main/AndroidManifest.xml" ]]; then
  echo "Winlator app source is missing. Clone WinCore with recursive submodules."
  exit 1
fi
if [[ "$VERSION" != "7.0.0" ]]; then
  echo "This patch is pinned to WinCore 7.0.0; VERSION contains $VERSION."
  exit 1
fi

mkdir -p "$APP_MODULE/src/main/java/com/winlator"
cp "$OVERLAY/src/main/java/com/winlator/WinCoreCompatibilityCenterActivity.java" "$APP_MODULE/src/main/java/com/winlator/"
cp "$OVERLAY/src/main/java/com/winlator/WinCoreSessionTracker.java" "$APP_MODULE/src/main/java/com/winlator/"
cp "$OVERLAY/src/main/java/com/winlator/WinCoreSevenActivity.java" "$APP_MODULE/src/main/java/com/winlator/"

mkdir -p "$APP_MODULE/src/main/java/com/winlator/contentdialog"
cp "$OVERLAY/src/main/java/com/winlator/contentdialog/AboutDialog.java" "$APP_MODULE/src/main/java/com/winlator/contentdialog/"
cp "$OVERLAY/src/main/res/layout/about_dialog.xml" "$APP_MODULE/src/main/res/layout/"
mkdir -p "$APP_MODULE/src/main/res/drawable"
cp "$OVERLAY/src/main/res/drawable/wincore_about_logo.xml" "$APP_MODULE/src/main/res/drawable/"

# Restore the previous WinCore launcher artwork. Keep it centered inside
# Android's launcher safe area instead of stretching a full-bleed image.
if [[ ! -s "$ICON" ]]; then
  echo "User-supplied WinCore launcher icon missing: $ICON"
  exit 1
fi
if ! identify -regard-warnings "$ICON" >/dev/null 2>&1; then
  echo "Launcher icon is not a valid readable image: $ICON"
  exit 1
fi
if [[ "$(identify -format '%wx%h' "$ICON")" != "512x512" ]]; then
  echo "Expected a 512x512 launcher icon; got $(identify -format '%wx%h' "$ICON")."
  exit 1
fi
if ! command -v convert >/dev/null 2>&1; then
  echo "ImageMagick is required to generate correctly sized launcher assets."
  exit 1
fi

declare -A ICON_SIZES=([mdpi]=48 [hdpi]=72 [xhdpi]=96 [xxhdpi]=144 [xxxhdpi]=192)
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  size="${ICON_SIZES[$density]}"
  dir="$APP_MODULE/src/main/res/mipmap-$density"
  mkdir -p "$dir"
  # Legacy and round icons get a modest inset; adaptive foreground gets
  # Android's conservative 66% safe-zone inset to prevent oversized artwork.
  for icon_name in ic_launcher.png ic_launcher_round.png; do
    convert "$ICON" -resize 72%x72% -gravity center -background none -extent "${size}x${size}" "$dir/$icon_name"
  done
  convert "$ICON" -resize 66%x66% -gravity center -background none -extent "${size}x${size}" "$dir/ic_launcher_foreground.png"
done

mkdir -p "$APP_MODULE/src/main/res/mipmap-anydpi-v26" \
         "$APP_MODULE/src/main/res/drawable-nodpi"
# Keep the launcher icon and the in-app About logo as separate assets.
# The user-supplied charcoal-background mark is represented by the dedicated
# wincore_about_logo vector drawable below; do not copy the launcher icon into
# generic logo.png resources or overwrite upstream logo files.

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
            <Button
                android:id="@+id/BTWinCore7Workspace"
                android:layout_width="match_parent"
                android:layout_height="wrap_content"
                android:layout_marginBottom="8dp"
                android:text="@string/wincore_7_workspace"
                android:textAllCaps="false" />
'''
replace_once(layout, anchor, anchor + button, "Settings Compatibility Center button")

strings_path = resource_root / "values/strings.xml"
strings = strings_path.read_text(encoding="utf-8")
if 'name="wincore_compatibility_center"' not in strings:
    marker = "</resources>"
    replace_once(strings_path, marker,
        '    <string name="wincore_compatibility_center">WinCore Compatibility Center 7.0.0</string>\n' + marker,
        "Compatibility Center string")
strings = strings_path.read_text(encoding="utf-8")
if 'name="wincore_7_workspace"' not in strings:
    marker = "</resources>"
    replace_once(strings_path, marker,
        '    <string name="wincore_7_workspace">WinCore 7.0.0 Workspace</string>\n' + marker,
        "WinCore 7.0.0 Workspace string")

# Register the new Activity in the app manifest.
manifest = app / "src/main/AndroidManifest.xml"
activity_anchor = '        <activity android:name="com.winlator.XServerDisplayActivity"'
activity_decl = '''        <activity
            android:name="com.winlator.WinCoreCompatibilityCenterActivity"
            android:theme="@style/AppThemeDark"
            android:exported="false"
            android:screenOrientation="sensor"
            android:configChanges="keyboard|keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize|density|navigation" />
        <activity
            android:name="com.winlator.WinCoreSevenActivity"
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
        view.findViewById(R.id.BTWinCore7Workspace).setOnClickListener(v ->
            startActivity(new Intent(context, WinCoreSevenActivity.class)));
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


# WinCore 7.0.0: use the user's exact image in the navigation drawer.
DRAWER_LOGO="$BRANDING/wincorebanner.png"
if [[ ! -s "$DRAWER_LOGO" ]]; then
  echo "Required navigation drawer banner missing: $DRAWER_LOGO"
  exit 1
fi
if ! identify -regard-warnings "$DRAWER_LOGO" >/dev/null 2>&1; then
  echo "Navigation drawer banner is not a valid readable image: $DRAWER_LOGO"
  exit 1
fi
# The upstream app also ships a density-specific HDPI copy. Android prefers
# that resource on HDPI devices, so replacing only drawable/logo.png leaves
# the original Winlator artwork visible in the navigation drawer.
mkdir -p "$APP_MODULE/src/main/res/drawable" "$APP_MODULE/src/main/res/drawable-hdpi"
cp "$DRAWER_LOGO" "$APP_MODULE/src/main/res/drawable/logo.png"
cp "$DRAWER_LOGO" "$APP_MODULE/src/main/res/drawable-hdpi/logo.png"
python3 - "$APP_MODULE" <<'PY'
from pathlib import Path
import sys
app = Path(sys.argv[1])
header = app / "src/main/res/layout/main_menu_header.xml"
source = header.read_text(encoding="utf-8")
if '@drawable/logo' not in source:
    raise SystemExit("Navigation drawer header no longer references @drawable/logo; review upstream layout.")
if 'android:scaleType="fitCenter"' not in source:
    source = source.replace('android:src="@drawable/logo"', 'android:src="@drawable/logo"\n        android:adjustViewBounds="true"\n        android:scaleType="fitCenter"')
header.write_text(source, encoding="utf-8")

manager = app / "src/main/java/com/winlator/container/ContainerManager.java"
s = manager.read_text(encoding="utf-8")
s = s.replace('import java.util.concurrent.Executors;', 'import java.util.concurrent.ExecutorService;\nimport java.util.concurrent.Executors;\nimport android.os.Looper;')
old = '''    private final ArrayList<Container> containers = new ArrayList<>();
    private int maxContainerId = 0;
    private final File homeDir;
    private final Context context;

    public ContainerManager(Context context) {
        this.context = context;
        File rootDir = RootFS.find(context).getRootDir();
        homeDir = new File(rootDir, "home");
        loadContainers();
    }'''
new = '''    private static final ExecutorService IO_EXECUTOR = Executors.newSingleThreadExecutor();
    private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());
    private final ArrayList<Container> containers = new ArrayList<>();
    private int maxContainerId = 0;
    private final File homeDir;
    private final Context context;

    public ContainerManager(Context context) {
        this(context, 0);
    }

    // selectedContainerId > 0 avoids parsing every container config while opening one container.
    public ContainerManager(Context context, int selectedContainerId) {
        this.context = context;
        File rootDir = RootFS.find(context).getRootDir();
        homeDir = new File(rootDir, "home");
        loadContainers(selectedContainerId);
    }'''
if old not in s: raise SystemExit("ContainerManager constructor anchor not found")
s = s.replace(old, new, 1)
start = s.index('    private void loadContainers() {')
end = s.index('    public void activateContainer(', start)
replacement = '''    private void loadContainers(int selectedContainerId) {
        containers.clear();
        maxContainerId = 0;
        File[] files = homeDir.listFiles();
        if (files == null) return;

        for (File file : files) {
            String prefix = RootFS.USER + "-";
            if (!file.isDirectory() || !file.getName().startsWith(prefix)) continue;
            final int id;
            try {
                id = Integer.parseInt(file.getName().substring(prefix.length()));
            }
            catch (NumberFormatException ignored) {
                continue;
            }
            if (id <= 0) continue;
            maxContainerId = Math.max(maxContainerId, id);
            if (selectedContainerId > 0 && id != selectedContainerId) continue;
            try {
                Container container = new Container(id);
                container.setRootDir(file);
                JSONObject data = new JSONObject(FileUtils.readString(container.getConfigFile()));
                container.loadData(data);
                containers.add(container);
            }
            catch (Exception error) {
                android.util.Log.w("WinCore", "Skipping unreadable container " + id, error);
            }
        }
    }

'''
s = s[:start] + replacement + s[end:];
s = s.replace('''        final Handler handler = new Handler();
        Executors.newSingleThreadExecutor().execute(() -> {
            final Container container = createContainer(data);
            handler.post(() -> callback.call(container));
        });''','''        IO_EXECUTOR.execute(() -> {
            Container container = null;
            try { container = createContainer(data); }
            catch (Exception error) { android.util.Log.e("WinCore", "Container creation failed", error); }
            final Container result = container;
            MAIN_HANDLER.post(() -> callback.call(result));
        });''',1);
s = s.replace('''        final Handler handler = new Handler();
        Executors.newSingleThreadExecutor().execute(() -> {
            duplicateContainer(container);
            handler.post(callback);
        });''','''        IO_EXECUTOR.execute(() -> {
            try { duplicateContainer(container); }
            catch (Exception error) { android.util.Log.e("WinCore", "Container duplication failed", error); }
            finally { MAIN_HANDLER.post(callback); }
        });''',1);
s = s.replace('''        final Handler handler = new Handler();
        Executors.newSingleThreadExecutor().execute(() -> {
            removeContainer(container);
            handler.post(callback);
        });''','''        IO_EXECUTOR.execute(() -> {
            try { removeContainer(container); }
            catch (Exception error) { android.util.Log.e("WinCore", "Container removal failed", error); }
            finally { MAIN_HANDLER.post(callback); }
        });''',1);
manager.write_text(s, encoding="utf-8");

detail = app / "src/main/java/com/winlator/ContainerDetailFragment.java"
d = detail.read_text(encoding="utf-8")
anchor = 'manager = new ContainerManager(context);'
if d.count(anchor) != 1: raise SystemExit("ContainerDetailFragment manager construction anchor changed")
d = d.replace(anchor, 'manager = new ContainerManager(context, containerId);', 1)
detail.write_text(d, encoding="utf-8")

# Defer cloning user.reg until a write is requested; detail-screen reads stay read-only.
registry = app / "src/main/java/com/winlator/core/WineRegistryEditor.java"
w = registry.read_text(encoding="utf-8")
w = w.replace("    private final File cloneFile;\n", "    private File cloneFile;\n    private boolean cloneCreated = false;\n")
old_ctor = '''    public WineRegistryEditor(File file) {
        this.file = file;
        cloneFile = FileUtils.createTempFile(file.getParentFile(), FileUtils.getBasename(file.getPath()));
        if (!file.isFile()) {
            try {
                cloneFile.createNewFile();
            }
            catch (IOException e) {}
        }
        else FileUtils.copy(file, cloneFile);
    }'''
new_ctor = '''    public WineRegistryEditor(File file) {
        this.file = file;
        this.cloneFile = file;
    }

    private boolean ensureClone() {
        if (cloneCreated) return true;
        File temp = FileUtils.createTempFile(file.getParentFile(), FileUtils.getBasename(file.getPath()));
        if (file.isFile()) {
            if (!FileUtils.copy(file, temp)) {
                temp.delete();
                return false;
            }
        }
        else {
            try {
                if (!temp.createNewFile() && !temp.isFile()) return false;
            }
            catch (IOException error) {
                temp.delete();
                return false;
            }
        }
        cloneFile = temp;
        cloneCreated = true;
        return true;
    }'''
if old_ctor not in w: raise SystemExit("WineRegistryEditor constructor anchor not found")
w = w.replace(old_ctor, new_ctor, 1)
w = w.replace('''        if (modified && cloneFile.exists()) {
            cloneFile.renameTo(file);
        }
        else cloneFile.delete();''','''        if (modified && cloneCreated && cloneFile.exists()) {
            if (!cloneFile.renameTo(file)) {
                android.util.Log.e("WineRegistryEditor", "Could not commit registry changes to " + file);
            }
        }
        else if (cloneCreated) cloneFile.delete();''',1)
w = w.replace('''    private Location createKey(String key) {
        Location location''','''    private Location createKey(String key) {
        if (!ensureClone()) return null;
        Location location''',1)
w = w.replace('''    private void setRawValue(String key, String name, String value) {
        Location keyLocation''','''    private void setRawValue(String key, String name, String value) {
        if (!ensureClone()) return;
        Location keyLocation''',1)
w = w.replace('''    private void setRawValues(String key, String[]... items) {
        Location keyLocation''','''    private void setRawValues(String key, String[]... items) {
        if (!ensureClone()) return;
        Location keyLocation''',1)
w = w.replace('''    private boolean removeRegion(Location location) {
        char[] buffer''','''    private boolean removeRegion(Location location) {
        if (!ensureClone()) return false;
        char[] buffer''',1)
registry.write_text(w, encoding="utf-8")

# Make all regular Winlator container configuration saves atomic.
container_file = app / "src/main/java/com/winlator/container/Container.java"
container_source = container_file.read_text(encoding="utf-8")
container_source = container_source.replace(
    "import com.winlator.box64.Box64Preset;",
    "import android.util.AtomicFile;\n\nimport com.winlator.box64.Box64Preset;"
)
container_source = container_source.replace(
    "import java.io.File;\n",
    "import java.io.File;\nimport java.io.FileOutputStream;\nimport java.io.IOException;\nimport java.nio.charset.StandardCharsets;\n"
)
old_write = "            FileUtils.writeString(getConfigFile(), data.toString());"
new_write = """            AtomicFile atomicFile = new AtomicFile(getConfigFile());
            FileOutputStream output = null;
            try {
                output = atomicFile.startWrite();
                output.write(data.toString().getBytes(StandardCharsets.UTF_8));
                atomicFile.finishWrite(output);
            }
            catch (IOException error) {
                if (output != null) atomicFile.failWrite(output);
                android.util.Log.e("WinCore", "Atomic container config save failed for " + id, error);
            }"""
if container_source.count(old_write) != 1:
    raise SystemExit("Container.saveData atomic-write anchor changed.")
container_source = container_source.replace(old_write, new_write, 1)
container_file.write_text(container_source, encoding="utf-8")

# Record game launches for the WinCore 7.0.0 recent-games list.
shortcuts = app / "src/main/java/com/winlator/ShortcutsFragment.java"
shortcut_source = shortcuts.read_text(encoding="utf-8")
shortcut_anchor = "        private void runFromShortcut(Shortcut shortcut) {"
if shortcut_source.count(shortcut_anchor) != 1:
    raise SystemExit("ShortcutsFragment launch tracking anchor changed.")
shortcut_source = shortcut_source.replace(
    shortcut_anchor,
    shortcut_anchor + "\n            WinCoreSevenActivity.recordGameLaunch(getContext(), shortcut);",
    1
)
shortcuts.write_text(shortcut_source, encoding="utf-8")
PY

cmp -s "$DRAWER_LOGO" "$APP_MODULE/src/main/res/drawable/logo.png"
cmp -s "$DRAWER_LOGO" "$APP_MODULE/src/main/res/drawable-hdpi/logo.png"
grep -q 'android:src="@drawable/logo"' "$APP_MODULE/src/main/res/layout/main_menu_header.xml"
grep -q 'new ContainerManager(context, containerId)' "$APP_MODULE/src/main/java/com/winlator/ContainerDetailFragment.java"
grep -q 'loadContainers(int selectedContainerId)' "$APP_MODULE/src/main/java/com/winlator/container/ContainerManager.java"
grep -q 'Skipping unreadable container' "$APP_MODULE/src/main/java/com/winlator/container/ContainerManager.java"

# Verify the exact branding and Activity files exist before Gradle starts.
test -s "$APP_MODULE/src/main/java/com/winlator/WinCoreCompatibilityCenterActivity.java"
test -s "$APP_MODULE/src/main/java/com/winlator/WinCoreSessionTracker.java"
test -s "$APP_MODULE/src/main/res/drawable/wincore_about_logo.xml"
test -s "$APP_MODULE/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
test -s "$APP_MODULE/src/main/res/mipmap-xxxhdpi/ic_launcher_round.png"
test -s "$APP_MODULE/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
test -s "$APP_MODULE/src/main/res/mipmap-anydpi-v26/ic_launcher.xml"
test -s "$APP_MODULE/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml"

# Verify the dedicated About-page graphic and text fixes without touching launcher resources.
ABOUT="$APP_MODULE/src/main/java/com/winlator/contentdialog/AboutDialog.java"
ABOUT_LAYOUT="$APP_MODULE/src/main/res/layout/about_dialog.xml"
COMPAT="$APP_MODULE/src/main/java/com/winlator/WinCoreCompatibilityCenterActivity.java"
test -s "$ABOUT"
test -s "$ABOUT_LAYOUT"
test -s "$APP_MODULE/src/main/res/drawable/wincore_about_logo.xml"
grep -q 'website.setVisibility(View.GONE)' "$ABOUT"
if grep -qi 'winlator.org' "$ABOUT"; then
  echo "The old Winlator website link is still present in AboutDialog."
  exit 1
fi
grep -q 'android:src="@drawable/wincore_about_logo"' "$ABOUT_LAYOUT"
if grep -q '@mipmap/ic_launcher' "$ABOUT_LAYOUT"; then
  echo "About dialog is incorrectly reusing the launcher icon."
  exit 1
fi
grep -q 'setTextColor(0xffffffff)' "$COMPAT"
grep -q 'setHintTextColor(0xffb8c0c8)' "$COMPAT"

# Verify all launcher density outputs are square and use the expected Android sizes.
declare -A EXPECTED_ICON_SIZES=([mdpi]=48 [hdpi]=72 [xhdpi]=96 [xxhdpi]=144 [xxxhdpi]=192)
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  expected="${EXPECTED_ICON_SIZES[$density]}x${EXPECTED_ICON_SIZES[$density]}"
  for icon_name in ic_launcher.png ic_launcher_round.png ic_launcher_foreground.png; do
    actual="$(identify -format '%wx%h' "$APP_MODULE/src/main/res/mipmap-$density/$icon_name")"
    [[ "$actual" == "$expected" ]] || { echo "Bad launcher size: $density/$icon_name is $actual"; exit 1; }
  done
done
# Launcher resources are density-specific and padded; the About and drawer
# logos remain independent assets.
