#!/usr/bin/env bash
#
# convert-nikgapps-to-magisk.sh
#
# Author: DrClef <https://github.com/drclefcxk>
# Adapted from opengapps-magisk (ic0xgkk / Bave Lee) and
# OpenGapps-For-Magisk-Converter (Bave Lee), GPL-3.0.
#
# Convert a NikGapps flashable zip into the systemless payload of a Magisk
# module (the "system" folder of a Magisk module).
#
# NikGapps stores every package as its own archive:
#
#   AppSet/<AppSet>/<Package>.zip
#
# and each file inside that archive is prefixed with an encoded path, e.g.
#
#   ___priv-app___PrebuiltGmsCore/PrebuiltGmsCoreSc.apk
#
# The "___" separator stands for a path separator while the leading one is a
# partition-less path.  NikGapps installs such a file into the partition that
# is configured for the package (product, system_ext, ...), unless the path
# starts with an explicit partition name (system/system_ext/product/vendor) or
# with "overlay" (which always belongs to the product overlay).
#
# This script rebuilds the exact same layout, but rooted at
#
#   <module dir>/system/<partition>/<path>
#
# which is the layout Magisk expects (Magisk transparently handles whether
# /product, /system_ext and friends are dedicated partitions or not).
#
# usage: ./convert-nikgapps-to-magisk.sh <NikGapps zip> <module directory>
#
# The module directory must already contain module.prop (and optionally
# customize.sh).  Its "system" folder is wiped and recreated by this script.
#
# Requirements: bash, unzip, tar (xz support)
#
# License: GPL-3.0-or-later

set -euo pipefail

if ((BASH_VERSINFO[0] < 4)); then
  echo "ERROR: bash 4 or newer is required (found ${BASH_VERSION})" >&2
  exit 1
fi

usage() {
  cat >&2 <<EOF
usage: $0 <NikGapps flashable zip> <module directory>

  e.g: $0 NikGapps-core-arm64-12-20241231-signed.zip ./.build/module
EOF
}

if [[ $# -ne 2 ]]; then
  usage
  exit 1
fi

nikgapps_zip="$1"
module_dir="$2"

[[ -f "$nikgapps_zip" ]] || {
  echo "ERROR: NikGapps zip not found: $nikgapps_zip" >&2
  exit 1
}

for tool in unzip tar; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: '$tool' is required but was not found in PATH" >&2
    exit 1
  }
done

nikgapps_zip="$(cd "$(dirname "$nikgapps_zip")" && pwd)/$(basename "$nikgapps_zip")"

mkdir -p "$module_dir"
module_dir="$(cd "$module_dir" && pwd)"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/nikgapps-convert.XXXXXX")"
cleanup() {
  rm -rf "$work_dir"
}
trap cleanup EXIT

echo "==> Extracting $(basename "$nikgapps_zip")"
unzip -q "$nikgapps_zip" -d "$work_dir/nik"

nik_dir="$work_dir/nik"

[[ -d "$nik_dir/AppSet" ]] || {
  echo "ERROR: $nikgapps_zip does not look like a NikGapps build (AppSet/ is missing)" >&2
  exit 1
}

###############################################################################
# Package -> partition map
#
# common/install.sh contains blocks such as:
#
#   Core="
#   GoogleServicesFramework,7415,system_ext
#   GooglePlayStore,53834,product
#   ...
#   "
#
# which is the authoritative source for the partition each package installs
# into.  Packages that are not listed there fall back to the
# "default_partition" value of their own installer.sh, then to "product".
###############################################################################

declare -A pkg_partitions=()

install_sh="$nik_dir/common/install.sh"
if [[ -f "$install_sh" ]]; then
  while IFS=',' read -r pkg_name _pkg_size pkg_partition; do
    case "$pkg_partition" in
      system|product|system_ext|vendor)
        pkg_partitions["$pkg_name"]="$pkg_partition"
        ;;
    esac
  done < <(
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$install_sh" |
      grep -E '^[A-Za-z0-9_.]+,-?[0-9]+,(system|product|system_ext|vendor)$' || true
  )
fi

###############################################################################
# Helpers
###############################################################################

