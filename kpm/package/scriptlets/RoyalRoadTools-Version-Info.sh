#!/bin/sh
# Name: RoyalRoadTools-Version-Info
# Refreshes a readable software version inventory document on the Kindle.

DOCS="/mnt/us/documents"
OUT="$DOCS/Kindle-Version-Report.txt"
KPM="/var/local/kmc/bin/kpm"
KPM_DB="/mnt/us/kmc/kpm/kpm.db"
KPM_PACKAGES="/mnt/us/kmc/kpm/packages"
KO_ROOT="/mnt/us/koreader"
PLUGIN_ACTIVE="$KO_ROOT/plugins/kindle-batch-prepare-addon-fixed.koplugin"
PLUGIN_DISABLED="$KO_ROOT/plugins/kindle-batch-prepare-addon-fixed.disabled"

mkdir -p "$DOCS"
: > "$OUT"

say() { printf '%s\n' "$*" | tee -a "$OUT"; }

read_first_line() {
  FILE="$1"
  if [ -r "$FILE" ]; then
    sed -n '1p' "$FILE" | tr -d '\r'
  else
    printf '%s' "Not found"
  fi
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
  MATCHED=0
  printf '%s\n' "$KPM_INFO" | grep -E 'Kindle Package Manager v|cli v|libkpm v|built for platform' | while IFS= read -r LINE; do
    printf '%s\n' "$LINE"
  done | tee -a "$OUT"
  if [ -z "$KPM_INFO" ]; then say "KPM version command returned no information."; fi
else
  say "KPM executable not found at $KPM"
fi
say ""

say "INSTALLED KPM PACKAGES"
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
STAMP="$DOCS/RoyalRoadTools-installed-version.txt"
if [ -r "$STAMP" ]; then
  sed 's/^/Install stamp: /' "$STAMP" | while IFS= read -r LINE; do say "$LINE"; done
else
  say "Install stamp not found. Run KPM-Update-All, then refresh this report."
fi

PKG_MANIFEST="$KPM_PACKAGES/royalroad-kindle-tools/manifest.json"
if [ -r "$PKG_MANIFEST" ]; then
  PACKAGE_VERSION="$(awk '
    /"version"[[:space:]]*:/ {
      if (getline > 0) { gsub(/[^0-9]/, ""); a=$0 }
      if (getline > 0) { gsub(/[^0-9]/, ""); b=$0 }
      if (getline > 0) { gsub(/[^0-9]/, ""); c=$0 }
      if (a != "" && b != "" && c != "") print a "." b "." c
      exit
    }
  ' "$PKG_MANIFEST")"
  say "KPM package folder manifest version: \${PACKAGE_VERSION:-Could not read}"
else
  say "KPM package folder manifest not found."
fi
say ""

say "KOREADER"
if [ -r "$KO_ROOT/git-rev" ]; then
  say "Installed KOReader revision: $(read_first_line "$KO_ROOT/git-rev")"
else
  say "KOReader git-rev file not found under $KO_ROOT."
fi
say ""

say "KINDLE BATCH PREPARATION PLUGIN"
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
    say "Plugin metadata version: \${PLUGIN_VERSION:-Not declared}"
  else
    say "Plugin metadata: _meta.lua missing"
  fi
  if [ -r "$MAIN" ] && grep -Fq 'KOREADER_BATCH_PREPARE_MENU_FIX_V2' "$MAIN"; then
    say "Menu crash-fix marker: present"
  elif [ -r "$MAIN" ]; then
    say "Menu crash-fix marker: not found"
  else
    say "main.lua: missing"
  fi
else
  say "No plugin version could be read."
fi
say ""

say "KPP BROWSER APPLICATION"
if [ -x /app/bin/KPPMainAppV2 ]; then
  say "KPPMainAppV2: present at /app/bin/KPPMainAppV2"
  say "Separate KPP app version string: not exposed by this report"
else
  say "KPPMainAppV2: not found at the expected path"
fi
say ""
say "============================================================"
say "This document is refreshed whenever you open RoyalRoadTools-Version-Info."
say "After updating KPM or KOReader, open that launcher again to refresh the numbers."
say "Saved to: $OUT"
