#!/bin/sh
# KPM install hook. Installs active launchers and a private version-report helper.
# Retired-artifact cleanup is built into KPM-Update-All.
set -e
DOCS="/mnt/us/documents"
INTERNAL_DIR="$DOCS/.royalroadtools"
mkdir -p "$DOCS" "$INTERNAL_DIR"
# One-time migration from the former queue-based cleaner. This package install
# hook runs during KPM Update All, so legacy cleanup state is removed without
# installing a separate cleaner or creating replacement state files.
rm -f "$DOCS/RoyalRoadTools-Cleanup.sh" \
  "$DOCS/RoyalRoadTools-Cleanup-Queue.txt" \
  "$DOCS/RoyalRoadTools-Cleanup-Completed.txt" \
  "$DOCS/RoyalRoadTools-Cleanup.log" \
  "$INTERNAL_DIR/cleanup.sh"
say() { printf '%s\n' "$*"; }

install_scriptlet() {
  SOURCE="$1"; DEST="$2"; TEMP="$DEST.new.$"
  say "Installing $(basename "$DEST")..."
  cp "$SOURCE" "$TEMP"; chmod 755 "$TEMP"; mv -f "$TEMP" "$DEST"
}


# Stage the Rav Zvi USB Overlay Fix from the bundled KPKG.
# This only stages the installer, restore script, and transparent replacement icons.
# It deliberately does NOT run the system installer or modify bg_usbconnect.png.
install_usb_overlay_payload() {
  OVERLAY_PACKAGE="files/rav-zvi-usb-overlay-fix.kpkg"
  EXTRACT_DIR="$INTERNAL_DIR/usb-overlay-extract.$"
  PAYLOAD_DIR="$EXTRACT_DIR/payload"
  ASSET_DEST="$DOCS/RavZviUSBOverlayFix/assets"

  if ! command -v tar >/dev/null 2>&1; then
    say "ERROR: tar is required to stage the bundled USB overlay files."
    return 1
  fi
  if [ ! -s "$OVERLAY_PACKAGE" ] || ! tar -tzf "$OVERLAY_PACKAGE" >/dev/null 2>&1; then
    say "ERROR: Bundled Rav Zvi USB Overlay Fix package is missing or corrupt."
    return 1
  fi

  rm -rf "$EXTRACT_DIR"
  if ! mkdir -p "$EXTRACT_DIR" || ! tar -xzf "$OVERLAY_PACKAGE" -C "$EXTRACT_DIR"; then
    rm -rf "$EXTRACT_DIR"
    say "ERROR: Could not extract the bundled Rav Zvi USB Overlay Fix package."
    return 1
  fi

  if [ ! -s "$PAYLOAD_DIR/Install-Rav-Zvi-USB-Overlay-Fix.sh" ] ||
     [ ! -s "$PAYLOAD_DIR/Restore-Rav-Zvi-USB-Overlay-Fix.sh" ] ||
     [ ! -s "$PAYLOAD_DIR/RavZviUSBOverlayFix/assets/ov_default_charging.png" ] ||
     [ ! -s "$PAYLOAD_DIR/RavZviUSBOverlayFix/assets/ov_default_notcharging.png" ]; then
    rm -rf "$EXTRACT_DIR"
    say "ERROR: Bundled USB overlay payload is incomplete."
    return 1
  fi

  mkdir -p "$ASSET_DEST"
  cp "$PAYLOAD_DIR/Install-Rav-Zvi-USB-Overlay-Fix.sh" "$DOCS/Install-Rav-Zvi-USB-Overlay-Fix.sh"
  cp "$PAYLOAD_DIR/Restore-Rav-Zvi-USB-Overlay-Fix.sh" "$DOCS/Restore-Rav-Zvi-USB-Overlay-Fix.sh"
  cp "$PAYLOAD_DIR/RavZviUSBOverlayFix/assets/ov_default_charging.png" "$ASSET_DEST/ov_default_charging.png"
  cp "$PAYLOAD_DIR/RavZviUSBOverlayFix/assets/ov_default_notcharging.png" "$ASSET_DEST/ov_default_notcharging.png"
  chmod 755 "$DOCS/Install-Rav-Zvi-USB-Overlay-Fix.sh" "$DOCS/Restore-Rav-Zvi-USB-Overlay-Fix.sh"
  chmod 644 "$ASSET_DEST/ov_default_charging.png" "$ASSET_DEST/ov_default_notcharging.png"

  {
    printf '%s\\n' "version=1.0.0"
    printf '%s\\n' "staged_at=$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s\\n' "system_overlay_applied=no"
  } > "$INTERNAL_DIR/usb-overlay-version.txt"
  chmod 600 "$INTERNAL_DIR/usb-overlay-version.txt"
  rm -rf "$EXTRACT_DIR"

  say "Staged Rav Zvi USB Overlay Fix v1.0.0 in Documents."
  say "The existing bg_usbconnect.png was not included or changed."
  say "The system overlay has not been applied; use Install-Rav-Zvi-USB-Overlay-Fix.sh when ready."
}


