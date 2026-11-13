#!/bin/sh
# KPM install hook. Installs launchers and prepares the cleanup queue.
# No diagnostic, export, upload, version-report, repair, or cleanup script is run here.
set -e
DOCS="/mnt/us/documents"
QUEUE="$DOCS/RoyalRoadTools-Cleanup-Queue.txt"
COMPLETED="$DOCS/RoyalRoadTools-Cleanup-Completed.txt"
QUEUE_TEMPLATE="scriptlets/RoyalRoadTools-Cleanup-Queue.txt"
INTERNAL_DIR="$DOCS/.royalroadtools"
mkdir -p "$DOCS" "$INTERNAL_DIR"

say() { printf '%s\n' "$*"; }

install_scriptlet() {
  SOURCE="$1"
  DEST="$2"
  TEMP="$DEST.new.$$"
  say "Installing $(basename "$DEST")..."
  cp "$SOURCE" "$TEMP"
  chmod 755 "$TEMP"
  mv -f "$TEMP" "$DEST"
}

merge_cleanup_queue() {
  [ -f "$QUEUE" ] || printf '%s\n' '# Pending cleanup actions: add TYPE|VALUE entries here.' > "$QUEUE"
  [ -f "$COMPLETED" ] || printf '%s\n' '# Entries successfully removed; do not requeue these.' > "$COMPLETED"

  if [ ! -f "$QUEUE_TEMPLATE" ]; then
    say "WARNING: Cleanup queue template is missing; existing Kindle queue was left unchanged."
    return 0
  fi

  while IFS= read -r ENTRY || [ -n "$ENTRY" ]; do
    case "$ENTRY" in
      ""|\#*) continue ;;
    esac
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
    case "$ENTRY" in
      ""|\#*) continue ;;
      *'|'*) ;;
      *) continue ;;
    esac

    ITEM_TYPE="$(printf '%s\n' "$ENTRY" | cut -d '|' -f 1)"
    ITEM_VALUE="$(printf '%s\n' "$ENTRY" | cut -d '|' -f 2-)"
    FOUND=0

    case "$ITEM_TYPE" in
      DOC)
        TARGET="$DOCS/$ITEM_VALUE"
        if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then FOUND=1; fi
        ;;
      DOCGLOB)
        for TARGET in "$DOCS"/$ITEM_VALUE; do
          if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then FOUND=1; fi
        done
        ;;
      PKG)
        TARGET="/mnt/us/kmc/kpm/packages/royalroad-kindle-tools/$ITEM_VALUE"
        if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then FOUND=1; fi
        ;;
      PKGDIR)
        TARGET="/mnt/us/kmc/kpm/packages/royalroad-kindle-tools/$ITEM_VALUE"
        if [ -d "$TARGET" ]; then FOUND=1; fi
        ;;
      REMOTE_DELETE)
        if [ -s "$DOCS/$ITEM_VALUE" ]; then FOUND=1; fi
        ;;
    esac

    if [ "$FOUND" -eq 1 ]; then
      # Do not trust a stale completion record when the retired target exists.
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

# User-facing tools are installed as manual Kindle launchers.
# The Kindle-side interface inspector and report uploader are retired.
# Do not reinstall these launchers; the queue removes previous copies.
install_scriptlet "scriptlets/RR-KPP-Bytecode-Export.sh" "$DOCS/RR-KPP-Bytecode-Export.sh"
install_scriptlet "scriptlets/KPP-Comprehensive-Diagnostic.sh" "$DOCS/KPP-Comprehensive-Diagnostic.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"
install_scriptlet "scriptlets/KindleBatchPrepareFix.sh" "$DOCS/KindleBatchPrepareFix.sh"
install_scriptlet "scriptlets/RoyalRoadTools-Version-Info.sh" "$INTERNAL_DIR/version-info.sh"

# The cleanup runner is deliberately hidden and is called by KPM-Update-All.
install_scriptlet "scriptlets/RoyalRoadTools-Cleanup.sh" "$INTERNAL_DIR/cleanup.sh"
rm -f "$DOCS/RoyalRoadTools-Cleanup.sh"
rm -f "$INTERNAL_DIR/inspector-upload.sh" "$INTERNAL_DIR/bytecode-export.sh"
# Retire the old public version-report launcher; the report is refreshed by Update All.
rm -f "$DOCS/Kindle-Version-Report.sh" "$DOCS/RoyalRoadTools-Version-Info.sh"

merge_cleanup_queue
# If a retired item still exists, re-queue it even if an older run marked it
# complete. This catches files recreated by an earlier package installer.
requeue_existing_targets

# Bundle the source used by KindleBatchPrepareFix so repairs work offline.
SOURCE_TEMP="$DOCS/KindleBatchPrepare-main.lua.gz.new.$$"
cp "files/kindle_batch_prepare_main.lua.gz" "$SOURCE_TEMP"
chmod 644 "$SOURCE_TEMP"
mv -f "$SOURCE_TEMP" "$DOCS/KindleBatchPrepare-main.lua.gz"

PACKAGE_VERSION="$(awk '
  /"version"[[:space:]]*:/ {
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
say "It will run automatically only when KPM-Update-All completes successfully."
say "Manual launchers installed: one-run KPP diagnostic, one-time bytecode export, KPM updater, and plugin repair."
say "The version-report helper is private; no version-report launcher is installed."
say "Refreshing the version report after package installation..."
if sh "$INTERNAL_DIR/version-info.sh"; then
  say "SUCCESS — Kindle-Version-Report.txt was regenerated."
else
  say "WARNING — package installation succeeded, but the version report could not be regenerated."
fi
say "No diagnostic, bundle export, or report upload was executed by this package installation."
say "Package version: $PACKAGE_VERSION"
say "Installation complete."
