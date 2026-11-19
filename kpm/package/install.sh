#!/bin/sh
# KPM install hook. Installs manual launchers and prepares the cleanup queue.
# No diagnostic, export, upload, version-report, repair, or cleanup script runs here.
set -e
DOCS="/mnt/us/documents"
QUEUE="$DOCS/RoyalRoadTools-Cleanup-Queue.txt"
COMPLETED="$DOCS/RoyalRoadTools-Cleanup-Completed.txt"
QUEUE_TEMPLATE="scriptlets/RoyalRoadTools-Cleanup-Queue.txt"
INTERNAL_DIR="$DOCS/.royalroadtools"
mkdir -p "$DOCS" "$INTERNAL_DIR"
say() { printf '%s\n' "$*"; }

install_scriptlet() {
  SOURCE="$1"; DEST="$2"; TEMP="$DEST.new.$"
  say "Installing $(basename "$DEST")..."
  cp "$SOURCE" "$TEMP"; chmod 755 "$TEMP"; mv -f "$TEMP" "$DEST"
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
  if [ ! -d "$SOURCE_DIR" ] || [ ! -s "$SOURCE_DIR/SHA256SUMS" ]; then
    say "ERROR: Bundled ScreenLockPin files or SHA256SUMS are missing."
    return 1
  fi
  if ! (cd "$SOURCE_DIR" && sha256sum -c SHA256SUMS); then
    say "ERROR: Bundled ScreenLockPin checksum validation failed."
    return 1
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
  if ! (cd "$TEMP_DIR" && sha256sum -c SHA256SUMS); then
    rm -rf "$TEMP_DIR"
    say "ERROR: Staged ScreenLockPin files failed checksum validation."
    return 1
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


merge_cleanup_queue() {
  [ -f "$QUEUE" ] || printf '%s\n' '# Pending cleanup actions: add TYPE|VALUE entries here.' > "$QUEUE"
  [ -f "$COMPLETED" ] || printf '%s\n' '# Entries successfully removed; do not requeue these.' > "$COMPLETED"
  if [ ! -f "$QUEUE_TEMPLATE" ]; then
    say "WARNING: Cleanup queue template is missing; existing Kindle queue was left unchanged."
    return 0
  fi
  while IFS= read -r ENTRY || [ -n "$ENTRY" ]; do
    case "$ENTRY" in ""|\#*) continue ;; esac
    if ! grep -Fqx "$ENTRY" "$QUEUE" 2>/dev/null &&
       ! grep -Fqx "$ENTRY" "$COMPLETED" 2>/dev/null; then
      printf '%s\n' "$ENTRY" >> "$QUEUE"
      say "Added cleanup task: $ENTRY"
    fi
  done < "$QUEUE_TEMPLATE"
}

requeue_existing_targets() {
  [ -f "$QUEUE_TEMPLATE" ] || return 0
  [ -f "$COMPLETED" ] || : > "$COMPLETED"
  while IFS= read -r ENTRY || [ -n "$ENTRY" ]; do
    case "$ENTRY" in ""|\#*) continue ;; *'|'*) ;; *) continue ;; esac
    ITEM_TYPE="$(printf '%s\n' "$ENTRY" | cut -d '|' -f 1)"
    ITEM_VALUE="$(printf '%s\n' "$ENTRY" | cut -d '|' -f 2-)"
    FOUND=0
    case "$ITEM_TYPE" in
      DOC)
        TARGET="$DOCS/$ITEM_VALUE"
        if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then FOUND=1; fi ;;
      DOCGLOB)
        for TARGET in "$DOCS"/$ITEM_VALUE; do
          if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then FOUND=1; fi
        done ;;
      PKG)
        TARGET="/mnt/us/kmc/kpm/packages/royalroad-kindle-tools/$ITEM_VALUE"
        if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then FOUND=1; fi ;;
      PKGDIR)
        TARGET="/mnt/us/kmc/kpm/packages/royalroad-kindle-tools/$ITEM_VALUE"
        if [ -d "$TARGET" ]; then FOUND=1; fi ;;
      KOREADER_FILE)
        case "$ITEM_VALUE" in
          01_Rav_Zvi_Kushelevsky.png|02_Rav_Osher_Arieli.png|03_Chofetz_Chaim.jpg|SHA256SUMS) TARGET="/mnt/us/koreader-screensavers-inverted/$ITEM_VALUE" ;;
          *) TARGET="" ;;
        esac
        if [ -n "$TARGET" ] && { [ -e "$TARGET" ] || [ -L "$TARGET" ]; }; then FOUND=1; fi ;;
      SLEEP_SCREEN_IMAGE)
        case "$ITEM_VALUE" in
          01_Rav_Zvi_Kushelevsky.png|02_Rav_Osher_Arieli.png) TARGET="/mnt/us/screensavers/$ITEM_VALUE" ;;
          *) TARGET="" ;;
        esac
        if [ -n "$TARGET" ] && { [ -e "$TARGET" ] || [ -L "$TARGET" ]; }; then FOUND=1; fi ;;
      KOREADER_IMAGE_DIR)
        if [ "$ITEM_VALUE" = "koreader-screensavers-inverted" ] && [ -d "/mnt/us/koreader-screensavers-inverted" ]; then FOUND=1; fi ;;
      REMOTE_DELETE)
        if [ -s "$DOCS/$ITEM_VALUE" ]; then FOUND=1; fi ;;
      BOOKMARK)
        if [ "$ITEM_VALUE" = "Royal Road Session Test" ]; then
          if [ -f "/var/local/KPPBrowser.db" ] && command -v sqlite3 >/dev/null 2>&1; then
            BOOKMARK_COUNT="$(sqlite3 -cmd '.timeout 5000' "/var/local/KPPBrowser.db" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" 2>/dev/null)"
            case "$BOOKMARK_COUNT" in
              0) FOUND=0 ;;
              ''|*[!0-9]*) FOUND=1 ;;
              *) [ "$BOOKMARK_COUNT" -gt 0 ] && FOUND=1 ;;
            esac
          else
            FOUND=1
          fi
        fi ;;
    esac
    if [ "$FOUND" -eq 1 ]; then
      TEMP="$COMPLETED.new.$$"
      grep -Fvx "$ENTRY" "$COMPLETED" > "$TEMP" 2>/dev/null || true
      mv -f "$TEMP" "$COMPLETED"
      if ! grep -Fqx "$ENTRY" "$QUEUE" 2>/dev/null; then
        printf '%s\n' "$ENTRY" >> "$QUEUE"
        say "Re-queued existing retired item: $ENTRY"
      fi
    fi
  done < "$QUEUE_TEMPLATE"
}

