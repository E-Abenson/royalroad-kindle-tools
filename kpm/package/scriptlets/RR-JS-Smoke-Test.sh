#!/bin/sh
# Name: RR-JS-Smoke-Test
# Author: E-Abenson
# Read-only detailed diagnostic of the Kindle's built-in browser LIPC service.
# It prints only property names and type/access metadata, never property values.
# It does not launch, focus, navigate, refresh, bookmark, or inject into the browser.

DOCS="/mnt/us/documents"
LOG="$DOCS/RR-JS-Smoke-Test.log"
mkdir -p "$DOCS"
: > "$LOG"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

probe_service() {
  SERVICE="$1"
  say ""
  say "---- LIPC service: $SERVICE ----"

  if ! command -v lipc-probe >/dev/null 2>&1; then
    say "lipc-probe is not installed."
    return 1
  fi

  # Probe only this service. Never run the verbose all-services command:
  # that can expose unrelated account/session properties.
  OUTPUT="$(lipc-probe "$SERVICE" 2>&1)"
  STATUS=$?
  if [ "$STATUS" -ne 0 ] || [ -z "$OUTPUT" ]; then
    say "Service could not be queried (exit code $STATUS)."
    return 1
  fi

  # Parse only the first three columns (name, type, access). The Value column
  # and any trailing text are discarded. If this firmware uses another format,
  # report presence of a small known-property allowlist without printing lines.
  SAFE_ROWS="$(printf '%s\n' "$OUTPUT" | awk '
    function trim(s) {
      sub(/^[ \t]+/, "", s)
      sub(/[ \t]+$/, "", s)
      return s
    }
    BEGIN {
      known[1]="deleteAllHistory"
      known[2]="emitBrowserLoadTimeMetrics"
      known[3]="getAllSettings"
      known[4]="getLastOpenPage"
      known[5]="insertBookmark"
      known[6]="insertOrUpdateHistory"
      known[7]="invokeAction"
      known[8]="isBookmarkPresent"
      known[9]="migrateDataFromMesquite"
      known[10]="updateSetting"
    }
    {
      line=$0
      name=""; type=""; access=""
      if (index(line, "|") > 0) {
        n=split(line, fields, "|")
        name=trim(fields[1]); type=trim(fields[2]); access=trim(fields[3])
      } else {
        line=trim(line)
        n=split(line, fields, /[ \t]+/)
        name=fields[1]; type=fields[2]; access=fields[3]
        sub(/:$/, "", name)
        gsub(/[^[:alpha:]]/, "", type)
        gsub(/[^[:alpha:]]/, "", access)
      }
      if (name ~ /^[A-Za-z_][A-Za-z0-9_.-]*$/ &&
          (type=="Str" || type=="Int" || type=="Has") &&
          (access=="r" || access=="w" || access=="rw")) {
        if (!printed[name]++) {
          print "property|" name "|" type "|" access
        }
        parsed++
      }
      for (i=1; i<=10; i++) {
        p=known[i]
        if (p != "" && index(line,p)>0) found[p]=1
      }
    }
    END {
      for (i=1; i<=10; i++) {
        p=known[i]
        if (found[p] && !printed[p]) print "present|" p "||"
      }
      if (parsed==0) print "notice|NO_ROWS_PARSED||"
    }
  ' 2>/dev/null)"

  if [ -n "$SAFE_ROWS" ]; then
    printf '%s\n' "$SAFE_ROWS" | while IFS='|' read -r KIND PROP TYPE ACCESS; do
      case "$KIND" in
        property)
          say "Property: $PROP | Type: $TYPE | Access: $ACCESS"
          ;;
        present)
          say "Property present: $PROP (type/access format not recognized)"
          ;;
        notice)
          say "The output format was not recognized; raw output was suppressed for privacy."
          ;;
      esac
    done
  else
    say "No property rows were returned; raw output was suppressed for privacy."
  fi

  if printf '%s\n' "$SAFE_ROWS" | grep -q '^property|invokeAction|'; then
    ACTION_META="$(printf '%s\n' "$SAFE_ROWS" | awk -F'|' '$1=="property" && $2=="invokeAction" {print $3 " " $4; exit}')"
    say "FINDING: invokeAction is registered ($ACTION_META). No action payload was sent."
  elif printf '%s\n' "$SAFE_ROWS" | grep -q '^present|invokeAction|'; then
    say "FINDING: invokeAction is registered; type/access could not be parsed. No action payload was sent."
  else
    say "FINDING: invokeAction was not confirmed by this probe."
  fi

  return 0
}

