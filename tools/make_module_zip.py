#!/usr/bin/env python3
"""Pack a Magisk module directory into a flashable Magisk module zip.

Author: DrClef <https://github.com/drclefcxk>

usage: make_module_zip.py <module directory> <output zip>

The module directory must contain module.prop.  Symbolic links and empty
directories are skipped on purpose: a Magisk module only needs regular files.
"""

from __future__ import annotations

import os
import sys
import zipfile


def fail(message: str) -> int:
    print(f"error: {message}", file=sys.stderr)
    return 1


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(f"usage: {argv[0]} <module directory> <output zip>", file=sys.stderr)
        return 1

    src = os.path.abspath(argv[1])
    dst = os.path.abspath(argv[2])

    if not os.path.isdir(src):
        return fail(f"module directory not found: {src}")
    if not os.path.isfile(os.path.join(src, "module.prop")):
        return fail("module.prop is missing, this is not a Magisk module directory")

    entries: list[tuple[str, str]] = []
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for name in sorted(files):
            full = os.path.join(root, name)
            if os.path.islink(full) or not os.path.isfile(full):
                continue
            rel = os.path.relpath(full, src).replace(os.sep, "/")
            entries.append((full, rel))

    if not entries:
        return fail("module directory is empty")

    # Keep update-binary first, it is the first file recovery tooling looks at.
    update_binary = "META-INF/com/google/android/update-binary"
    entries.sort(key=lambda item: (item[1] != update_binary, item[1]))

    os.makedirs(os.path.dirname(dst) or ".", exist_ok=True)
    if os.path.exists(dst):
        os.remove(dst)

    total = 0
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as archive:
        for full, rel in entries:
            archive.write(full, rel)
            total += os.path.getsize(full)

    size = os.path.getsize(dst)
    print(
        f"==> Packed {len(entries)} files "
        f"({total / 1024 / 1024:.1f} MiB unpacked) -> {dst} "
        f"({size / 1024 / 1024:.1f} MiB)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
