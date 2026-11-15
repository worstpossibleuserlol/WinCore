#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_DIR="$REPO_ROOT/upstream"
APP_MODULE="$UPSTREAM_DIR/app/app"
OVERLAY="$REPO_ROOT/overlay"
BRANDING="$REPO_ROOT/assets/branding"
ICON="$BRANDING/wincore-user-icon.png"
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

mkdir -p "$APP_MODULE/src/main/java/com/winlator/contentdialog"
cp "$OVERLAY/src/main/java/com/winlator/contentdialog/AboutDialog.java" "$APP_MODULE/src/main/java/com/winlator/contentdialog/"
cp "$OVERLAY/src/main/res/layout/about_dialog.xml" "$APP_MODULE/src/main/res/layout/"
mkdir -p "$APP_MODULE/src/main/res/drawable"
cp "$OVERLAY/src/main/res/drawable/wincore_about_logo.xml" "$APP_MODULE/src/main/res/drawable/"

# Use the exact user-supplied WinCore icon/logo file, not a generated substitute.
if [[ ! -s "$ICON" ]]; then
  echo "Required user-supplied logo missing: $ICON"
  exit 1
fi

for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  mkdir -p "$APP_MODULE/src/main/res/mipmap-$density"
  for icon_name in ic_launcher.png ic_launcher_round.png ic_launcher_foreground.png; do
    cp "$ICON" "$APP_MODULE/src/main/res/mipmap-$density/$icon_name"
  done
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
'''
replace_once(layout, anchor, anchor + button, "Settings Compatibility Center button")

strings_path = resource_root / "values/strings.xml"
strings = strings_path.read_text(encoding="utf-8")
if 'name="wincore_compatibility_center"' not in strings:
    marker = "</resources>"
    replace_once(strings_path, marker,
        '    <string name="wincore_compatibility_center">WinCore Compatibility Center 7.0.0</string>\n' + marker,
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


# WinCore 7.0.0: use the user's exact image in the navigation drawer.
DRAWER_LOGO="$BRANDING/WinCore To Replace WinLator Logo.png"
if [[ ! -s "$DRAWER_LOGO" ]]; then
  echo "Required navigation drawer logo missing: $DRAWER_LOGO"
  exit 1
fi
cp "$DRAWER_LOGO" "$APP_MODULE/src/main/res/drawable/logo.png"
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
PY

cmp -s "$DRAWER_LOGO" "$APP_MODULE/src/main/res/drawable/logo.png"
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

# Verify every launcher density and visible logo is byte-for-byte identical to the supplied asset.
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  for icon_name in ic_launcher.png ic_launcher_round.png ic_launcher_foreground.png; do
    cmp -s "$ICON" "$APP_MODULE/src/main/res/mipmap-$density/$icon_name"
  done
done
# Launcher icon checks are intentionally limited to mipmap resources.
# The About dialog uses its own charcoal-background WinCore logo drawable.
