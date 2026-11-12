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

remove_pending_cleanup_entry() {
  ENTRY="$1"
  [ -f "$QUEUE" ] || return 0
  TEMP="$QUEUE.new.$$"
  awk -v target="$ENTRY" '$0 != target' "$QUEUE" > "$TEMP"
  mv -f "$TEMP" "$QUEUE"
}

say "Royal Road Kindle Tools — installing current toolset."

# User-facing tools are installed as manual Kindle launchers.
install_scriptlet "scriptlets/RR-KPP-Interface-Inspector.sh" "$DOCS/RR-KPP-Interface-Inspector.sh"
install_scriptlet "scriptlets/RR-KPP-Interface-Inspector-Upload.sh" "$DOCS/RR-KPP-Interface-Inspector-Upload.sh"
install_scriptlet "scriptlets/RR-KPP-Bytecode-Export.sh" "$DOCS/RR-KPP-Bytecode-Export.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"
install_scriptlet "scriptlets/KindleBatchPrepareFix.sh" "$DOCS/KindleBatchPrepareFix.sh"
install_scriptlet "scriptlets/RoyalRoadTools-Version-Info.sh" "$DOCS/Kindle-Version-Report.sh"

# The cleanup runner is deliberately hidden and is called by KPM-Update-All.
install_scriptlet "scriptlets/RoyalRoadTools-Cleanup.sh" "$INTERNAL_DIR/cleanup.sh"
rm -f "$DOCS/RoyalRoadTools-Cleanup.sh"
rm -f "$INTERNAL_DIR/inspector-upload.sh" "$INTERNAL_DIR/bytecode-export.sh" "$INTERNAL_DIR/version-info.sh"

merge_cleanup_queue
# An earlier release queued this now-manual launcher for deletion. Remove that
# stale pending instruction before the next Update All cleanup can run.
remove_pending_cleanup_entry "DOC|RR-KPP-Interface-Inspector-Upload.sh"

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
say "Manual launchers installed: KPP inspector, optional report upload, bytecode export, version report, KPM updater, and plugin repair."
say "No diagnostic or maintenance script was executed by this package installation."
say "Package version: $PACKAGE_VERSION"
say "Installation complete."
