#!/bin/sh
# One-tap KPM repository refresh, package upgrade, and automatic cleanup.
# Other tools remain manual launchers and are never started by this script.

KPM="/var/local/kmc/bin/kpm"
DOCS="/mnt/us/documents"
LOG="$DOCS/KPM-Update-All.log"
CLEANUP="$DOCS/.royalroadtools/cleanup.sh"
VERSION_REPORT="$DOCS/.royalroadtools/version-info.sh"

mkdir -p "$DOCS"
: > "$LOG"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

# Run a command with live output on screen and in the log, while preserving
# the command's actual exit status (a plain tee pipeline would hide it).
run_and_show() {
  STATUS_FILE="$DOCS/.KPM-Update-All-status.$$"
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
    say "ERROR: The command ended without returning a status."
  fi
  rm -f "$STATUS_FILE"
  return "$COMMAND_STATUS"
}

say "============================================================"
say "KPM UPDATE ALL — starting"
say "Device time: $(date)"
say "Progress will appear here and be saved to $LOG."

if [ ! -x "$KPM" ]; then
  say "ERROR: KPM executable not found at $KPM"
  say "No update was run."
  exit 1
fi

say ""
say "STEP 1 OF 2 — Refreshing package repositories..."
if run_and_show "$KPM" update; then
  say "STEP 1 COMPLETE — repository refresh succeeded."
else
  RESULT=$?
  say "ERROR — KPM repository refresh failed (exit code $RESULT)."
  say "STEP 2 was skipped. Check Wi-Fi and the log."
  exit "$RESULT"
fi

say ""
say "STEP 2 OF 2 — Upgrading installed KPM packages..."
say "Automatic confirmation is enabled."
if run_and_show "$KPM" -y upgrade; then
  say "SUCCESS — KPM upgrade completed."
  say "All available upgrades have been processed."

  say ""
  say "STEP 3 — Running the automatic cleanup queue..."
  if [ -x "$CLEANUP" ]; then
    if run_and_show sh "$CLEANUP"; then
      say "SUCCESS — cleanup completed; no pending items remain."
    else
      CLEANUP_RESULT=$?
      say "WARNING — cleanup has pending or unverifiable items (exit code $CLEANUP_RESULT)."
      say "They remain queued for the next KPM-Update-All run."
      say "See $DOCS/RoyalRoadTools-Cleanup.log"
    fi
  else
    say "WARNING — private cleanup runner is missing: $CLEANUP"
    say "Run KPM-Update-All again after reinstalling the Royal Road Kindle Tools package."
  fi

  say ""
  say "STEP 4 — Regenerating the Kindle software version report..."
  if [ -x "$VERSION_REPORT" ]; then
    if run_and_show sh "$VERSION_REPORT"; then
      say "SUCCESS — Kindle-Version-Report.txt was regenerated and replaced."
    else
      REPORT_RESULT=$?
      say "WARNING — package upgrade and cleanup completed, but version report refresh failed (exit code $REPORT_RESULT)."
    fi
  else
    say "WARNING — internal version-report helper is missing: $VERSION_REPORT"
  fi

  say "Finished: $(date)"
  exit 0
else
  RESULT=$?
  say "ERROR — KPM upgrade failed (exit code $RESULT)."
  say "Cleanup was not run because the package upgrade did not complete successfully."
  say "Finished: $(date)"
  exit "$RESULT"
fi
