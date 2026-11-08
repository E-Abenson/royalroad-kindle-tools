#!/bin/sh
# Name: RR-JS-Smoke-Test
# Author: E-Abenson
# Read-only detailed diagnostic of the Kindle's built-in browser LIPC service.
# It prints only allowlisted property names, type/access metadata, and owner process metadata.
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

  # -v reports each property with its access/type/name columns. It also
  # reads values for readable properties, so capture everything in memory
  # and emit ONLY the allowlisted metadata columns below. Never log values.
  OUTPUT="$(lipc-probe "$SERVICE" -v 2>&1)"
  STATUS=$?
  if [ "$STATUS" -ne 0 ] || [ -z "$OUTPUT" ]; then
    say "Service could not be queried (exit code $STATUS)."
    return 1
  fi

  SAFE_ROWS="$(printf '%s\n' "$OUTPUT" | awk '
    BEGIN {
      known["deleteAllHistory"]=1
      known["emitBrowserLoadTimeMetrics"]=1
      known["getAllSettings"]=1
      known["getLastOpenPage"]=1
      known["insertBookmark"]=1
      known["insertOrUpdateHistory"]=1
      known["invokeAction"]=1
      known["isBookmarkPresent"]=1
      known["migrateDataFromMesquite"]=1
      known["updateSetting"]=1
    }
    {
      line=$0
      sub(/^[ \t]+/, "", line)
      n=split(line, fields, /[ \t]+/)
      access=fields[1]
      type=fields[2]
      name=fields[3]
      if ((access=="r" || access=="w" || access=="rw") &&
          (type=="Str" || type=="Int" || type=="Has") &&
          known[name]) {
        if (!printed[name]++) print access "|" type "|" name
        parsed++
      }
    }
    END {
      if (parsed==0) print "NONE|||"
    }
  ' 2>/dev/null)"

  if [ -n "$SAFE_ROWS" ]; then
    printf '%s\n' "$SAFE_ROWS" | while IFS='|' read -r ACCESS TYPE PROP; do
      case "$ACCESS" in
        r|w|rw)
          say "Property: $PROP | Type: $TYPE | Access: $ACCESS"
          ;;
        NONE)
          say "Verbose output format was not recognized; raw output was suppressed."
          ;;
      esac
    done
  else
    say "No property metadata was parsed; raw output was suppressed."
  fi

  if printf '%s\n' "$SAFE_ROWS" | grep -qE '^(r|w|rw)\|Str\|invokeAction$'; then
    ACTION_ACCESS="$(printf '%s\n' "$SAFE_ROWS" | awk -F'|' '$3=="invokeAction" {print $1; exit}')"
    say "FINDING: invokeAction is a string property (access: $ACTION_ACCESS)."
    say "Its accepted payload is still unknown. No action payload was sent."
  else
    say "FINDING: invokeAction metadata was not confirmed by this probe."
  fi

  # Identify the process that owns this LIPC service using a read-only
  # D-Bus query. Only the PID, process name, and executable path are reported.
  if command -v dbus-send >/dev/null 2>&1; then
    OWNER_INFO="$(dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.GetConnectionUnixProcessID string:"$SERVICE" 2>/dev/null)"
    OWNER_PID="$(printf '%s\n' "$OWNER_INFO" | sed -n 's/.*uint32 \([0-9][0-9]*\).*/\1/p' | head -n 1)"
    case "$OWNER_PID" in
      ''|*[!0-9]*)
        say "Service owner PID could not be determined."
        ;;
      *)
        OWNER_COMM="$(cat "/proc/$OWNER_PID/comm" 2>/dev/null | tr -d '\r\n')"
        OWNER_EXE="$(readlink "/proc/$OWNER_PID/exe" 2>/dev/null)"
        [ -n "$OWNER_COMM" ] || OWNER_COMM="unknown"
        [ -n "$OWNER_EXE" ] || OWNER_EXE="unavailable"
        say "Service owner PID: $OWNER_PID"
        say "Service owner process: $OWNER_COMM"
        say "Service owner executable: $OWNER_EXE"
        ;;
    esac
  else
    say "dbus-send is unavailable; service owner process was not queried."
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
