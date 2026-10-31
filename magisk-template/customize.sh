#!/system/bin/sh
#
# NikGapps for Magisk - installation customization
#
# This script is sourced (not executed) by Magisk's module installer *after*
# the module files were extracted into $MODPATH.  It runs inside Magisk's
# BusyBox ash with standalone mode enabled, so keep it POSIX sh compatible.
#
# DO NOT call "exit" here: the installer still has cleanup work to do.
#

ui_print " "
ui_print "*******************************"
ui_print "  NikGapps for Magisk"
ui_print "  Systemless Google Apps"
ui_print "*******************************"
ui_print "- Arch: ${ARCH:-unknown} / API: ${API:-unknown}"

# Every NikGapps build shipped by this project is arm64 only.
if [ -n "$ARCH" ] && [ "$ARCH" != "arm64" ]; then
  abort "! This NikGapps build is arm64 only (detected: $ARCH)"
fi

# The bundled Google apps are built for a specific Android version: using
# them on an older release usually breaks Google Play Services.
if [ -n "$API" ] && [ "$API" -lt 31 ] 2>/dev/null; then
  ui_print "! Warning: this NikGapps build targets Android 12 (API 31)."
  ui_print "! Your device reports API $API - Google apps may crash."
fi

# Files are mounted systemlessly; make sure ownership/permissions match what
# Android expects even when the installer skipped the default extraction.
if [ -d "$MODPATH/system" ]; then
  set_perm_recursive "$MODPATH/system" 0 0 0755 0644
fi

app_count="$(find "$MODPATH/system" -type f -name '*.apk' 2>/dev/null | wc -l | tr -d ' ')"
ui_print "- $app_count app(s) will be mounted over /system at boot"
ui_print "- Reboot to activate NikGapps"