# Map a NikGapps package entry to its path inside the Magisk module.
#   $1 = entry path exactly as stored in the package archive
#   $2 = default partition of the package
# Prints e.g. "system/product/priv-app/PrebuiltGmsCore/PrebuiltGmsCoreSc.apk"
map_entry_path() {
  local entry="$1"
  local default_partition="$2"
  local loc first rest target

  # "___priv-app___Foo/bar.apk" -> "priv-app/Foo/bar.apk"
  loc="${entry//___//}"
  while [[ "$loc" == /* ]]; do
    loc="${loc#/}"
  done

  [[ -n "$loc" ]] || return 0

  first="${loc%%/*}"
  if [[ "$loc" == */* ]]; then
    rest="${loc#*/}"
  else
    rest=""
  fi

  case "$first" in
    system)
      # Explicit "/system/..." entry
      target="system/$rest"
      ;;
    product|system_ext|vendor|odm)
      # Explicit partition entry
      target="system/$first/$rest"
      ;;
    overlay)
      # NikGapps installs overlays into the product partition
      target="system/product/overlay/$rest"
      ;;
    *)
      target="system/$default_partition/$loc"
      ;;
  esac

  printf '%s' "${target%/}"
}

# Read default_partition="..." out of an unpacked package directory.
read_default_partition() {
  local pkg_dir="$1"
  local value=""
  if [[ -f "$pkg_dir/installer.sh" ]]; then
    value="$(sed -n 's/^default_partition="\([^"]*\)".*/\1/p' "$pkg_dir/installer.sh" | head -n 1)"
  fi
  case "$value" in
    system|product|system_ext|vendor) printf '%s' "$value" ;;
    *) printf '%s' "product" ;;
  esac
}

extract_pkg_archive() {
  local archive="$1" dest="$2"
  rm -rf "$dest"
  mkdir -p "$dest"
  case "$archive" in
    *.zip) unzip -q "$archive" -d "$dest" ;;
    *.tar.xz) tar -xJf "$archive" -C "$dest" ;;
    *)
      return 1
      ;;
  esac
}

###############################################################################
# Convert
###############################################################################

payload_dir="$module_dir/system"
rm -rf "$payload_dir"
mkdir -p "$payload_dir"

pkg_count=0
file_count=0

shopt -s nullglob
for appset_dir in "$nik_dir"/AppSet/*/; do
  appset_name="$(basename "$appset_dir")"

  for pkg_archive in "$appset_dir"*; do
    case "$pkg_archive" in
      *.zip|*.tar.xz) ;;
      *) continue ;;
    esac

    pkg_file="$(basename "$pkg_archive")"
    pkg_name="${pkg_file%.zip}"
    pkg_name="${pkg_name%.tar.xz}"

    pkg_work="$work_dir/pkg"
    if ! extract_pkg_archive "$pkg_archive" "$pkg_work"; then
      echo "[SKIP] Unsupported package format: $appset_name/$pkg_file" >&2
      continue
    fi

    default_partition="${pkg_partitions[$pkg_name]:-}"
    [[ -n "$default_partition" ]] || default_partition="$(read_default_partition "$pkg_work")"

    pkg_files=0
    while IFS= read -r -d '' file; do
      rel="${file#"$pkg_work"/}"

      # Installer helper scripts are NikGapps internals, not payload
      case "$rel" in
        installer.sh|uninstaller.sh) continue ;;
      esac

      target="$(map_entry_path "$rel" "$default_partition")"
      [[ -n "$target" ]] || continue

      mkdir -p "$module_dir/$(dirname "$target")"
      cp -f "$file" "$module_dir/$target"
      pkg_files=$((pkg_files + 1))
    done < <(find "$pkg_work" -type f -print0)

    if [[ "$pkg_files" -eq 0 ]]; then
      echo "[SKIP] $appset_name/$pkg_name (no payload files)"
      continue
    fi

    printf '[CONVERT] %-28s -> system/%-10s (%s files)\n' \
      "$appset_name/$pkg_name" "$default_partition" "$pkg_files"

    pkg_count=$((pkg_count + 1))
    file_count=$((file_count + pkg_files))
  done
done

if [[ "$pkg_count" -eq 0 ]]; then
  echo "ERROR: No package could be converted from $nikgapps_zip" >&2
  exit 1
fi

echo "==> Converted $pkg_count package(s), $file_count file(s)"
du -sh "$payload_dir" | awk '{print "==> Payload size: " $1}'
