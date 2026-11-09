#!/bin/sh
# KPM install hook. Installs only the current tools into Kindle user storage.
set -e
DOCS="/mnt/us/documents"
CLEANUP_DONE="$DOCS/.RoyalRoadTools-Cleanup-v2.done"
mkdir -p "$DOCS"
say() { printf '%s\n' "$*"; }
install_scriptlet() {
  SOURCE="$1"
  DEST="$2"
  TEMP="$DEST.new.$$"
  say "Installing $(basename "$DEST")..."
  cp "$SOURCE" "$TEMP"
  chmod 755 "$TEMP"
  mv -f "$TEMP" "$DEST"
}
say "Royal Road Kindle Tools — installing current toolset."
install_scriptlet "scriptlets/RR-LIPC-READONLY-PROBE.sh" "$DOCS/RR-LIPC-READONLY-PROBE.sh"
install_scriptlet "scriptlets/KPM-Update-All.sh" "$DOCS/KPM-Update-All.sh"
install_scriptlet "scriptlets/KindleBatchPrepareFix.sh" "$DOCS/KindleBatchPrepareFix.sh"
install_scriptlet "scriptlets/RoyalRoadTools-Version-Info.sh" "$DOCS/RoyalRoadTools-Version-Info.sh"
if [ ! -f "$CLEANUP_DONE" ]; then
  install_scriptlet "scriptlets/RoyalRoadTools-Cleanup.sh" "$DOCS/RoyalRoadTools-Cleanup.sh"
fi
# Bundle the source used by KindleBatchPrepareFix so repairs work offline.
SOURCE_TEMP="$DOCS/KindleBatchPrepare-main.lua.gz.new.$$"
cp "files/kindle_batch_prepare_main.lua.gz" "$SOURCE_TEMP"
chmod 644 "$SOURCE_TEMP"
mv -f "$SOURCE_TEMP" "$DOCS/KindleBatchPrepare-main.lua.gz"
PACKAGE_VERSION="$(awk '
  /"version"[[:space:]]*:/ {
    if (getline > 0) { gsub(/[^0-9]/, ""); a=$0 }
    if (getline > 0) { gsub(/[^0-9]/, ""); b=$0 }
    if (getline > 0) { gsub(/[^0-9]/, ""); c=$0 }
    if (a != "" && b != "" && c != "") print a "." b "." c
    exit
  }
' manifest.json)"
[ -n "$PACKAGE_VERSION" ] || PACKAGE_VERSION="unknown"
{
  printf 'version=%s\n' "$PACKAGE_VERSION"
  printf 'installed_at=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
} > "$DOCS/.RoyalRoadTools-installed-version.txt"
chmod 600 "$DOCS/.RoyalRoadTools-installed-version.txt" 2>/dev/null || true
say "Installed the read-only LIPC probe, version report, KPM updater and KOReader repair tool."
if [ ! -f "$CLEANUP_DONE" ]; then
  say "The one-time cleanup launcher is installed to retire previous test scripts and logs."
else
  say "Previous test cleanup has already been completed."
fi
say "Package version: $PACKAGE_VERSION"
say "Installation complete."
