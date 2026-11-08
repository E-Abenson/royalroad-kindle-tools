#!/bin/sh
# Name: KindleBatchPrepareDiagnostics
# Purpose: Collect a local, privacy-conscious diagnostic report for the
# Kindle Batch Preparation KOReader plugin. Does not upload anything.
# The report is replaced on every run.

DOCS="/mnt/us/documents"
KO_ROOT="/mnt/us/koreader"
PLUGIN_DIR="$KO_ROOT/plugins/kindle-batch-prepare-addon-fixed.koplugin"
TARGET="$PLUGIN_DIR/main.lua"
META="$PLUGIN_DIR/_meta.lua"
FIX_LOG="$DOCS/KindleBatchPrepareFix.log"
PACKAGE_LOG="$DOCS/RoyalRoadTools-package.log"
CRASH_LOG="$KO_ROOT/crash.log"
OUT="$DOCS/KindleBatchPrepareDiagnostics.log"

mkdir -p "$DOCS"
: > "$OUT"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$OUT"
}

section() {
  say ""
  say "============================================================"
  say "$*"
  say "============================================================"
}

show_file() {
  FILE="$1"
  LABEL="$2"
  if [ -f "$FILE" ]; then
    say "$LABEL: PRESENT"
    ls -ln "$FILE" 2>&1 | tee -a "$OUT"
    cksum "$FILE" 2>&1 | tee -a "$OUT"
  else
    say "$LABEL: NOT FOUND ($FILE)"
  fi
}

section "KINDLE BATCH PREPARATION DIAGNOSTICS"
say "Report is regenerated on every run."
say "This script does not upload files or send data anywhere."
say "Device time: $(date)"
say "Kernel: $(uname -a 2>&1)"
say "KOReader root: $KO_ROOT"
say "Expected plugin folder: $PLUGIN_DIR"

section "DIRECTORY CHECKS"
for DIR in "$KO_ROOT" "$KO_ROOT/plugins" "$PLUGIN_DIR" "$KO_ROOT/settings" "$DOCS"; do
  if [ -d "$DIR" ]; then
    say "DIRECTORY PRESENT: $DIR"
    ls -ld "$DIR" 2>&1 | tee -a "$OUT"
  else
    say "DIRECTORY MISSING: $DIR"
  fi
done

section "PLUGIN FILES"
show_file "$META" "_meta.lua"
show_file "$TARGET" "main.lua"
if [ -d "$PLUGIN_DIR" ]; then
  say "Plugin directory listing:"
  ls -la "$PLUGIN_DIR" 2>&1 | tee -a "$OUT"
fi

section "PLUGIN METADATA"
if [ -f "$META" ]; then
  say "Contents of _meta.lua:"
  sed -n '1,160p' "$META" 2>&1 | tee -a "$OUT"
else
  say "_meta.lua is missing."
fi

section "MENU REGISTRATION CODE"
if [ -f "$TARGET" ]; then
  say "Relevant lines in installed main.lua:"
  grep -nE 'function .*init|function .*onReaderReady|function .*addToMainMenu|registerToMainMenu|sorting_hint|menu_items\.' "$TARGET" 2>&1 | tee -a "$OUT"
  say "Fix marker check:"
  grep -nF 'KOREADER_BATCH_PREPARE_MENU_FIX_V2' "$TARGET" 2>&1 | tee -a "$OUT"
else
  say "Cannot inspect menu registration because main.lua is missing."
fi

section "PLUGIN SETTINGS FILES"
if [ -d "$KO_ROOT/settings" ]; then
  ls -la "$KO_ROOT/settings" 2>&1 | grep -iE 'plugin|setting|config' | tee -a "$OUT"
  if [ ! -s "$OUT" ]; then
    say "No matching settings filenames were listed."
  fi
else
  say "KOReader settings directory is missing."
fi

section "INSTALLER LOGS"
show_file "$FIX_LOG" "KindleBatchPrepareFix.log"
if [ -f "$FIX_LOG" ]; then
  say "Last 100 lines of KindleBatchPrepareFix.log:"
  tail -n 100 "$FIX_LOG" 2>&1 | tee -a "$OUT"
fi
show_file "$PACKAGE_LOG" "RoyalRoadTools-package.log"
if [ -f "$PACKAGE_LOG" ]; then
  say "Last 60 lines of RoyalRoadTools-package.log:"
  tail -n 60 "$PACKAGE_LOG" 2>&1 | tee -a "$OUT"
fi

section "KOREADER RUNTIME LOG"
show_file "$CRASH_LOG" "KOReader crash.log"
if [ -f "$CRASH_LOG" ]; then
  say "Last 160 lines of crash.log:"
  tail -n 160 "$CRASH_LOG" 2>&1 | tee -a "$OUT"
else
  say "No crash.log exists. That does not prove KOReader has crashed."
  say "For a non-crash problem, enable verbose logging in KOReader's Help > Report a bug, restart KOReader, reproduce the missing-menu problem, then run this diagnostics launcher again."
fi

section "END OF REPORT"
say "Diagnostic report saved to: $OUT"
say "Please attach this file to the ChatGPT conversation."
say "Review it before sharing if you are concerned about file paths or book names."
exit 0
