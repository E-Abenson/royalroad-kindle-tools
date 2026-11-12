#!/bin/sh
# Name: RoyalRoadTools-Version-Info
# Report build: 1.8
# Refreshes a readable software inventory on the Kindle.

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
say "KPP interface inspector launcher: $( [ -x "$DOCS/RR-KPP-Interface-Inspector.sh" ] && echo present || echo missing )"
say "KPP interface upload helper: $( [ -x "$DOCS/.royalroadtools/inspector-upload.sh" ] && echo present || echo missing )"
say "KPP interface inspector log: $( [ -s "$DOCS/RR-KPP-Interface-Inspector.log" ] && echo present || echo not yet generated )"
say "Pasters.io delete token: $( [ -s "$DOCS/.RR-KPP-Interface-Inspector-delete-url.txt" ] && echo saved privately || echo not present )"
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
  if grep -Fq 'text = _("Prepare Kindle books for KOReader")' "$MAIN"; then
    say "Batch button label: updated (Prepare Kindle books for KOReader)"
  elif grep -Fq 'text = _("Prepare all Kindle books for KOReader")' "$MAIN"; then
    say "Batch button label: OLD — repair did not install the updated label"
  else
    say "Batch button label: unknown — expected text not found"
  fi
  if [ -r "$MAIN" ] && grep -Fq 'KOREADER_BATCH_PREPARE_MENU_FIX_V6' "$MAIN"; then
    say "Plugin source revision: V6 (selectable batch limit, responsive controls, staged EPUB output)"
  elif [ -r "$MAIN" ]; then
    say "Plugin source revision: older than V6 or unverified"
  else
    say "main.lua: missing"
  fi

  HELPER="$KO_ROOT/plugins/kindle.koplugin/dist/kindle_helper.py"
  YJ_BOOK="$KO_ROOT/plugins/kindle.koplugin/dist/kfxlib/yj_book.py"
  if [ -r "$HELPER" ] && grep -Fq '# KOREADER_BATCH_PREPARE_V2' "$HELPER"; then
    say "Converter helper: V2 (pause checkpoints)"
    if grep -Fq 'self.pause_file' "$HELPER" && grep -Fq -- '--pause-file' "$HELPER"; then
      say "Pause/resume helper support: present"
    else
      say "Pause/resume helper support: marker present but implementation check failed"
    fi
  elif [ -r "$HELPER" ] && grep -Fq '# KOREADER_BATCH_PREPARE_V1' "$HELPER"; then
    say "Converter helper: V1 (old progress/cancel build; pause migration needed)"
  elif [ -r "$HELPER" ]; then
    say "Converter helper: installed, but patch version unrecognized"
  else
    say "Converter helper: not found"
  fi
  if [ -r "$YJ_BOOK" ] && grep -Fq 'KOREADER_BATCH_PREPARE_PROGRESS_V1' "$YJ_BOOK"; then
    say "KFX decoder progress support: present"
  elif [ -r "$YJ_BOOK" ]; then
    say "KFX decoder progress support: not found"
  else
    say "KFX decoder source: not found"
  fi
  if [ -r "$MAIN" ] && grep -Fq 'function PLUGIN:createBatchLimitMenuItem()' "$MAIN"; then
    say "Batch size selector: present (default maximum: one new conversion per run)"
  elif [ -r "$MAIN" ]; then
    say "Batch size selector: not present"
  fi
  if [ -r "$MAIN" ] && grep -Fq '.batch-partial.epub' "$MAIN"; then
    say "Interrupted-output protection: staged EPUB before final cache commit"
  elif [ -r "$MAIN" ]; then
    say "Interrupted-output protection: not present"
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

say "KPP HERMES BYTECODE — ONE-TIME USB INVESTIGATION"
BUNDLE_COPY="$DOCS/KPPMainApp.js.hbc"
BUNDLE_REPORT="$DOCS/KPP-Bytecode-Export.txt"
say "USB export helper: $( [ -x "$DOCS/.royalroadtools/bytecode-export.sh" ] && echo present || echo missing )"
if [ -s "$BUNDLE_COPY" ]; then
  say "USB transfer copy: present in Documents"
  say "Bundle size: $(wc -c < "$BUNDLE_COPY" | tr -d ' ') bytes"
  say "Bundle SHA256: $(fingerprint "$BUNDLE_COPY")"
  if command -v od >/dev/null 2>&1; then
    HBC_VERSION="$(od -An -tu4 -j 8 -N 4 "$BUNDLE_COPY" 2>/dev/null | tr -d ' ')"
    say "Hermes bytecode version (header field): ${HBC_VERSION:-unavailable}"
  fi
else
  say "USB transfer copy: not yet available; update package to export it"
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
else
  say "KPM update log: not found"
fi
say ""
say "============================================================"
say "This report is automatically regenerated after KPM package installation/upgrade and successful batch-plugin repairs."
say "Saved to: $OUT_FINAL"
if ! mv -f "$OUT_TMP" "$OUT_FINAL"; then
  printf 'Could not replace version report: %s\n' "$OUT_FINAL" >&2
  exit 1
fi
trap - 0
