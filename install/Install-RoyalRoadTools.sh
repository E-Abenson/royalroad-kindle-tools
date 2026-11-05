#!/bin/sh
# Name: Install Royal Road Kindle Tools
# Author: E-Abenson
# One-time Kindle bootstrap. Run this as a Kindle .sh scriptlet.
# Calling kpm directly avoids the search-bar parser rejecting URL punctuation.

KPM="/var/local/kmc/bin/kpm"
REPO_URL="https://raw.githubusercontent.com/E-Abenson/royalroad-kindle-tools/main/kpm-repo/manifest.json"
LOG="/mnt/us/documents/RoyalRoadTools-install.log"

mkdir -p "/mnt/us/documents"
exec >> "$LOG" 2>&1

echo "=== Royal Road Kindle Tools bootstrap: $(date) ==="

# Display a short native Kindle alert as well as keeping the full details in
# the log. The alert is dismissed after 10 seconds (or by the user tapping OK).
screen_alert() {
  ALERT_TITLE=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')
  ALERT_TEXT=$(printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g')

  if ! command -v lipc-set-prop >/dev/null 2>&1; then
    echo "WARNING: Kindle alert service unavailable; see $LOG"
    return 0
  fi

  ALERT_JSON=$(printf '{"clientParams":{"alertId":"appAlert1","show":true,"customStrings":[{"matchStr":"alertTitle","replaceStr":"%s"},{"matchStr":"alertText","replaceStr":"%s"}]}}' "$ALERT_TITLE" "$ALERT_TEXT")

  if lipc-set-prop com.lab126.pillow pillowAlert "$ALERT_JSON" >/dev/null 2>&1; then
    sleep 10
    lipc-set-prop com.lab126.pillow pillowAlert '{"clientParams":{"alertId":"appAlert1","show":false}}' >/dev/null 2>&1 || true
  else
    echo "WARNING: Could not display Kindle alert; see $LOG"
  fi
}

finish() {
  EXIT_CODE="$1"
  TITLE="$2"
  MESSAGE="$3"
  echo "$TITLE: $MESSAGE"
  screen_alert "$TITLE" "$MESSAGE"
  exit "$EXIT_CODE"
}

if [ ! -x "$KPM" ]; then
  finish 1 "Installation failed" "KPM was not found. Install or repair KPM first."
fi

echo "Adding the project KPM repository..."
"$KPM" add-repo "$REPO_URL" || echo "Repository may already be registered; continuing to refresh."

echo "Refreshing package index..."
if ! "$KPM" update; then
  finish 1 "Installation failed" "KPM could not refresh the package list. Check Wi-Fi and the install log."
fi

echo "Installing Royal Road Kindle Tools..."
if ! "$KPM" install royalroad-kindle-tools; then
  finish 1 "Installation failed" "KPM could not install the package. Check Wi-Fi and the install log."
fi

finish 0 "Installation successful" "Royal Road Tools installed. Open RoyalRoadTools in your library to add the test bookmark."
