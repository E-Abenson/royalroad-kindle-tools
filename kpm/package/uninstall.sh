#!/bin/sh
DOCS="/mnt/us/documents"
LOG="$DOCS/RoyalRoadTools-package.log"
mkdir -p "$DOCS"
say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

if [ "$1" = "upgrade" ]; then
  say "KPM is upgrading this package; preserving the existing library launchers during the transition."
  exit 0
fi

say "Royal Road Kindle Tools — uninstall started."
ROOT="$(CDPATH= cd "$(dirname "$0")" && pwd)"
if [ -f "$ROOT/tools/remove-browser-bookmark.sh" ]; then
  say "Removing the package's exact browser bookmark..."
  if sh "$ROOT/tools/remove-browser-bookmark.sh"; then
    say "Bookmark removal check completed."
  else
    say "WARNING: Could not remove the bookmark automatically; see $LOG."
  fi
fi

for ITEM in RoyalRoadTools.sh RR-JS-Smoke-Test.sh KPM-Update-All.sh; do
  if [ -f "$DOCS/$ITEM" ]; then
    say "Removing library item: $ITEM"
    rm -f "$DOCS/$ITEM"
  fi
done

say "Royal Road Kindle Tools removed. Local backup and log files were kept."
