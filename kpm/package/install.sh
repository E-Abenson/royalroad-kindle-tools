#!/bin/sh
# KPM install hook. It writes only to the user storage partition.
set -e
DOCS="/mnt/us/documents"
mkdir -p "$DOCS"

# Install by atomic replacement. This matters when KPM-Update-All is
# currently running and upgrades this package: the running shell keeps
# its original file while the new launcher replaces it for next time.
install_scriptlet() {
  SOURCE="$1"
  DEST="$2"
  TEMP="${DEST}.new.$$"
  cp "$SOURCE" "$TEMP"
  chmod 755 "$TEMP"
  mv -f "$TEMP" "$DEST"
}

install_scriptlet "scriptlets/RoyalRoadTools.sh" "$DOCS/RoyalRoadTools.sh"
install_scriptlet "scriptlets/RR-JS-Smoke-Test.sh" "$DOCS/RR-JS-Smoke-Test.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"

echo "Royal Road Kindle Tools installed; three library scriptlets are up to date."
# Attempt the one safe, backup-first bookmark setup now. A busy browser DB
# does not fail the package install; the library scriptlet can retry later.
if [ -f "tools/add-browser-bookmark.sh" ]; then
  sh "tools/add-browser-bookmark.sh" || echo "Browser bookmark was not added now; open RoyalRoadTools in the library to retry."
fi