# Install the KPM-managed ScreenLockPin plugin into the existing KOReader tree.
# Plugin PIN/settings live in KOReader's settings.reader.lua, not in this code folder.
install_screenlockpin_plugin() {
  SOURCE_DIR="files/screenlockpin.koplugin"
  KO_ROOT="/mnt/us/koreader"
  PLUGIN_ROOT="$KO_ROOT/plugins"
  PLUGIN_NAME="screenlockpin.koplugin"
  DEST_DIR="$PLUGIN_ROOT/$PLUGIN_NAME"
  TEMP_DIR="$PLUGIN_ROOT/.$PLUGIN_NAME.new.$"
  BACKUP_DIR="$PLUGIN_ROOT/.$PLUGIN_NAME.backup.$"
  MARKER="$DEST_DIR/.royalroad-kpm-managed"

  if [ ! -d "$KO_ROOT" ]; then
    say "ERROR: KOReader root not found: $KO_ROOT"
    return 1
  fi
  if [ ! -d "$SOURCE_DIR" ] ||
     [ ! -s "$SOURCE_DIR/_meta.lua" ] ||
     [ ! -s "$SOURCE_DIR/main.lua" ]; then
    say "ERROR: Required bundled ScreenLockPin plugin files are missing."
    return 1
  fi

  # SHA256SUMS is optional. If a publisher supplies it, keep the integrity
  # check; otherwise do not block installation of the verified-in-repository
  # plugin source files merely because the checksum manifest is absent.
  if [ -s "$SOURCE_DIR/SHA256SUMS" ]; then
    if ! (cd "$SOURCE_DIR" && sha256sum -c SHA256SUMS); then
      say "ERROR: Bundled ScreenLockPin checksum validation failed."
      return 1
    fi
  else
    say "NOTICE: Bundled ScreenLockPin SHA256SUMS is absent; source checksum validation skipped."
  fi

  mkdir -p "$PLUGIN_ROOT"
  rm -rf "$TEMP_DIR" "$BACKUP_DIR"
  if ! mkdir "$TEMP_DIR"; then
    say "ERROR: Could not create temporary ScreenLockPin folder."
    return 1
  fi
  if ! cp -R "$SOURCE_DIR"/. "$TEMP_DIR"/; then
    rm -rf "$TEMP_DIR"
    say "ERROR: Could not stage ScreenLockPin files."
    return 1
  fi
  if [ -s "$TEMP_DIR/SHA256SUMS" ]; then
    if ! (cd "$TEMP_DIR" && sha256sum -c SHA256SUMS); then
      rm -rf "$TEMP_DIR"
      say "ERROR: Staged ScreenLockPin files failed checksum validation."
      return 1
    fi
  else
    say "NOTICE: Staged ScreenLockPin has no SHA256SUMS; staged checksum validation skipped."
  fi

  HAD_OLD=0
  if [ -e "$DEST_DIR" ] || [ -L "$DEST_DIR" ]; then
    if ! mv "$DEST_DIR" "$BACKUP_DIR"; then
      rm -rf "$TEMP_DIR"
      say "ERROR: Could not preserve the existing ScreenLockPin folder."
      return 1
    fi
    HAD_OLD=1
  fi

  if ! mv "$TEMP_DIR" "$DEST_DIR"; then
    rm -rf "$TEMP_DIR"
    if [ "$HAD_OLD" -eq 1 ]; then
      mv "$BACKUP_DIR" "$DEST_DIR" || true
    fi
    say "ERROR: Could not install ScreenLockPin into $DEST_DIR."
    return 1
  fi

  if ! {
    printf '%s\n' "managed_by=royalroad-kindle-tools"
    printf '%s\n' "upstream_version=2026.10"
  } > "$MARKER"; then
    rm -rf "$DEST_DIR"
    if [ "$HAD_OLD" -eq 1 ]; then
      mv "$BACKUP_DIR" "$DEST_DIR" || true
    fi
    say "ERROR: Could not write ScreenLockPin ownership marker."
    return 1
  fi

  rm -rf "$BACKUP_DIR"
  say "Installed ScreenLockPin v2026.10 into $DEST_DIR."
  say "Existing KOReader PIN and preferences were left in settings.reader.lua."
}


