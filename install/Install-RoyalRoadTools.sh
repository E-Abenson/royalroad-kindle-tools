#!/bin/sh
# One-time Kindle bootstrap. Run this as a Kindle .sh scriptlet.
# Calling kpm directly avoids the search-bar parser rejecting URL punctuation.
KPM="/var/local/kmc/bin/kpm"
REPO_URL="https://raw.githubusercontent.com/E-Abenson/royalroad-kindle-tools/main/kpm-repo/manifest.json"
LOG="/mnt/us/documents/RoyalRoadTools-install.log"
mkdir -p "/mnt/us/documents"
exec >> "$LOG" 2>&1
echo "=== Royal Road Kindle Tools bootstrap: $(date) ==="
if [ ! -x "$KPM" ]; then
  echo "ERROR: KPM was not found at $KPM. Install/repair KPM first."
  exit 1
fi
echo "Adding the project KPM repository..."
"$KPM" add-repo "$REPO_URL" || echo "Repository may already be registered; continuing to refresh."
echo "Refreshing package index..."
if ! "$KPM" update; then
  echo "ERROR: KPM update failed. Check Wi-Fi and the log at $LOG."
  exit 1
fi
echo "Installing Royal Road Kindle Tools..."
if ! "$KPM" install royalroad-kindle-tools; then
  echo "ERROR: KPM could not install the package. Check that the repository appears in kpm list-repo and that the GitHub build has published a release."
  exit 1
fi
echo "SUCCESS: Royal Road Kindle Tools installed."
echo "Open the RoyalRoadTools library item once to add the test bookmark."
