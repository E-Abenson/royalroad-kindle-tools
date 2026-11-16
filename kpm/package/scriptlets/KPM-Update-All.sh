#!/bin/sh
# One-tap KPM repository refresh, automatic screensaver installation/upgrade,
# package upgrades, and automatic cleanup. Other tools remain manual launchers.

KPM="/var/local/kmc/bin/kpm"
DOCS="/mnt/us/documents"
LOG="$DOCS/KPM-Update-All.log"
CLEANUP="$DOCS/.royalroadtools/cleanup.sh"
VERSION_REPORT="$DOCS/.royalroadtools/version-info.sh"

# Official third-party repository for Kindle Custom Screensaver.
SCREENSAVER_REPO="https://kpm.andrecheng.com/kpm.json"
SCREENSAVER_PACKAGE="custom-screensaver"
SCREENSAVER_APP_DIR="/mnt/us/extensions/custom-screensaver"
SCREENSAVER_SCRIPTLET="$DOCS/Custom Screensaver.sh"

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
say "STEP 1 OF 4 — Ensuring the Custom Screensaver repository is registered..."
SCREENSAVER_REPO_READY=0

if "$KPM" list-repo 2>&1 | grep -F "$SCREENSAVER_REPO" >/dev/null 2>&1; then
  SCREENSAVER_REPO_READY=1
  say "Custom Screensaver repository is already registered."
else
  if run_and_show "$KPM" add-repo "$SCREENSAVER_REPO"; then
    SCREENSAVER_REPO_READY=1
    say "Custom Screensaver repository added."
  elif "$KPM" list-repo 2>&1 | grep -F "$SCREENSAVER_REPO" >/dev/null 2>&1; then
    # Treat an "already registered" response as success.
    SCREENSAVER_REPO_READY=1
    say "Custom Screensaver repository is registered; continuing."
  else
    say "WARNING — could not register the Custom Screensaver repository."
    say "The normal KPM update will continue; screensaver installation will be skipped."
  fi
fi

say ""
say "STEP 2 OF 4 — Refreshing package repositories..."
if run_and_show "$KPM" update; then
  say "STEP 2 COMPLETE — repository refresh succeeded."
else
  RESULT=$?
  say "ERROR — KPM repository refresh failed (exit code $RESULT)."
  say "Package upgrades and cleanup were skipped. Check Wi-Fi and the log."
  exit "$RESULT"
fi

say ""
say "STEP 3 OF 4 — Checking the Custom Screensaver installation..."
if [ "$SCREENSAVER_REPO_READY" -eq 1 ]; then
  if [ -x "$SCREENSAVER_APP_DIR/custom_ss_daemon.sh" ] &&
     [ -f "$SCREENSAVER_SCRIPTLET" ]; then
    say "Custom Screensaver is already installed."
    say "Any newer release will be applied by the normal KPM upgrade step."
  else
    say "Custom Screensaver is missing or incomplete; installing it now."
    if run_and_show "$KPM" -y install "$SCREENSAVER_PACKAGE"; then
      say "SUCCESS — Custom Screensaver package installed."
    else
      INSTALL_RESULT=$?
      say "WARNING — Custom Screensaver installation failed (exit code $INSTALL_RESULT)."
      say "Other installed KPM packages will still be upgraded."
    fi
  fi
else
  say "WARNING — screensaver install skipped because its repository is unavailable."
fi

say ""
say "STEP 4 OF 4 — Upgrading installed KPM packages..."
say "Automatic confirmation is enabled."
if run_and_show "$KPM" -y upgrade; then
  say "SUCCESS — KPM upgrade completed."
  say "All available upgrades have been processed."

  say ""
  say "STEP 5 — Running the automatic cleanup queue..."
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
  say "STEP 6 — Regenerating the Kindle software version report..."
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
