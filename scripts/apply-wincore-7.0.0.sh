#!/usr/bin/env bash
set -euo pipefail
set -x

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
python3 - "$ICON" "$APP_MODULE" <<'PY'
from pathlib import Path
import sys
from PIL import Image, ImageChops

source = Path(sys.argv[1])
app = Path(sys.argv[2])
try:
    image = Image.open(source)
    image.load()
    image = image.convert("RGBA")
except Exception as error:
    raise SystemExit(f"Cannot decode supplied WinCore launcher PNG: {error}")

if image.width != image.height:
    raise SystemExit(f"Launcher icon must be square; got {image.width}x{image.height}")

# Trim only the blank white canvas around the supplied mark. The actual logo,
# its green facets, and its white interior remain untouched.
difference = ImageChops.difference(
    image.convert("RGB"),
    Image.new("RGB", image.size, (255, 255, 255))
).convert("L")
mask = difference.point(lambda value: 255 if value > 24 else 0)
bounds = mask.getbbox()
if bounds:
    artwork = image.crop(bounds)
    side = max(artwork.width, artwork.height)
    padding = max(1, round(side * 0.02))
    square = Image.new("RGBA", (side + padding * 2, side + padding * 2), (255, 255, 255, 255))
    offset = ((square.width - artwork.width) // 2, (square.height - artwork.height) // 2)
    square.alpha_composite(artwork, offset)
    image = square

# Re-encode once to remove malformed/unsupported ancillary metadata, then
# render density assets with Pillow rather than ImageMagick.
sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for density, size in sizes.items():
    directory = app / "src/main/res" / f"mipmap-{density}"
    directory.mkdir(parents=True, exist_ok=True)
    for name, scale in (("ic_launcher.png", 0.72), ("ic_launcher_round.png", 0.72),
                        ("ic_launcher_foreground.png", 0.66)):
        artwork_size = max(1, round(size * scale))
        artwork = image.resize((artwork_size, artwork_size), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        offset = ((size - artwork_size) // 2, (size - artwork_size) // 2)
        canvas.alpha_composite(artwork, offset)
        canvas.save(directory / name, format="PNG", optimize=True)
print(f"Generated WinCore launcher assets from {source} ({image.width}x{image.height}).")
PY

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

# Track explicit user exits and whether the first guest window ever appeared.
replace_once(
    xserver,
    "    private String screenEffectProfile;\n",
    "    private String screenEffectProfile;\n    private boolean wincoreIntentionalExit = false;\n    private boolean wincoreFirstWindowShown = false;\n",
    "XServer guest-exit diagnostics fields"
)
replace_once(
    xserver,
    "    private void exit() {\n        winHandler.stop();",
    "    private void exit() {\n        wincoreIntentionalExit = true;\n        winHandler.stop();",
    "XServer intentional exit tracking"
)
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


# WinCore 7.0.0: wait for RootFS installation before loading containers,
# and perform container directory/config scans away from the UI thread.
python3 - "$APP_MODULE" <<'PY'
from pathlib import Path
import sys

app = Path(sys.argv[1])

def replace_once(path: Path, old: str, new: str, label: str) -> None:
    source = path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one anchor, found {count} in {path}")
    path.write_text(source.replace(old, new, 1), encoding="utf-8")

# RootFS installation is asynchronous. Keep a completion callback and notify
# the visible container screen only after the installer has finished.
main_activity = app / "src/main/java/com/winlator/MainActivity.java"
main = main_activity.read_text(encoding="utf-8")
if main.count("RootFSInstaller.installIfNeeded(this);") != 2:
    raise SystemExit("MainActivity: expected installIfNeeded calls in startup and permission callback.")
main = main.replace(
    "RootFSInstaller.installIfNeeded(this);",
    "RootFSInstaller.installIfNeeded(this, this::onRootFSReady);"
)
method_anchor = "    private boolean requestAppPermissions() {"
method = """    private void onRootFSReady() {
        if (currentFragment instanceof ContainersFragment) {
            ((ContainersFragment)currentFragment).reloadContainers();
        }
    }

"""
if main.count(method_anchor) != 1 or "private void onRootFSReady()" in main:
    raise SystemExit("MainActivity: RootFS completion callback insertion point changed.")
main = main.replace(method_anchor, method + method_anchor, 1)
main_activity.write_text(main, encoding="utf-8")

# Extend the installer without breaking existing callers. The completion
# callback always runs after the extraction attempt so the screen can show
# either loaded containers or a clear not-ready/error state.
installer = app / "src/main/java/com/winlator/xenvironment/RootFSInstaller.java"
installer_source = installer.read_text(encoding="utf-8")
old_install = """    public static void install(final MainActivity activity) {
        AppUtils.keepScreenOn(activity);"""
new_install = """    public static void install(final MainActivity activity) {
        install(activity, null);
    }

    private static void install(final MainActivity activity, final Runnable onComplete) {
        AppUtils.keepScreenOn(activity);"""
if installer_source.count(old_install) != 1:
    raise SystemExit("RootFSInstaller: install method anchor changed.")
installer_source = installer_source.replace(old_install, new_install, 1)
worker_anchor = """        Executors.newSingleThreadExecutor().execute(() -> {
            clearRootDir(rootDir);"""
worker_replacement = """        Executors.newSingleThreadExecutor().execute(() -> {
            try {
                clearRootDir(rootDir);"""
if installer_source.count(worker_anchor) != 1:
    raise SystemExit("RootFSInstaller worker anchor changed.")
installer_source = installer_source.replace(worker_anchor, worker_replacement, 1)

old_complete = """            dialog.closeOnUiThread();
        });
    }

    public static void installIfNeeded(final MainActivity activity) {
        RootFS rootFS = RootFS.find(activity);
        if (!rootFS.isValid() || rootFS.getVersion() < LATEST_VERSION) install(activity);
    }"""
new_complete = """            }
            catch (Exception error) {
                android.util.Log.e("WinCore", "RootFS installation failed", error);
                AppUtils.showToast(activity, R.string.unable_to_install_system_files);
            }
            finally {
                dialog.closeOnUiThread();
                if (onComplete != null) activity.runOnUiThread(onComplete);
            }
        });
    }

    public static void installIfNeeded(final MainActivity activity) {
        installIfNeeded(activity, null);
    }

    public static void installIfNeeded(final MainActivity activity, final Runnable onComplete) {
        RootFS rootFS = RootFS.find(activity);
        int version;
        try { version = rootFS.getVersion(); }
        catch (Exception error) { version = 0; }
        if (!rootFS.isValid() || version < LATEST_VERSION) {
            install(activity, onComplete);
        }
        else if (onComplete != null) {
            activity.runOnUiThread(onComplete);
        }
    }"""
if installer_source.count(old_complete) != 1:
    raise SystemExit("RootFSInstaller: install completion / installIfNeeded block changed.")
installer_source = installer_source.replace(old_complete, new_complete, 1)
installer.write_text(installer_source, encoding="utf-8")

# Treat a malformed RootFS version marker as an outdated installation instead
# of allowing NumberFormatException to abort startup/container discovery.
rootfs_file = app / "src/main/java/com/winlator/xenvironment/RootFS.java"
rootfs_source = rootfs_file.read_text(encoding="utf-8")
old_version = """        return rfsVersionFile.exists() ? Integer.parseInt(FileUtils.readLines(rfsVersionFile).get(0)) : 0;"""
new_version = """        if (!rfsVersionFile.exists()) return 0;
        try {
            java.util.List<String> lines = FileUtils.readLines(rfsVersionFile);
            return lines.isEmpty() ? 0 : Integer.parseInt(lines.get(0).trim());
        }
        catch (Exception error) {
            android.util.Log.e("WinCore", "Invalid RootFS version marker; reinstall required", error);
            return 0;
        }"""
if rootfs_source.count(old_version) != 1:
    raise SystemExit("RootFS.getVersion anchor changed.")
rootfs_file.write_text(rootfs_source.replace(old_version, new_version, 1), encoding="utf-8")

# Make the list show explicit setup/loading/failure states. ContainerManager's
# filesystem scan and JSON parsing execute on a shared worker, not on the UI.
# Prevent container launch from leaving the "Starting up..." preloader forever
# when Wine preparation or XEnvironment startup throws.
display = app / "src/main/java/com/winlator/XServerDisplayActivity.java"
display_source = display.read_text(encoding="utf-8")
display_source = display_source.replace(
    "import android.widget.Spinner;\n",
    "import android.widget.Spinner;\nimport android.widget.Toast;\n",
    1
)
old_startup = """        Executors.newSingleThreadExecutor().execute(() -> {
            if (!isGenerateWineprefix()) {
                setupWineSystemFiles();
                extractGraphicsDriverFiles();
                changeWineAudioDriver();
            }
            setupXEnvironment();
        });"""
new_startup = """        Executors.newSingleThreadExecutor().execute(() -> {
            try {
                if (!isGenerateWineprefix()) {
                    setupWineSystemFiles();
                    extractGraphicsDriverFiles();
                    changeWineAudioDriver();
                }
                setupXEnvironment();
            }
            catch (Exception error) {
                android.util.Log.e("WinCore", "Container startup failed", error);
                runOnUiThread(() -> {
                    preloaderDialog.close();
                    StringBuilder detail = new StringBuilder("WinCore could not start the selected container.");
                    Throwable cause = error;
                    int depth = 0;
                    while (cause != null && depth < 6) {
                        detail.append(depth == 0 ? "\\n\\n" : "\\nCaused by: ");
                        detail.append(cause.getClass().getSimpleName());
                        String message = cause.getMessage();
                        if (message != null && !message.trim().isEmpty()) {
                            detail.append(": ").append(message.trim());
                        }
                        cause = cause.getCause();
                        depth++;
                    }
                    final String report = detail.toString();
                    new android.app.AlertDialog.Builder(this)
                        .setTitle("Container failed to start")
                        .setMessage(report)
                        .setPositiveButton("Return to WinCore", (dialog, which) -> finish())
                        .setNeutralButton("Copy details", (dialog, which) -> {
                            android.content.ClipboardManager clipboard =
                                (android.content.ClipboardManager)getSystemService(CLIPBOARD_SERVICE);
                            if (clipboard != null) {
                                clipboard.setPrimaryClip(
                                    android.content.ClipData.newPlainText("WinCore startup error", report)
                                );
                                Toast.makeText(this, "Startup details copied", Toast.LENGTH_SHORT).show();
                            }
                        })
                        .setCancelable(false)
                        .show();
                });
            }
        });"""
if display_source.count(old_startup) == 1:
    display_source = display_source.replace(old_startup, new_startup, 1)
elif "Container startup failed" in display_source:
    print("XServerDisplayActivity startup diagnostics already present; skipping duplicate patch.")
elif "setupXEnvironment();" in display_source and "Executors.newSingleThreadExecutor().execute" in display_source:
    # Upstream may reformat the worker between pinned revisions. Do not abort
    # the entire APK build over a diagnostic-only wrapper; preserve launch code.
    print("XServerDisplayActivity startup worker formatting changed; preserving upstream worker.")
else:
    raise SystemExit("XServerDisplayActivity startup worker is missing; cannot safely patch startup diagnostics.")
display.write_text(display_source, encoding="utf-8")

containers = app / "src/main/java/com/winlator/ContainersFragment.java"
source = containers.read_text(encoding="utf-8")
source = source.replace(
    "import android.os.Build;\n",
    "import android.os.Build;\nimport android.os.Handler;\nimport android.os.Looper;\n",
    1
)
source = source.replace(
    "import com.winlator.xenvironment.RootFS;\n",
    "import com.winlator.xenvironment.RootFS;\nimport com.winlator.xenvironment.RootFSInstaller;\n",
    1
)
source = source.replace(
    "import java.util.List;\n",
    "import java.util.List;\nimport java.util.concurrent.ExecutorService;\nimport java.util.concurrent.Executors;\n",
    1
)
fields_anchor = """public class ContainersFragment extends Fragment {
    private RecyclerView recyclerView;"""
fields_replacement = """public class ContainersFragment extends Fragment {
    private static final ExecutorService CONTAINER_LOAD_EXECUTOR = Executors.newSingleThreadExecutor();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private int loadGeneration = 0;
    private RecyclerView recyclerView;"""
if source.count(fields_anchor) != 1:
    raise SystemExit("ContainersFragment: class fields insertion point changed.")
source = source.replace(fields_anchor, fields_replacement, 1)

old_on_view = """        manager = new ContainerManager(getContext());
        loadContainersList();"""
if source.count(old_on_view) != 1:
    raise SystemExit("ContainersFragment: initial manager construction anchor changed.")
source = source.replace(old_on_view, "        loadContainersList();", 1)

old_loader = """    private void loadContainersList() {
        ArrayList<Container> containers = manager.getContainers();
        recyclerView.setAdapter(new ContainersAdapter(containers));
        if (containers.isEmpty()) emptyTextView.setVisibility(View.VISIBLE);
    }"""
new_loader = """    public void reloadContainers() {
        loadContainersList();
    }

    private void loadContainersList() {
        if (recyclerView == null || emptyTextView == null) return;
        final Context context = getContext();
        if (context == null) return;
        final int generation = ++loadGeneration;
        final Context appContext = context.getApplicationContext() != null ? context.getApplicationContext() : context;

        boolean rootFSReady = false;
        try {
            RootFS rootFS = RootFS.find(appContext);
            rootFSReady = rootFS.isValid() && rootFS.getVersion() >= RootFSInstaller.LATEST_VERSION;
        }
        catch (Exception ignored) { }

        if (!rootFSReady) {
            manager = null;
            recyclerView.setAdapter(null);
            emptyTextView.setText("System files are not ready. Tap here to retry installation and load containers.");
            emptyTextView.setVisibility(View.VISIBLE);
            emptyTextView.setOnClickListener(v -> {
                MainActivity activity = (MainActivity)getActivity();
                if (activity != null) {
                    emptyTextView.setText("Installing system files…");
                    RootFSInstaller.installIfNeeded(activity, this::reloadContainers);
                }
            });
            return;
        }

        emptyTextView.setText("Loading containers…");
        emptyTextView.setVisibility(View.VISIBLE);
        CONTAINER_LOAD_EXECUTOR.execute(() -> {
            try {
                final ContainerManager loadedManager = new ContainerManager(appContext);
                final ArrayList<Container> loadedContainers = new ArrayList<>(loadedManager.getContainers());
                mainHandler.post(() -> {
                    if (!isAdded() || generation != loadGeneration || recyclerView == null || emptyTextView == null) return;
                    manager = loadedManager;
                    recyclerView.setAdapter(new ContainersAdapter(loadedContainers));
                    emptyTextView.setOnClickListener(null);
                    if (loadedContainers.isEmpty()) {
                        emptyTextView.setText("No containers found. Check that your container data exists under the WinCore system files.");
                        emptyTextView.setVisibility(View.VISIBLE);
                    }
                    else {
                        emptyTextView.setText("");
                        emptyTextView.setVisibility(View.GONE);
                    }
                });
            }
            catch (Exception error) {
                final String detail = error.getMessage() != null ? error.getMessage() : error.getClass().getSimpleName();
                mainHandler.post(() -> {
                    if (!isAdded() || generation != loadGeneration || recyclerView == null || emptyTextView == null) return;
                    manager = null;
                    recyclerView.setAdapter(null);
                    emptyTextView.setText("Unable to load containers: " + detail + ". Use refresh or reopen the screen after checking system files.");
                    emptyTextView.setVisibility(View.VISIBLE);
                });
            }
        });
    }

    @Override
    public void onDestroyView() {
        loadGeneration++;
        recyclerView = null;
        emptyTextView = null;
        manager = null;
        super.onDestroyView();
    }"""
if source.count(old_loader) != 1:
    raise SystemExit("ContainersFragment: loadContainersList method anchor changed.")
source = source.replace(old_loader, new_loader, 1)
containers.write_text(source, encoding="utf-8")
PY

# Verify the RootFS readiness callback and background container loading patch.
grep -q 'RootFSInstaller.installIfNeeded(this, this::onRootFSReady)' "$APP_MODULE/src/main/java/com/winlator/MainActivity.java"
grep -q 'private void onRootFSReady()' "$APP_MODULE/src/main/java/com/winlator/MainActivity.java"
grep -q 'installIfNeeded(final MainActivity activity, final Runnable onComplete)' "$APP_MODULE/src/main/java/com/winlator/xenvironment/RootFSInstaller.java"
grep -q 'public void reloadContainers()' "$APP_MODULE/src/main/java/com/winlator/ContainersFragment.java"
grep -q 'CONTAINER_LOAD_EXECUTOR.execute' "$APP_MODULE/src/main/java/com/winlator/ContainersFragment.java"
grep -q 'RootFSInstaller.LATEST_VERSION' "$APP_MODULE/src/main/java/com/winlator/ContainersFragment.java"



# Container scan diagnostics and reliable refresh behavior.
python3 - "$APP_MODULE" <<'PY'
from pathlib import Path
import sys

app = Path(sys.argv[1])

manager = app / "src/main/java/com/winlator/container/ContainerManager.java"
m = manager.read_text(encoding="utf-8")

field_anchor = "    private final File homeDir;\n"
if m.count(field_anchor) != 1:
    raise SystemExit("ContainerManager diagnostics field anchor changed.")
m = m.replace(field_anchor, field_anchor + "    private final ArrayList<String> loadWarnings = new ArrayList<>();\n", 1)

method_anchor = """    public ArrayList<Container> getContainers() {
        return containers;
    }
"""
method = """    public ArrayList<String> getLoadWarnings() {
        return new ArrayList<>(loadWarnings);
    }

"""
if m.count(method_anchor) != 1:
    raise SystemExit("ContainerManager warning getter anchor changed.")
m = m.replace(method_anchor, method_anchor + "\n" + method, 1)

old_scan = """        containers.clear();
        maxContainerId = 0;
        File[] files = homeDir.listFiles();
        if (files == null) return;
"""
new_scan = """        containers.clear();
        loadWarnings.clear();
        maxContainerId = 0;
        if (!homeDir.exists()) {
            throw new IllegalStateException("Container directory is missing: " + homeDir.getAbsolutePath());
        }
        if (!homeDir.isDirectory()) {
            throw new IllegalStateException("Container path is not a directory: " + homeDir.getAbsolutePath());
        }
        if (!homeDir.canRead()) {
            throw new IllegalStateException("Container directory is not readable: " + homeDir.getAbsolutePath());
        }
        File[] files = homeDir.listFiles();
        if (files == null) {
            throw new IllegalStateException("Android could not list container directory: " + homeDir.getAbsolutePath());
        }
"""
if m.count(old_scan) != 1:
    raise SystemExit("ContainerManager scan null-list anchor changed.")
m = m.replace(old_scan, new_scan, 1)

old_skip = """            catch (Exception error) {
                android.util.Log.w("WinCore", "Skipping unreadable container " + id, error);
            }"""
new_skip = """            catch (Exception error) {
                String reason = error.getMessage() != null ? error.getMessage() : error.getClass().getSimpleName();
                loadWarnings.add("Container " + id + " (" + file.getName() + "): " + reason);
                android.util.Log.w("WinCore", "Skipping unreadable container " + id, error);
            }"""
if m.count(old_skip) != 1:
    raise SystemExit("ContainerManager unreadable-container warning anchor changed.")
m = m.replace(old_skip, new_skip, 1)
manager.write_text(m, encoding="utf-8")

containers = app / "src/main/java/com/winlator/ContainersFragment.java"
c = containers.read_text(encoding="utf-8")

old_success = """                    manager = loadedManager;
                    recyclerView.setAdapter(new ContainersAdapter(loadedContainers));
                    emptyTextView.setOnClickListener(null);
                    if (loadedContainers.isEmpty()) {
                        emptyTextView.setText("No containers found. Check that your container data exists under the WinCore system files.");
                        emptyTextView.setVisibility(View.VISIBLE);
                    }
                    else {
                        emptyTextView.setText("");
                        emptyTextView.setVisibility(View.GONE);
                    }"""
new_success = """                    manager = loadedManager;
                    recyclerView.setAdapter(new ContainersAdapter(loadedContainers));
                    ArrayList<String> warnings = loadedManager.getLoadWarnings();
                    if (loadedContainers.isEmpty() || !warnings.isEmpty()) {
                        StringBuilder status = new StringBuilder();
                        if (loadedContainers.isEmpty()) {
                            status.append("No readable containers found. ");
                        }
                        else {
                            status.append("Loaded ").append(loadedContainers.size()).append(" container(s). ");
                        }
                        if (!warnings.isEmpty()) {
                            status.append("Skipped ").append(warnings.size()).append(" unreadable container(s): ");
                            int limit = Math.min(warnings.size(), 3);
                            for (int index = 0; index < limit; index++) {
                                if (index > 0) status.append(" | ");
                                status.append(warnings.get(index));
                            }
                            if (warnings.size() > limit) {
                                status.append(" | and ").append(warnings.size() - limit).append(" more");
                            }
                            status.append(". ");
                        }
                        status.append("Tap here to scan again.");
                        emptyTextView.setText(status.toString());
                        emptyTextView.setVisibility(View.VISIBLE);
                        emptyTextView.setOnClickListener(v -> loadContainersList());
                    }
                    else {
                        emptyTextView.setText("");
                        emptyTextView.setOnClickListener(null);
                        emptyTextView.setVisibility(View.GONE);
                    }"""
if c.count(old_success) != 1:
    raise SystemExit("ContainersFragment successful-load status anchor changed.")
c = c.replace(old_success, new_success, 1)

old_error = """                    manager = null;
                    recyclerView.setAdapter(null);
                    emptyTextView.setText("Unable to load containers: " + detail + ". Use refresh or reopen the screen after checking system files.");
                    emptyTextView.setVisibility(View.VISIBLE);"""
new_error = """                    manager = null;
                    recyclerView.setAdapter(null);
                    emptyTextView.setText("Unable to load containers: " + detail + ". Tap here to retry.");
                    emptyTextView.setVisibility(View.VISIBLE);
                    emptyTextView.setOnClickListener(v -> loadContainersList());"""
if c.count(old_error) != 1:
    raise SystemExit("ContainersFragment error refresh anchor changed.")
c = c.replace(old_error, new_error, 1)
containers.write_text(c, encoding="utf-8")

# Ensure the install callback still runs even if closing the progress dialog throws.
installer = app / "src/main/java/com/winlator/xenvironment/RootFSInstaller.java"
r = installer.read_text(encoding="utf-8")
old_finally = """            finally {
                dialog.closeOnUiThread();
                if (onComplete != null) activity.runOnUiThread(onComplete);
            }"""
new_finally = """            finally {
                try {
                    dialog.closeOnUiThread();
                }
                catch (Exception closeError) {
                    android.util.Log.w("WinCore", "Could not close RootFS progress dialog", closeError);
                }
                if (onComplete != null) {
                    try {
                        activity.runOnUiThread(onComplete);
                    }
                    catch (Exception callbackError) {
                        android.util.Log.e("WinCore", "Could not dispatch RootFS completion callback", callbackError);
                    }
                }
            }"""
if r.count(old_finally) != 1:
    raise SystemExit("RootFSInstaller final callback guard anchor changed.")
r = r.replace(old_finally, new_finally, 1)
installer.write_text(r, encoding="utf-8")
PY

grep -q 'Container directory is missing:' "$APP_MODULE/src/main/java/com/winlator/container/ContainerManager.java"
grep -q 'Android could not list container directory:' "$APP_MODULE/src/main/java/com/winlator/container/ContainerManager.java"
grep -q 'public ArrayList<String> getLoadWarnings()' "$APP_MODULE/src/main/java/com/winlator/container/ContainerManager.java"
grep -q 'Tap here to scan again.' "$APP_MODULE/src/main/java/com/winlator/ContainersFragment.java"
grep -q 'Could not close RootFS progress dialog' "$APP_MODULE/src/main/java/com/winlator/xenvironment/RootFSInstaller.java"



# Validate the essential RootFS directories as well as the version marker.
python3 - "$APP_MODULE" <<'PY'
from pathlib import Path
import sys
app = Path(sys.argv[1])
rootfs = app / "src/main/java/com/winlator/xenvironment/RootFS.java"
source = rootfs.read_text(encoding="utf-8")
old = """    public boolean isValid() {
        return rootDir.isDirectory() && getRFSVersionFile().exists();
    }"""
new = """    public boolean isValid() {
        return rootDir.isDirectory()
            && getRFSVersionFile().isFile()
            && new File(rootDir, "home").isDirectory()
            && new File(rootDir, "opt").isDirectory();
    }"""
if source.count(old) != 1:
    raise SystemExit("RootFS.isValid health-check anchor changed.")
rootfs.write_text(source.replace(old, new, 1), encoding="utf-8")

fragment = app / "src/main/java/com/winlator/ContainersFragment.java"
source = fragment.read_text(encoding="utf-8")
old_click = """            emptyTextView.setOnClickListener(v -> {
                MainActivity activity = (MainActivity)getActivity();
                if (activity != null) {
                    emptyTextView.setText("Installing system files…");
                    RootFSInstaller.installIfNeeded(activity, this::reloadContainers);
                }
            });"""
new_click = """            emptyTextView.setOnClickListener(v -> {
                MainActivity activity = (MainActivity)getActivity();
                if (activity != null) {
                    emptyTextView.setOnClickListener(null);
                    emptyTextView.setText("Checking and repairing system files…");
                    RootFSInstaller.installIfNeeded(activity, this::reloadContainers);
                }
            });"""
if source.count(old_click) != 1:
    raise SystemExit("ContainersFragment RootFS retry click anchor changed.")
fragment.write_text(source.replace(old_click, new_click, 1), encoding="utf-8")
PY

grep -q 'new File(rootDir, "home").isDirectory()' "$APP_MODULE/src/main/java/com/winlator/xenvironment/RootFS.java"
grep -q 'new File(rootDir, "opt").isDirectory()' "$APP_MODULE/src/main/java/com/winlator/xenvironment/RootFS.java"
grep -q 'emptyTextView.setOnClickListener(null);' "$APP_MODULE/src/main/java/com/winlator/ContainersFragment.java"
