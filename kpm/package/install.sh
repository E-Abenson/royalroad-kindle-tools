#!/bin/sh
# KPM install hook. It writes only to the user storage partition.
set -e
DOCS="/mnt/us/documents"
mkdir -p "$DOCS"
cp "scriptlets/RoyalRoadTools.sh" "$DOCS/RoyalRoadTools.sh"
chmod 755 "$DOCS/RoyalRoadTools.sh"
echo "Royal Road Kindle Tools installed."
echo "Open the RoyalRoadTools item in the Kindle library once to add the browser test bookmark."
