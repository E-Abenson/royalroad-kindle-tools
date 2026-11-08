#!/bin/sh
# Name: RR-LIPC-Metadata-Check
# Author: E-Abenson
# Build: 0.1.40
# Read-only inspection of the Kindle's Royal Road browser LIPC services.
# Property values returned by lipc-probe -v are filtered and never logged.

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
    say "ERROR: lipc-probe is not installed."
    return 1
  fi

  # KindleModding documents this syntax: lipc-probe <service> -v.
  # Verbose mode can include readable property values. Capture it privately,
  # then print only access/type/name columns for a small allowlist.
  OUTPUT="$(lipc-probe "$SERVICE" -v 2>&1)"
  STATUS=$?
  if [ "$STATUS" -ne 0 ] || [ -z "$OUTPUT" ]; then
    say "lipc-probe failed for this service (exit code $STATUS)."
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
      split(line, fields, /[ \t]+/)
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

  FOUND_ACTION=0
  if [ -n "$SAFE_ROWS" ]; then
    printf '%s\n' "$SAFE_ROWS" | while IFS='|' read -r ACCESS TYPE PROP; do
      case "$ACCESS" in
        r|w|rw)
          say "Property: $PROP | Type: $TYPE | Access: $ACCESS"
          ;;
        NONE)
          say "No allowlisted metadata rows could be parsed; raw output was suppressed."
          ;;
      esac
    done
    if printf '%s\n' "$SAFE_ROWS" | grep -qE '^(r|w|rw)\|[^|]+\|invokeAction$'; then
      FOUND_ACTION=1
    fi
  else
    say "No property metadata was parsed; raw output was suppressed."
  fi

  if [ "$FOUND_ACTION" -eq 1 ]; then
    ACTION_ROW="$(printf '%s\n' "$SAFE_ROWS" | awk -F'|' '$3=="invokeAction" {print $1 " / " $2; exit}')"
    say "FINDING: invokeAction metadata: $ACTION_ROW."
    say "No invokeAction payload was sent."
  else
    say "FINDING: invokeAction metadata was not confirmed."
  fi

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
}

say "============================================================"
say "ROYAL ROAD — LIPC METADATA CHECK — BUILD 0.1.40"
say "This is the new launcher. If you can read this, KPM installed v0.1.40."
say "Read-only: no navigation, refresh, bookmarks, setting changes, or JS injection."
say "The log is cleared at the beginning of each run."

ACTIVE_APP="$(lipc-get-prop com.lab126.appmgrd activeApp 2>/dev/null)"
[ -n "$ACTIVE_APP" ] && say "Active application: $ACTIVE_APP" || say "Active application: unavailable"

LAST_URL="$(lipc-get-prop com.lab126.kppbrowser getLastOpenPage 2>/dev/null | tr -d '\r\n')"
if [ -n "$LAST_URL" ]; then
  SAFE_URL="$(printf '%s' "$LAST_URL" | sed -E 's/[?#].*$//')"
  SAFE_URL="$(printf '%s' "$SAFE_URL" | sed -E 's#(https?://[^/]+/).*#\1[page path omitted]#')"
  say "Last-open page origin: $SAFE_URL"
else
  say "Last-open page: unavailable"
fi

SETTINGS="$(lipc-get-prop com.lab126.kppbrowser getAllSettings 2>/dev/null)"
case "$SETTINGS" in
  *'"isJavascriptEnabled":"true"'*) say "Browser JavaScript: enabled" ;;
  *'"isJavascriptEnabled":"false"'*) say "Browser JavaScript: disabled" ;;
  *) say "Browser JavaScript: unavailable or unrecognized" ;;
esac
case "$SETTINGS" in
  *'"isImageEnabled":"true"'*) say "Browser images: enabled" ;;
  *'"isImageEnabled":"false"'*) say "Browser images: disabled" ;;
  *) say "Browser images: unavailable or unrecognized" ;;
esac

probe_service "com.lab126.kppbrowser"
probe_service "com.lab126.browser"

say ""
say "CHECK COMPLETE. No browser action or JavaScript was sent."
say "Log saved to: $LOG"
exit 0
