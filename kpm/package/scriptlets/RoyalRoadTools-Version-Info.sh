#!/bin/sh
# Name: RoyalRoadTools-Version-Info
# Report build: 1.1
# Refreshes a readable software inventory on the Kindle.

DOCS="/mnt/us/documents"
OUT="$DOCS/Kindle-Version-Report.txt"
KPM="/var/local/kmc/bin/kpm"
KPM_DB="/mnt/us/kmc/kpm/kpm.db"
KO_ROOT="/mnt/us/koreader"
PLUGIN_ACTIVE="$KO_ROOT/plugins/kindle-batch-prepare-addon-fixed.koplugin"
PLUGIN_DISABLED="$KO_ROOT/plugins/kindle-batch-prepare-addon-fixed.disabled"
STAMP="$DOCS/.RoyalRoadTools-installed-version.txt"

mkdir -p "$DOCS"
: > "$OUT"
say() { printf '%s\n' "$*" | tee -a "$OUT"; }
read_first_line() {
  FILE="$1"
  if [ -r "$FILE" ]; then sed -n '1p' "$FILE" | tr -d '\r'
  else printf '%s' "Not found"; fi
}
fingerprint() {
  FILE="$1"
  if [ ! -r "$FILE" ]; then printf '%s' "Not found"
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$FILE" | awk '{print "SHA256 " $1}'
  elif command -v cksum >/dev/null 2>&1; then cksum "$FILE" | awk '{print "cksum " $1 " / bytes " $2}'
  else printf '%s' "File present; no checksum utility found"; fi
}

say "KINDLE SOFTWARE VERSION REPORT"
say "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
say "============================================================"
say ""
say "DEVICE"
say "Model: $(read_first_line /var/local/deviceType.txt)"
say "Firmware: $(read_first_line /etc/prettyversion.txt)"
say "Firmware identifier: $(read_first_line /etc/version.txt)"
say ""

say "KPM — KINDLE PACKAGE MANAGER"
if [ -x "$KPM" ]; then
  KPM_INFO="$("$KPM" version 2>&1)"
  VERSION_LINES="$(printf '%s\n' "$KPM_INFO" | grep -E 'Kindle Package Manager v|cli v|libkpm v|built for platform')"
  if [ -n "$VERSION_LINES" ]; then
    printf '%s\n' "$VERSION_LINES" | while IFS= read -r LINE; do say "$LINE"; done
  else
    say "KPM version command did not return recognizable version lines."
  fi
else
  say "KPM executable not found at $KPM"
fi
say ""

say "INSTALLED KPM PACKAGES (from KPM database)"
if [ -r "$KPM_DB" ] && command -v sqlite3 >/dev/null 2>&1; then
  PACKAGE_ROWS="$(sqlite3 -cmd '.timeout 5000' "$KPM_DB" "PRAGMA query_only=ON; SELECT id || '  ' || version_major || '.' || version_minor || '.' || version_patch FROM installed_packages ORDER BY id;" 2>/dev/null)"
  if [ -n "$PACKAGE_ROWS" ]; then
    printf '%s\n' "$PACKAGE_ROWS" | while IFS= read -r LINE; do say "$LINE"; done
  else
    say "No installed package rows returned, or the database query was unavailable."
  fi
else
  say "Installed package list unavailable (KPM database or sqlite3 CLI missing)."
fi
say ""

say "ROYAL ROAD KINDLE TOOLS"
if [ -r "$STAMP" ]; then
  say "Install version stamp: $(sed -n 's/^version=/version /p' "$STAMP" | head -n 1)"
  say "Installed at: $(sed -n 's/^installed_at=//p' "$STAMP" | head -n 1)"
else
  say "Install stamp: unavailable (package may predate this report feature)"
fi
if [ -r "$KPM_DB" ] && command -v sqlite3 >/dev/null 2>&1; then
  RR_VERSION="$(sqlite3 -cmd '.timeout 5000' "$KPM_DB" "PRAGMA query_only=ON; SELECT version_major || '.' || version_minor || '.' || version_patch FROM installed_packages WHERE id='royalroad-kindle-tools' LIMIT 1;" 2>/dev/null)"
  say "Installed Royal Road Kindle Tools package version: ${RR_VERSION:-not found in KPM database}"
