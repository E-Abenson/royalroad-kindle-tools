#!/bin/sh
# One-tap KPM repository refresh and package upgrade.
# Installed as a Kindle library scriptlet by Royal Road Kindle Tools.

KPM="/var/local/kmc/bin/kpm"
DOCS="/mnt/us/documents"
LOG="$DOCS/KPM-Update-All.log"

mkdir -p "$DOCS"
exec >> "$LOG" 2>&1

echo
echo "============================================================"
echo "KPM UPDATE ALL — $(date)"
echo "============================================================"

if [ ! -x "$KPM" ]; then
  echo "ERROR: KPM executable not found at $KPM"
  echo "No update was run."
  exit 1
fi

echo
echo "STEP 1/2: Refreshing package repositories..."
if "$KPM" update; then
  echo "Repository refresh completed."
else
  RESULT=$?
  echo "ERROR: KPM update failed (exit code $RESULT)."
  echo "Package upgrade was not attempted."
  echo "See this log: $LOG"
  exit "$RESULT"
fi

echo
echo "STEP 2/2: Upgrading installed KPM packages..."
if "$KPM" -y upgrade; then
  echo "SUCCESS: KPM upgrade command completed."
  echo "All available upgrades were applied."
  echo "Finished: $(date)"
  exit 0
else
  RESULT=$?
  echo "ERROR: KPM upgrade failed (exit code $RESULT)."
  echo "Finished: $(date)"
  echo "See this log: $LOG"
  exit "$RESULT"
fi
