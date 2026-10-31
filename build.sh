#!/usr/bin/env bash
#
# build.sh - Build a systemless "NikGapps for Magisk" module zip.
#
# Author: DrClef <https://github.com/drclefcxk>
# Adapted from opengapps-magisk (ic0xgkk / Bave Lee) and
# OpenGapps-For-Magisk-Converter (Bave Lee), GPL-3.0.
#
# usage: ./build.sh [NikGapps zip] [output zip]
#
# With no arguments it uses the NikGapps zip named in .env, or the first
# NikGapps-*.zip found in this directory.  The resulting Magisk module zip is
# written to this directory as "<NikGapps zip name>-magisk.zip".
#
# requirements: unzip, tar, python3
#
# License: GPL-3.0-or-later

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

# ---------------------------------------------------------------------------
# Configuration (optional, see .env)
# ---------------------------------------------------------------------------

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  . ./.env
  set +a
fi

# ---------------------------------------------------------------------------
# Locate the NikGapps zip
# ---------------------------------------------------------------------------

input_zip="${1:-}"

if [[ -z "$input_zip" ]] && [[ -n "${NIKGAPPS_ZIP_NAME:-}" ]] && [[ -f "$NIKGAPPS_ZIP_NAME" ]]; then
  input_zip="$NIKGAPPS_ZIP_NAME"
fi

if [[ -z "$input_zip" ]]; then
  shopt -s nullglob
  candidates=(NikGapps-*.zip)
  shopt -u nullglob

  if [[ "${#candidates[@]}" -eq 0 ]]; then
    cat >&2 <<EOF
error: no NikGapps zip found in $(pwd)

  Download a build and run:
    ./build.sh NikGapps-core-arm64-12-20241231-signed.zip
EOF
    exit 1
  fi

  input_zip="${candidates[0]}"
fi

if [[ ! -f "$input_zip" ]]; then
  echo "error: NikGapps zip not found: $input_zip" >&2
  exit 1
fi

input_zip="$(cd "$(dirname "$input_zip")" && pwd)/$(basename "$input_zip")"
stem="$(basename "$input_zip" .zip)"
output_zip="${2:-$PWD/${stem}-magisk.zip}"

# ---------------------------------------------------------------------------
# Work out module metadata from the NikGapps file name
# ---------------------------------------------------------------------------

info="${stem#NikGapps-}"
info="${info%-signed}"

version="${info}"
version_code="1"

if [[ "$info" =~ ^([A-Za-z]+)-([A-Za-z0-9]+)-([0-9.]+)-([0-9]{8})$ ]]; then
  version_code="${BASH_REMATCH[4]}"
fi

module_version="${RELEASE_VERSION:-$version}"

echo "==> Source   : $input_zip"
echo "==> Version  : $module_version (code $version_code)"

# ---------------------------------------------------------------------------
# Build the module
# ---------------------------------------------------------------------------

build_dir="$PWD/.build"
module_dir="$build_dir/module"

rm -rf "$build_dir"
mkdir -p "$module_dir"
cp -a magisk-template/. "$module_dir/"

cat > "$module_dir/module.prop" <<EOF
id=${MODULE_ID:-nikgapps-magisk}
name=${MODULE_NAME:-NikGapps for Magisk}
version=${module_version}
versionCode=${version_code}
author=${MODULE_AUTHOR:-DrClef}
description=Systemless NikGapps (${module_version}). Flash from the Magisk app, reboot and use Google apps without touching /system.
minMagisk=20400
support=${MODULE_SUPPORT:-https://github.com/drclefcxk/nikgapps-magisk}
EOF

./convert-nikgapps-to-magisk.sh "$input_zip" "$module_dir"

# Sensible modes for the module files (Magisk re-applies them on install)
chmod 0755 "$module_dir/META-INF/com/google/android/update-binary"
chmod 0644 "$module_dir/module.prop" "$module_dir/customize.sh"
find "$module_dir" -type d -exec chmod 0755 {} +
find "$module_dir/system" -type f -exec chmod 0644 {} + 2>/dev/null || true

# ---------------------------------------------------------------------------
# Pack the module
# ---------------------------------------------------------------------------

python3 tools/make_module_zip.py "$module_dir" "$output_zip"

echo "==> SHA-256  : $(sha256sum "$output_zip" | cut -d' ' -f1)"
echo "==> Output   : $output_zip"
