#!/bin/sh
# KPM install hook. Installs the active tools and merges the persistent cleanup queue.
set -e
DOCS="/mnt/us/documents"
QUEUE="$DOCS/RoyalRoadTools-Cleanup-Queue.txt"
COMPLETED="$DOCS/RoyalRoadTools-Cleanup-Completed.txt"
QUEUE_TEMPLATE="scriptlets/RoyalRoadTools-Cleanup-Queue.txt"
mkdir -p "$DOCS"

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

say "Royal Road Kindle Tools — installing current toolset."
install_scriptlet "scriptlets/RR-KPP-Interface-Inspector.sh" "$DOCS/RR-KPP-Interface-Inspector.sh"
install_scriptlet "scriptlets/RR-KPP-Interface-Inspector-Upload.sh" "$DOCS/RR-KPP-Interface-Inspector-Upload.sh"
install_scriptlet "scriptlets/RoyalRoadTools-Cleanup.sh" "$DOCS/RoyalRoadTools-Cleanup.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"
install_scriptlet "scriptlets/KindleBatchPrepareFix.sh" "$DOCS/KindleBatchPrepareFix.sh"
install_scriptlet "scriptlets/RoyalRoadTools-Version-Info.sh" "$DOCS/RoyalRoadTools-Version-Info.sh"

merge_cleanup_queue

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

say "Running cleanup automatically as part of this package install/update..."
if sh "$DOCS/RoyalRoadTools-Cleanup.sh"; then
  say "Cleanup queue processed successfully."
else
  say "Cleanup left one or more items pending. They remain in the queue for retry."
fi

say "Installed the read-only KPP interface inspector, separate optional pasters.io upload launcher, persistent cleanup queue, version report, KPM updater and KOReader repair tool."
say "Package version: $PACKAGE_VERSION"
say "Installation complete."
