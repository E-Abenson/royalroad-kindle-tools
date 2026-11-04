#!/bin/sh
if [ "$1" = "upgrade" ]; then
  exit 0
fi
ROOT="$(CDPATH= cd "$(dirname "$0")" && pwd)"
if [ -f "$ROOT/tools/remove-browser-bookmark.sh" ]; then
  sh "$ROOT/tools/remove-browser-bookmark.sh" || echo "Could not remove the test bookmark automatically; see package README."
fi
rm -f "/mnt/us/documents/RoyalRoadTools.sh"
echo "Royal Road Kindle Tools removed. Local backup files were kept."
