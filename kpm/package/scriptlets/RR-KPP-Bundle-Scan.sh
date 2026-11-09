#!/bin/sh
# Name: RR-KPP-Bundle-Scan
# Author: E-Abenson
# Read-only inspection of the installed KPP JavaScript bundle.
# Only narrow, allowlisted string matches are written to the diagnostic log.

DOCS="/mnt/us/documents"
LOG="$DOCS/RR-JS-Smoke-Test.log"
HBC="/app/KPPMainApp/js/KPPMainApp.js.hbc"
NATIVE="/app/bin/KPPMainAppV2"
mkdir -p "$DOCS"
: > "$LOG"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

if command -v strings >/dev/null 2>&1; then
  STRINGS="strings"
elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -qx strings; then
  STRINGS="busybox strings"
else
  STRINGS=""
fi

scan_file() {
  FILE="$1"
  LABEL="$2"
  say ""
  say "---- Static string scan: $LABEL ----"

  if [ ! -r "$FILE" ]; then
    say "File not readable or not present: $FILE"
    return
  fi

  SIZE="$(wc -c < "$FILE" 2>/dev/null | tr -d ' ')"
  say "File: $FILE"
  say "Size in bytes: \${SIZE:-unknown}"

  if [ -z "$STRINGS" ]; then
    say "ERROR: strings utility is unavailable; no file contents were read."
    return
  fi

  # Search only for browser/LIPC identifiers and likely action-dispatch names.
  # The full strings output is never saved. Matching lines are capped and
  # URL-like substrings are removed before anything reaches the log.
  MATCHES="$(
    $STRINGS -n 5 "$FILE" 2>/dev/null |
    grep -i -E -C 3 'invokeAction|com\.lab126\.kppbrowser|kppbrowser|insertBookmark|getLastOpenPage|deleteAllHistory|updateSetting|goBack|goForward|loadUrl|loadURL|reloadPage|navigateTo|browser.{0,24}(action|navigate|reload|load)|action.{0,24}(browser|navigate|reload|load)' |
    awk '
      NR <= 120 {
        gsub(/https?:\/\/[^[:space:]"]+/, "[URL omitted]")
        if (length($0) > 280) $0=substr($0,1,280) "..."
        print
      }
      END {
        if (NR > 120) print "[additional matches omitted]"
      }
    '
  )"

  if [ -n "$MATCHES" ]; then
    printf '%s\n' "$MATCHES" | while IFS= read -r LINE; do
      say "CODE STRING: $LINE"
    done
  else
    say "No matching browser/action strings were found in this file."
  fi
}

say "============================================================"
say "ROYAL ROAD — KPP BUNDLE SCAN — READ ONLY"
say "This reads installed app files but does not modify them or run their code."
say "It does not contact the browser, navigate, refresh, or send invokeAction."

if [ -r "$HBC" ]; then
  scan_file "$HBC" "KPP JavaScript Hermes bundle"
else
  say "Expected Hermes bundle is absent; searching for KPP-related HBC files..."
  if command -v find >/dev/null 2>&1; then
    CANDIDATES="$(find /app -type f -name '*.hbc' 2>/dev/null | grep -i -E 'KPP|Browser|MainApp' | head -n 20)"
    if [ -n "$CANDIDATES" ]; then
      printf '%s\n' "$CANDIDATES" | while IFS= read -r FILE; do
        scan_file "$FILE" "Discovered Hermes bundle"
      done
    else
      say "No KPP/browser Hermes bundle path was found under /app."
    fi
  else
    say "find utility is unavailable."
  fi
fi

scan_file "$NATIVE" "KPPMainAppV2 native executable"

say ""
say "SCAN COMPLETE. No browser action, navigation, or JavaScript was sent."
say "Log saved to: $LOG"
exit 0