say "Royal Road Kindle Tools — installing current toolset."
install_scriptlet "scriptlets/KPP-Native-Bridge-Export.sh" "$DOCS/KPP-Native-Bridge-Export.sh"
install_scriptlet "scriptlets/KPP-JavaScript-Bundle-Export.sh" "$DOCS/KPP-JavaScript-Bundle-Export.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"

install_scriptlet "scriptlets/Inspect-USB-Screen.sh" "$DOCS/Inspect-USB-Screen.sh"
install_scriptlet "scriptlets/KindleBatchPrepareFix.sh" "$DOCS/KindleBatchPrepareFix.sh"
install_scriptlet "scriptlets/RoyalRoadTools-Version-Info.sh" "$INTERNAL_DIR/version-info.sh"

# Private cleaner: invoked by KPM-Update-All after successful package upgrades.
install_scriptlet "scriptlets/RoyalRoadTools-Cleanup.sh" "$INTERNAL_DIR/cleanup.sh"
rm -f "$DOCS/RoyalRoadTools-Cleanup.sh"
rm -f "$DOCS/RR-KPP-Bytecode-Export.sh" "$DOCS/Install-Rabbinic-Screensavers.sh"
rm -f "$INTERNAL_DIR/inspector-upload.sh" "$INTERNAL_DIR/bytecode-export.sh"
# The previous URL test is complete; remove its privately saved URL too.
rm -f "$INTERNAL_DIR/last-open-page-private.txt"
rm -f "$DOCS/Kindle-Version-Report.sh" "$DOCS/RoyalRoadTools-Version-Info.sh"

merge_cleanup_queue
requeue_existing_targets

# The new exporter reuses the USB-visible HBC filename. Remove any stale
# pending deletion instruction left by the retired one-time exporter.
remove_pending_cleanup_entry() {
  ENTRY="$1"
  [ -f "$QUEUE" ] || return 0
  TEMP="$QUEUE.new.$"
  grep -Fvx "$ENTRY" "$QUEUE" > "$TEMP" 2>/dev/null || true
  mv -f "$TEMP" "$QUEUE"
}
remove_pending_cleanup_entry "DOC|KPPMainApp.js.hbc"

install_screenlockpin_plugin

SOURCE_TEMP="$DOCS/KindleBatchPrepare-main.lua.gz.new.$"
cp "files/kindle_batch_prepare_main.lua.gz" "$SOURCE_TEMP"
chmod 644 "$SOURCE_TEMP"
mv -f "$SOURCE_TEMP" "$DOCS/KindleBatchPrepare-main.lua.gz"

PACKAGE_VERSION="$(awk '
  index($0, "\"version\"") {
    if (getline > 0) { gsub(/[^0-9]/, ""); a=$0 }
    if (getline > 0) { gsub(/[^0-9]/, ""); b=$0 }
    if (getline > 0) { gsub(/[^0-9]/, ""); c=$0 }
    if (a != "" && b != "" && c != "") print a "." b "." c
    exit
  }
' manifest.json)"
[ -n "$PACKAGE_VERSION" ] || PACKAGE_VERSION="unknown"
{
  printf 'version=%s\n' "$PACKAGE_VERSION"
  printf 'installed_at=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
} > "$DOCS/.RoyalRoadTools-installed-version.txt"
chmod 600 "$DOCS/.RoyalRoadTools-installed-version.txt" 2>/dev/null || true

say "Cleanup runner installed privately at $INTERNAL_DIR/cleanup.sh."
say "It runs automatically only when KPM-Update-All completes successfully."
say "Manual launchers installed: native bridge export, JavaScript bundle export, USB display inspection, KPM updater, and plugin repair."
say "The version-report helper is private; no version-report launcher is installed."
if sh "$INTERNAL_DIR/version-info.sh"; then
  say "SUCCESS — Kindle-Version-Report.txt was regenerated."
else
  say "WARNING — package installed, but version report regeneration failed."
fi
say "No diagnostic, native export, or report upload was executed by installation."
say "Package version: $PACKAGE_VERSION"
say "Installation complete."
