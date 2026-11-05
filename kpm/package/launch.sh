#!/bin/sh
ROOT="$(CDPATH= cd "$(dirname "$0")" && pwd)"
DOCS="/mnt/us/documents"
LOG="$DOCS/RoyalRoadTools-launch.log"
mkdir -p "$DOCS"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

say "Royal Road Tools — opening bookmark updater..."
if [ ! -f "$ROOT/tools/add-browser-bookmark.sh" ]; then
  say "ERROR: Bookmark installer is missing from the package."
  exit 1
fi
if sh "$ROOT/tools/add-browser-bookmark.sh"; then
  say "SUCCESS: Bookmark updater finished."
else
  RESULT=$?
  say "ERROR: Bookmark updater failed (exit code $RESULT)."
  exit "$RESULT"
fi
