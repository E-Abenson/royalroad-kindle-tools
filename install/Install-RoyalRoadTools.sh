#!/bin/sh
# Name: Install Royal Road Kindle Tools
# Author: E-Abenson
# One-time Kindle bootstrap. Run this as a Kindle .sh scriptlet.
# sh_integration displays stdout/stderr through FBInk. Output is also logged.

KPM="/var/local/kmc/bin/kpm"
REPO_URL="https://raw.githubusercontent.com/E-Abenson/royalroad-kindle-tools/main/kpm-repo/manifest.json"
DOCS="/mnt/us/documents"
LOG="$DOCS/RoyalRoadTools-install.log"

mkdir -p "$DOCS"
: >> "$LOG"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

run_and_show() {
  STATUS_FILE="$DOCS/.RoyalRoadTools-install-status.$$"
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
    say "ERROR: The KPM command ended without returning a status."
  fi
  rm -f "$STATUS_FILE"
  return "$COMMAND_STATUS"
}

finish() {
  EXIT_CODE="$1"
  TITLE="$2"
  MESSAGE="$3"
  say "$TITLE"
  say "$MESSAGE"
  say "Full output saved to $LOG"
  exit "$EXIT_CODE"
}

say "============================================================"
say "ROYAL ROAD KINDLE TOOLS — INSTALLER"
say "Starting at $(date)"
say "Progress will appear on this screen and be saved to $LOG."

if [ ! -x "$KPM" ]; then
  finish 1 "INSTALLATION FAILED" "KPM was not found at $KPM. Install or repair KPM first."
fi

say ""
say "STEP 1 — Registering the Royal Road KPM repository..."
if run_and_show "$KPM" add-repo "$REPO_URL"; then
  say "Repository registration completed."
else
  say "Repository add command returned a nonzero status; it may already be registered."
  say "Continuing to refresh the package index."
fi

say ""
say "STEP 2 — Refreshing the KPM package index..."
if ! run_and_show "$KPM" update; then
  RESULT=$?
  finish 1 "INSTALLATION FAILED" "KPM could not refresh the package list. Check Wi-Fi and the log."
fi

say ""
say "STEP 3 — Installing Royal Road Kindle Tools..."
if run_and_show "$KPM" install royalroad-kindle-tools; then
  finish 0 "INSTALLATION SUCCESSFUL" "Royal Road Tools is installed. Open RoyalRoadTools in your Kindle library."
else
  RESULT=$?
  finish "$RESULT" "INSTALLATION FAILED" "KPM could not install the package. Check Wi-Fi and the log."
fi
