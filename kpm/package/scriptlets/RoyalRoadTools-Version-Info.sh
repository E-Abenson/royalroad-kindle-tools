#!/bin/sh
# Name: Kindle-Version-Report
# Report build: 2.1
# Manual launcher: refreshes a readable software inventory on the Kindle.

DOCS="/mnt/us/documents"
OUT_FINAL="$DOCS/Kindle-Version-Report.txt"
OUT_TMP="$DOCS/.Kindle-Version-Report.txt.tmp.$$"
OUT="$OUT_TMP"
KPM="/var/local/kmc/bin/kpm"
KPM_DB="/mnt/us/kmc/kpm/kpm.db"
KO_ROOT="/mnt/us/koreader"
PLUGIN_ACTIVE="$KO_ROOT/plugins/kindle-batch-prepare-addon-fixed.koplugin"
PLUGIN_DISABLED="$KO_ROOT/plugins/kindle-batch-prepare-addon-fixed.disabled"
STAMP="$DOCS/.RoyalRoadTools-installed-version.txt"

mkdir -p "$DOCS"
: > "$OUT"
trap 'rm -f "$OUT_TMP"' 0
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
say "RAV ZVI USB OVERLAY FIX"
OVERLAY_STAMP="$DOCS/.royalroadtools/usb-overlay-version.txt"
if [ -r "$OVERLAY_STAMP" ]; then
  say "Bundled component version: $(sed -n 's/^version=//p' "$OVERLAY_STAMP" | head -n 1)"
  say "Staging status: installer and restore files present"
  say "System overlay applied by this package: no (user-controlled)"
  say "Install launcher: $( [ -x "$DOCS/Install-Rav-Zvi-USB-Overlay-Fix.sh" ] && echo present || echo missing )"
  say "Restore launcher: $( [ -x "$DOCS/Restore-Rav-Zvi-USB-Overlay-Fix.sh" ] && echo present || echo missing )"
  say "Existing bg_usbconnect.png: left unchanged by package staging"
else
  say "Bundled component: not staged"
fi
say ""
say "KPM updater launcher: $( [ -x "$DOCS/KPM-Update-All.sh" ] && echo present || echo missing )"
say "Native bridge export launcher: $( [ -x "$DOCS/KPP-Native-Bridge-Export.sh" ] && echo present || echo missing )"
say "JavaScript bundle export launcher: $( [ -x "$DOCS/KPP-JavaScript-Bundle-Export.sh" ] && echo present || echo missing )"
say "Experimental page-text capture launcher: $( [ -x "$DOCS/KPP-Page-Text-Capture.sh" ] && echo present || echo missing )"
say "Private ARM offscreen WebKit helper: $( [ -x "$DOCS/.royalroadtools/kpp-page-capture" ] && echo present || echo missing )"
say ""

say "KOREADER"
if [ -r "$KO_ROOT/git-rev" ]; then
  say "Installed KOReader revision: $(read_first_line "$KO_ROOT/git-rev")"
else
  say "KOReader git-rev file: not found; exact KOReader revision cannot be reported from this path"
fi
say ""

say "OPTIONAL KOReader PLUGIN — KINDLE BATCH PREPARATION"
say "Management: not installed, repaired, or updated by this KPM package."
PLUGIN_DIR=""
if [ -d "$PLUGIN_ACTIVE" ]; then PLUGIN_DIR="$PLUGIN_ACTIVE"; say "Plugin status: Active"
elif [ -d "$PLUGIN_DISABLED" ]; then PLUGIN_DIR="$PLUGIN_DISABLED"; say "Plugin status: Present but disabled"
else say "Plugin status: Not installed at the expected path"; fi
if [ -n "$PLUGIN_DIR" ]; then
  META="$PLUGIN_DIR/_meta.lua"; MAIN="$PLUGIN_DIR/main.lua"
  if [ -r "$META" ]; then
    PLUGIN_VERSION="$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$META" | head -n 1)"
    say "Plugin metadata version: ${PLUGIN_VERSION:-not declared}"
  else say "Plugin metadata: _meta.lua missing"; fi
  say "Installed main.lua fingerprint: $(fingerprint "$MAIN")"
else say "Plugin code fingerprint: unavailable"; fi
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

say "KPP HERMES JAVASCRIPT BUNDLE — USB EXPORT"
BUNDLE_COPY="$DOCS/KPPMainApp.js.hbc"
BUNDLE_REPORT="$DOCS/KPP-JavaScript-Bundle-Export.txt"
say "USB export launcher: $( [ -x "$DOCS/KPP-JavaScript-Bundle-Export.sh" ] && echo present || echo missing )"
if [ -s "$BUNDLE_COPY" ]; then
  say "USB transfer copy: present in Documents"
  say "Bundle size: $(wc -c < "$BUNDLE_COPY" | tr -d ' ') bytes"
  say "Bundle SHA256: $(fingerprint "$BUNDLE_COPY")"
  if command -v od >/dev/null 2>&1; then
    HBC_VERSION="$(od -An -tu4 -j 8 -N 4 "$BUNDLE_COPY" 2>/dev/null | tr -d ' ')"
    say "Hermes bytecode version (header field): ${HBC_VERSION:-unavailable}"
  fi
else
  say "USB transfer copy: not yet exported"
fi
if [ -r "$BUNDLE_REPORT" ]; then
  say "Export report: present"
else
  say "Export report: not yet generated"
fi
say "The original /app KPP application file is never modified."
say ""

say "MOST RECENT MAINTENANCE RUNS"
if [ -r "$DOCS/KPM-Update-All.log" ]; then
  LAST_UPDATE="$(grep -E 'SUCCESS — KPM upgrade completed|ERROR — KPM' "$DOCS/KPM-Update-All.log" | tail -n 1)"
  say "KPM update result: ${LAST_UPDATE:-no completion marker found}"
  LAST_CLEANUP="$(grep -F 'Retired-artifact cleanup:' "$DOCS/KPM-Update-All.log" | tail -n 1)"
  say "Retired-artifact cleanup: ${LAST_CLEANUP:-no cleanup summary found}"
else say "KPM update log: not found"; fi
say ""
say "============================================================"
say "This report is automatically regenerated after package installation and KPM-Update-All."
say "Saved to: $OUT_FINAL"
if ! mv -f "$OUT_TMP" "$OUT_FINAL"; then
  printf 'Could not replace version report: %s\n' "$OUT_FINAL" >&2
  exit 1
fi
trap - 0
