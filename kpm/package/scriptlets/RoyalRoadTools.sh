#!/bin/sh
# Name: RoyalRoadTools
# Author: E-Abenson
# Launches the Royal Road Kindle Tools package with visible progress.
# sh_integration sends stdout/stderr to the Kindle display.

KPM="/var/local/kmc/bin/kpm"
DOCS="/mnt/us/documents"
LOG="$DOCS/RoyalRoadTools-launch.log"
mkdir -p "$DOCS"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

run_and_show() {
  STATUS_FILE="$DOCS/.RoyalRoadTools-launch-status.$$"
  rm -f "$STATUS_FILE"
  (
    "$@"
    COMMAND_STATUS=$?
    printf '%s\n' "$COMMAND_STATUS" > "$STATUS_FILE"
    exit "$COMMAND_STATUS"
  ) 2>&1 | tee -a "$LOG"

  if [ -f "$STATUS_FILE" ]; then
    COMMAND_STATUS="$(cat "$STATUS_FILE" 2>/dev/null)"
  else
    COMMAND_STATUS=1
    say "ERROR: The package launcher ended without returning a status."
  fi
  rm -f "$STATUS_FILE"
  return "$COMMAND_STATUS"
}

say "Royal Road Kindle Tools — starting bookmark setup."
if [ ! -x "$KPM" ]; then
  say "ERROR: KPM executable not found at $KPM"
  exit 1
fi

if run_and_show "$KPM" launch royalroad-kindle-tools; then
  say "SUCCESS — bookmark setup finished."
  say "You can now return to the browser and use Royal Road Session Test."
  exit 0
else
  RESULT=$?
  say "ERROR — bookmark setup failed (exit code $RESULT)."
  say "See $LOG for the output."
  exit "$RESULT"
fi
