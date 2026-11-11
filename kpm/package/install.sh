#!/bin/sh
# KPM install hook. Installs the active tools and merges the persistent cleanup queue.
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

say "Royal Road Kindle Tools — installing current toolset."
install_scriptlet "scriptlets/RR-KPP-Interface-Inspector.sh" "$DOCS/RR-KPP-Interface-Inspector.sh"
install_scriptlet "scriptlets/RR-KPP-Interface-Inspector-Upload.sh" "$INTERNAL_DIR/inspector-upload.sh"
install_scriptlet "scriptlets/RoyalRoadTools-Cleanup.sh" "$DOCS/RoyalRoadTools-Cleanup.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"
install_scriptlet "scriptlets/KindleBatchPrepareFix.sh" "$DOCS/KindleBatchPrepareFix.sh"
install_scriptlet "scriptlets/RoyalRoadTools-Version-Info.sh" "$INTERNAL_DIR/version-info.sh"
install_scriptlet "scriptlets/RR-KPP-Bytecode-Export.sh" "$INTERNAL_DIR/bytecode-export.sh"

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

say "Running the KPP interface inspection automatically..."
if sh "$DOCS/RR-KPP-Interface-Inspector.sh"; then
  say "KPP interface inspection completed."
else
  say "WARNING: KPP interface inspection did not complete; the package installation remains valid."
fi

say "Creating a private local copy of the KPP Hermes bundle..."
if sh "$INTERNAL_DIR/bytecode-export.sh"; then
  say "KPP bytecode export step completed."
else
  say "WARNING: KPP bytecode export failed; the package installation remains valid."
fi

say "Publishing the sanitised inspector report to pasters.io (one-day expiry)..."
if sh "$INTERNAL_DIR/inspector-upload.sh"; then
  say "Inspector report upload completed."
else
  say "WARNING: Inspector report upload failed; the local report remains available."
fi

say "Refreshing the Kindle software version report automatically..."
if sh "$INTERNAL_DIR/version-info.sh"; then
  say "Version report regenerated; no manual version-report launcher is installed."
else
  say "WARNING: Automatic version report generation failed."
fi

say "Installed the read-only KPP inspector, automatic private bytecode export, optional one-day inspector-report upload, persistent cleanup, automatic version report and KOReader repair tool."
say "Package version: $PACKAGE_VERSION"
say "Installation complete."