else
  say "Installed package version: unavailable from KPM database"
fi
say "Bundle-scan launcher: $( [ -x "$DOCS/RR-KPP-Bundle-Scan.sh" ] && echo present || echo missing )"
say "Bundle-scan uploader: $( [ -x "$DOCS/RR-Upload-Bundle-Scan.sh" ] && echo present || echo missing )"
say "KPM updater launcher: $( [ -x "$DOCS/KPM-Update-All.sh" ] && echo present || echo missing )"
say ""

say "KOREADER"
if [ -r "$KO_ROOT/git-rev" ]; then
  say "Installed KOReader revision: $(read_first_line "$KO_ROOT/git-rev")"
else
  say "KOReader git-rev file: not found; exact KOReader revision cannot be reported from this path"
fi
say ""

say "KINDLE BATCH PREPARATION — KOReader PLUGIN"
PLUGIN_DIR=""
if [ -d "$PLUGIN_ACTIVE" ]; then
  PLUGIN_DIR="$PLUGIN_ACTIVE"
  say "Plugin status: Active"
elif [ -d "$PLUGIN_DISABLED" ]; then
  PLUGIN_DIR="$PLUGIN_DISABLED"
  say "Plugin status: Present but disabled"
else
  say "Plugin status: Not found at the expected path"
fi
if [ -n "$PLUGIN_DIR" ]; then
  META="$PLUGIN_DIR/_meta.lua"
  MAIN="$PLUGIN_DIR/main.lua"
  if [ -r "$META" ]; then
    PLUGIN_VERSION="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$META" | head -n 1)"
    say "Plugin metadata version: ${PLUGIN_VERSION:-not declared}"
  else
    say "Plugin metadata: _meta.lua missing"
  fi
  say "Installed main.lua fingerprint: $(fingerprint "$MAIN")"
  if [ -r "$MAIN" ] && grep -Fq 'KOREADER_BATCH_PREPARE_MENU_FIX_V2' "$MAIN"; then
    say "Menu crash-fix marker: present"
  elif [ -r "$MAIN" ]; then
    say "Menu crash-fix marker: not found"
  else
    say "main.lua: missing"
  fi
else
  say "Plugin code fingerprint: unavailable"
fi
say "Repair launcher: $( [ -x "$DOCS/KindleBatchPrepareFix.sh" ] && echo present || echo missing )"
say "Bundled repair source fingerprint: $(fingerprint "$DOCS/KindleBatchPrepare-main.lua.gz")"
if [ -r "$DOCS/KindleBatchPrepareFix.log" ]; then
  LAST_FIX="$(grep -F 'SUCCESS: Kindle Batch Preparation has been installed at:' "$DOCS/KindleBatchPrepareFix.log" | tail -n 1)"
  say "Last repair success: ${LAST_FIX:-no successful repair recorded in current log}"
else
  say "Last repair log: not found"
fi
say ""

say "KPP BROWSER APPLICATION"
if [ -x /app/bin/KPPMainAppV2 ]; then
  say "KPPMainAppV2: present at /app/bin/KPPMainAppV2"
  say "KPP executable fingerprint: $(fingerprint /app/bin/KPPMainAppV2)"
  say "Separate KPP app version: not exposed by the inspected interface"
else
  say "KPPMainAppV2: not found at the expected path"
fi
say ""

say "MOST RECENT MAINTENANCE RUNS"
if [ -r "$DOCS/KPM-Update-All.log" ]; then
  LAST_UPDATE="$(grep -E 'SUCCESS — KPM upgrade completed|ERROR — KPM' "$DOCS/KPM-Update-All.log" | tail -n 1)"
  say "KPM update result: ${LAST_UPDATE:-no completion marker found}"
else
  say "KPM update log: not found"
fi
say ""
say "============================================================"
say "This report is regenerated whenever you open RoyalRoadTools-Version-Info."
say "After a KPM or KOReader update, open it again to refresh the inventory."
say "Saved to: $OUT"
