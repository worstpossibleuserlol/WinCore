#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
UPSTREAM_DIR="${1:-"${REPO_ROOT}/upstream"}"
APP_REPO="${UPSTREAM_DIR}/app"
APP_MODULE="${APP_REPO}/app"

if [[ ! -f "${APP_REPO}/gradlew" || ! -f "${APP_MODULE}/build.gradle" ]]; then
  echo "Winlator source was not found."
  echo "Clone WinCore with: git clone --recurse-submodules ..."
  exit 1
fi

python3 - "${APP_MODULE}" <<'PY'
from pathlib import Path
import re
import sys

app = Path(sys.argv[1])

def replace_once(relative_path: str, old: str, new: str) -> None:
    path = app / relative_path
    if not path.is_file():
        raise SystemExit(f"Required upstream file is missing: {path}")
    source = path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise SystemExit(
            f"Expected exactly one occurrence of {old!r} in {path}, found {count}. "
            "Review the upstream change before applying the WinCore patch."
        )
    path.write_text(source.replace(old, new, 1), encoding="utf-8")

# Keep the upstream Java namespace intact, but install WinCore as a separate app.
replace_once(
    "build.gradle",
    "applicationId 'com.winlator'",
    "applicationId 'com.wincore'",
)
replace_once("build.gradle", "versionCode 33", "versionCode 1")
replace_once('build.gradle', 'versionName "11.2"', 'versionName "0.1.0"')

# Match the provider authority to the new application ID.
replace_once(
    "src/main/AndroidManifest.xml",
    'android:authorities="com.winlator.FileProvider"',
    'android:authorities="${applicationId}.FileProvider"',
)

# Resolve FileProvider using the installed package name, not the old app ID.
replace_once(
    "src/main/java/com/winlator/core/FileUtils.java",
    'FileProvider.getUriForFile(activity, "com.winlator.FileProvider", file)',
    'FileProvider.getUriForFile(activity, activity.getPackageName() + ".FileProvider", file)',
)

# Apply the product name to all shipped string-resource locales.
resource_root = app / "src/main/res"
updated = 0
for strings_file in resource_root.glob("values*/strings.xml"):
    source = strings_file.read_text(encoding="utf-8")
    patched, count = re.subn(
        r'(<string\s+name="app_name"[^>]*>)Winlator(</string>)',
        r'\1WinCore\2',
        source,
        count=1,
    )
    if count:
        strings_file.write_text(patched, encoding="utf-8")
        updated += 1

if updated == 0:
    raise SystemExit("Could not find the upstream app_name string to brand as WinCore.")

print(f"WinCore 0.1.0 patch applied. Updated app name in {updated} locale resource file(s).")
PY