say "Royal Road Kindle Tools — installing current toolset."
install_scriptlet "scriptlets/KPP-Native-Bridge-Export.sh" "$DOCS/KPP-Native-Bridge-Export.sh"
install_scriptlet "scriptlets/KPP-JavaScript-Bundle-Export.sh" "$DOCS/KPP-JavaScript-Bundle-Export.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"
install_scriptlet "scriptlets/Inspect-USB-Screen.sh" "$DOCS/Inspect-USB-Screen.sh"
install_scriptlet "scriptlets/KPP-Page-Text-Capture.sh" "$DOCS/KPP-Page-Text-Capture.sh"

# Install the firmware-matched experimental offscreen WebKit helper privately.
command -v gzip >/dev/null 2>&1 || {
  say "ERROR: gzip is required to install the experimental page-capture helper."
  exit 1
}
CAPTURE_HELPER_TEMP="$INTERNAL_DIR/kpp-page-capture.new.$$"
if [ ! -s "files/kpp-page-capture.gz" ] || ! gzip -t "files/kpp-page-capture.gz"; then
  say "ERROR: Experimental KPP page-capture helper archive is missing or corrupt."
  exit 1
fi
if ! gzip -dc "files/kpp-page-capture.gz" > "$CAPTURE_HELPER_TEMP" || [ ! -s "$CAPTURE_HELPER_TEMP" ]; then
  rm -f "$CAPTURE_HELPER_TEMP"
  say "ERROR: Could not unpack the experimental KPP page-capture helper."
  exit 1
fi
chmod 700 "$CAPTURE_HELPER_TEMP"
mv -f "$CAPTURE_HELPER_TEMP" "$INTERNAL_DIR/kpp-page-capture"
install_scriptlet "scriptlets/RoyalRoadTools-Version-Info.sh" "$INTERNAL_DIR/version-info.sh"
install_usb_overlay_payload

install_screenlockpin_plugin

say "ScreenLockPin installation step complete."
say "Reading the package version from manifest.json..."
VERSION_COMPONENTS="$(sed -n '/"version"[[:space:]]*:/,/]/p' manifest.json | grep -E '^[[:space:]]*[0-9]+[[:space:],]*$' | tr -cd '0-9\n' | tr '\n' ' ')"
set -- $VERSION_COMPONENTS
if [ "$#" -ge 3 ]; then
  PACKAGE_VERSION="$1.$2.$3"
else
  PACKAGE_VERSION="unknown"
fi
say "Package version resolved as: $PACKAGE_VERSION"

STAMP_TEMP="$DOCS/.RoyalRoadTools-installed-version.txt.tmp.$$"
{
  printf 'version=%s\n' "$PACKAGE_VERSION"
  printf 'installed_at=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
} > "$STAMP_TEMP"
if ! chmod 600 "$STAMP_TEMP"; then
  rm -f "$STAMP_TEMP"
  say "ERROR: Could not protect the installed-version stamp."
  exit 1
fi
if ! mv -f "$STAMP_TEMP" "$DOCS/.RoyalRoadTools-installed-version.txt"; then
  rm -f "$STAMP_TEMP"
  say "ERROR: Could not write the installed-version stamp."
  exit 1
fi

# Temporary hidden handoff for the already-running pre-upgrade Update All script.
# The new updater performs the cleanup itself, then removes this one-use shim.
cat > "$INTERNAL_DIR/cleanup.sh" <<'CLEANUP_HANDOFF'
#!/bin/sh
SELF="$0"
sh "/mnt/us/documents/KPM-Update-All.sh" --cleanup-only
RESULT=$?
rm -f "$SELF"
exit "$RESULT"
CLEANUP_HANDOFF
chmod 700 "$INTERNAL_DIR/cleanup.sh"

say "Retired-artifact cleanup is built into KPM-Update-All; no cleanup files are installed."
say "Manual launchers installed: native bridge export, JavaScript bundle export, experimental Royal Road page-text capture, USB display inspection, and KPM updater."
say "The version-report helper is private; no version-report launcher is installed."
say "The version report is refreshed after KPM exits, not from inside the KPM install hook."
say "No diagnostic, native export, or report upload was executed by installation."
say "Package version: $PACKAGE_VERSION"
say "Installation complete."