say "============================================================"
say "ROYAL ROAD — DETAILED READ-ONLY BROWSER LIPC DIAGNOSTIC"
say "No browser command, navigation, refresh, bookmark, or JavaScript injection will be sent."
say "This run clears the previous log and records only this diagnostic."

if ! command -v lipc-get-prop >/dev/null 2>&1; then
  say "ERROR: lipc-get-prop is unavailable."
  exit 1
fi

say ""
say "Checking which Kindle application is currently in front..."
ACTIVE_APP="$(lipc-get-prop com.lab126.appmgrd activeApp 2>/dev/null)"
if [ -n "$ACTIVE_APP" ]; then
  say "Active application: $ACTIVE_APP"
else
  say "Active application could not be read."
fi

say ""
say "Reading the browser's last-open page (query and fragment are omitted)..."
LAST_URL="$(lipc-get-prop com.lab126.kppbrowser getLastOpenPage 2>/dev/null | tr -d '\r\n')"
if [ -n "$LAST_URL" ]; then
  SAFE_URL="$(printf '%s' "$LAST_URL" | sed -E 's/[?#].*$//')"
  say "Last-open page: $SAFE_URL"
else
  say "The KPP browser did not return a last-open page."
fi

say ""
say "Checking the browser's read-only JavaScript/image settings..."
SETTINGS="$(lipc-get-prop com.lab126.kppbrowser getAllSettings 2>/dev/null)"
case "$SETTINGS" in
  *'"isJavascriptEnabled":"true"'*) say "Browser JavaScript setting: enabled" ;;
  *'"isJavascriptEnabled":"false"'*) say "Browser JavaScript setting: disabled" ;;
  *'isJavascriptEnabled'*) say "Browser JavaScript setting: returned, but format was not recognized" ;;
  *) say "Browser JavaScript setting: unavailable" ;;
esac
case "$SETTINGS" in
  *'"isImageEnabled":"true"'*) say "Browser images setting: enabled" ;;
  *'"isImageEnabled":"false"'*) say "Browser images setting: disabled" ;;
  *) say "Browser images setting: unavailable" ;;
esac

probe_service "com.lab126.kppbrowser"
probe_service "com.lab126.browser"

say ""
say "---- Browser executable/process flags ----"
FOUND_FLAG=0
for PROC_FILE in /proc/[0-9]*/cmdline; do
  [ -r "$PROC_FILE" ] || continue
  CMD_LINE="$(tr '\000' ' ' < "$PROC_FILE" 2>/dev/null)"
  case "$CMD_LINE" in
    *--remote-debugging-port=*)
      FLAG="$(printf '%s\n' "$CMD_LINE" | sed -n 's/.*\(--remote-debugging-port=[0-9][0-9]*\).*/\1/p')"
      say "Detected browser process flag: $FLAG"
      FOUND_FLAG=1
      ;;
  esac
done
if [ "$FOUND_FLAG" -eq 0 ]; then
  say "No visible --remote-debugging-port flag was found."
fi

say ""
say "DIAGNOSTIC COMPLETE."
say "No browser action or JavaScript was sent."
say "Log saved to: $LOG"
say "Share this log to continue identifying the correct browser-control interface."
exit 0
