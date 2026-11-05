#!/bin/sh
# KPM install hook. It writes only to the user storage partition.
set -e
DOCS="/mnt/us/documents"
mkdir -p "$DOCS"
cp "scriptlets/RoyalRoadTools.sh" "$DOCS/RoyalRoadTools.sh"
chmod 755 "$DOCS/RoyalRoadTools.sh"
cp "scriptlets/RR-JS-Smoke-Test.sh" "$DOCS/RR-JS-Smoke-Test.sh"
chmod 755 "$DOCS/RR-JS-Smoke-Test.sh"
echo "Royal Road Kindle Tools installed."
# Attempt the one safe, backup-first bookmark setup now. A busy browser DB
# does not fail the package install; the library scriptlet can retry later.
if [ -f "tools/add-browser-bookmark.sh" ]; then
  sh "tools/add-browser-bookmark.sh" || echo "Browser bookmark was not added now; open RoyalRoadTools in the library to retry."
fi
