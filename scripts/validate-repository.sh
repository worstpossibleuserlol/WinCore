#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

for required in VERSION .gitmodules README.md FEATURES.md CHANGELOG.md scripts/apply-wincore-patch.sh .github/workflows/android.yml; do
  [[ -s "$required" ]] || fail "required file is missing or empty: $required"
done

VERSION_VALUE="$(tr -d '[:space:]' < VERSION)"
[[ "$VERSION_VALUE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION must use MAJOR.MINOR.PATCH"

python3 - "$VERSION_VALUE" .github/workflows/android.yml <<'PY'
import re
import sys
from pathlib import Path

version = sys.argv[1]
workflow = Path(sys.argv[2]).read_text(encoding="utf-8")
major, minor, patch = (int(part) for part in version.split("."))
expected_code = major * 10000 + minor * 100 + patch

version_matches = re.findall(r"^\s*WINCORE_VERSION:\s*['\"]?([^'\"\s]+)", workflow, re.M)
code_matches = re.findall(r"^\s*WINCORE_VERSION_CODE:\s*(\d+)", workflow, re.M)

if version_matches != [version]:
    raise SystemExit(f"android.yml WINCORE_VERSION must match VERSION ({version}); found {version_matches}")
if code_matches != [str(expected_code)]:
    raise SystemExit(f"android.yml WINCORE_VERSION_CODE must be {expected_code}; found {code_matches}")

print(f"Version metadata OK: {version} (versionCode {expected_code})")
PY

[[ -d upstream/.git ]] || fail "upstream submodule is not initialized; use git clone --recurse-submodules"
EXPECTED_UPSTREAM="$(git ls-tree HEAD upstream | awk '$1 == "160000" && $2 == "commit" { print $3 }')"
[[ -n "$EXPECTED_UPSTREAM" ]] || fail "upstream is not recorded as a Git submodule in HEAD"
ACTUAL_UPSTREAM="$(git -C upstream rev-parse HEAD)"
[[ "$ACTUAL_UPSTREAM" == "$EXPECTED_UPSTREAM" ]] || fail "upstream checkout does not match the commit pinned by this WinCore revision"

bash -n scripts/apply-wincore-patch.sh
bash -n scripts/validate-repository.sh

printf 'Repository validation passed.\n'
printf 'WinCore version: %s\n' "$VERSION_VALUE"
printf 'Pinned upstream commit: %s\n' "$EXPECTED_UPSTREAM"
