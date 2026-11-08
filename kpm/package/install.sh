#!/bin/sh
# KPM install hook. It writes only to Kindle user storage.
set -e
DOCS="/mnt/us/documents"
LOG="$DOCS/RoyalRoadTools-package.log"
mkdir -p "$DOCS"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

# Atomic replacement lets KPM-Update-All safely upgrade its own launcher.
install_scriptlet() {
  SOURCE="$1"
  DEST="$2"
  TEMP="${DEST}.new.$$"
  say "Installing library item: $(basename "$DEST")"
  cp "$SOURCE" "$TEMP"
  chmod 755 "$TEMP"
  mv -f "$TEMP" "$DEST"
  say "Installed: $(basename "$DEST")"
}

say "Royal Road Kindle Tools — package installation/upgrade started."
install_scriptlet "scriptlets/RoyalRoadTools.sh" "$DOCS/RoyalRoadTools.sh"
install_scriptlet "scriptlets/RR-JS-Smoke-Test.sh" "$DOCS/RR-JS-Smoke-Test.sh"
install_scriptlet "scriptlets/RR-LIPC-Metadata-Check.sh" "$DOCS/RR-LIPC-Metadata-Check.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"
install_scriptlet "scriptlets/KindleBatchPrepareFix.sh" "$DOCS/KindleBatchPrepareFix.sh"
install_scriptlet "scriptlets/KindleBatchPrepareDiagnostics.sh" "$DOCS/KindleBatchPrepareDiagnostics.sh"
install_scriptlet "scriptlets/RR-Upload-Diagnostic.sh" "$DOCS/RR-Upload-Diagnostic.sh"
say "All seven library launchers are installed."

# A busy browser DB does not fail the package install; the launcher can retry.
if [ -f "tools/add-browser-bookmark.sh" ]; then
  say "Checking the Royal Road browser bookmark..."
  if sh "tools/add-browser-bookmark.sh"; then
    say "Bookmark setup check completed."
  else
    say "WARNING: Bookmark setup did not complete. Open RoyalRoadTools in the library to retry."
  fi
fi

say "Royal Road Kindle Tools package setup finished."
