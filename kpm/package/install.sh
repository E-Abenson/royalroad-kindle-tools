#!/bin/sh
# KPM install hook. It writes only to Kindle user storage.
set -e
DOCS="/mnt/us/documents"
LOG="$DOCS/RoyalRoadTools-package.log"
mkdir -p "$DOCS"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

install_scriptlet() {
  SOURCE="$1"
  DEST="$2"
  TEMP="\${DEST}.new.$$"
  say "Installing library item: $(basename "$DEST")"
  cp "$SOURCE" "$TEMP"
  chmod 755 "$TEMP"
  mv -f "$TEMP" "$DEST"
  say "Installed: $(basename "$DEST")"
}

say "Royal Road Kindle Tools — package installation/upgrade started."
install_scriptlet "scriptlets/RR-KPP-Bundle-Scan.sh" "$DOCS/RR-KPP-Bundle-Scan.sh"
install_scriptlet "scriptlets/RR-Upload-Bundle-Scan.sh" "$DOCS/RR-Upload-Bundle-Scan.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"
install_scriptlet "scriptlets/KindleBatchPrepareFix.sh" "$DOCS/KindleBatchPrepareFix.sh"
install_scriptlet "scriptlets/RoyalRoadTools-Version-Info.sh" "$DOCS/RoyalRoadTools-Version-Info.sh"

# Keep the cleanup launcher only until its one-time task has completed.
if [ ! -f "$DOCS/RoyalRoadTools-Cleanup.done" ]; then
  install_scriptlet "scriptlets/RoyalRoadTools-Cleanup.sh" "$DOCS/RoyalRoadTools-Cleanup.sh"
fi

PACKAGE_VERSION="$(awk '
  /"version"[[:space:]]*:/ {
    if (getline > 0) { gsub(/[^0-9]/, ""); a=$0 }
    if (getline > 0) { gsub(/[^0-9]/, ""); b=$0 }
    if (getline > 0) { gsub(/[^0-9]/, ""); c=$0 }
    if (a != "" && b != "" && c != "") print a "." b "." c
    exit
  }
' manifest.json)"
{
  printf 'version=%s\n' "\${PACKAGE_VERSION:-unknown}"
  printf 'installed_at=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
} > "$DOCS/RoyalRoadTools-installed-version.txt"
chmod 600 "$DOCS/RoyalRoadTools-installed-version.txt" 2>/dev/null || true

say "Installed tools: current bundle scan, uploader, version report, KPM updater, and KOReader repair."
say "Package version stamp: \${PACKAGE_VERSION:-unknown}"
say "Royal Road Kindle Tools package setup finished."
