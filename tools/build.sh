#!/usr/bin/env bash
# Build the installable module ZIP without accidentally packaging repository
# archives (especially ScreenOff-CoresOff-v2.1-stable.zip) or development files.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${1:-$ROOT/XtremeBS.zip}"
[[ "$OUTPUT" = /* ]] || OUTPUT="$ROOT/$OUTPUT"
mkdir -p "$(dirname -- "$OUTPUT")"

files=(
  CHANGELOG.md
  LICENSE
  META-INF
  README.md
  action.sh
  customize.sh
  module.prop
  service.sh
  system
  update.json
  webroot
  webui
  xbs-webui.sh
)

for item in "${files[@]}"; do
  [[ -e "$ROOT/$item" ]] || { echo "Missing package input: $item" >&2; exit 1; }
done

# Keep update metadata internally consistent with the canonical source branch.
version=$(sed -n 's/^version=//p' "$ROOT/module.prop" | head -n 1)
version_code=$(sed -n 's/^versionCode=//p' "$ROOT/module.prop" | head -n 1)
[ -n "$version" ] && [ -n "$version_code" ] || { echo "Invalid module.prop version metadata" >&2; exit 1; }
grep -Fqx "updateJson=https://raw.githubusercontent.com/Rocker14427c/Xtreme-Battery-Saver/main/update.json" "$ROOT/module.prop"
grep -Fq "\"version\": \"$version\"" "$ROOT/update.json"
grep -Fq "\"versionCode\": \"$version_code\"" "$ROOT/update.json"
grep -Fq "/main/XtremeBS.zip" "$ROOT/update.json"

# zip refuses to create an archive over an already-created empty mktemp file.
tmp="$(mktemp "$ROOT/.XtremeBS-build.XXXXXX.zip")"
rm -f "$tmp"
trap 'rm -f "$tmp"' EXIT
(
  cd "$ROOT"
  zip -X -q -r "$tmp" "${files[@]}"
)

unzip -tqq "$tmp"
entries=$(unzip -Z1 "$tmp")
grep -qx 'module.prop' <<< "$entries"
grep -qx 'webroot/index.html' <<< "$entries"
grep -qx 'xbs-webui.sh' <<< "$entries"

mv -f "$tmp" "$OUTPUT"
trap - EXIT
echo "Built: $OUTPUT"
