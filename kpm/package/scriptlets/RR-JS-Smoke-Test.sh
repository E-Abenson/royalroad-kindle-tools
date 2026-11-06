#!/bin/sh
# Name: RR-JS-Smoke-Test
# Author: E-Abenson
# Read-only diagnostic of the Kindle's actual browser LIPC interface.
#
# IMPORTANT:
# This version deliberately does NOT launch, focus, navigate, refresh, or inject
# into the browser. The previous test used an unverified gotoURL property and
# could interrupt page loading. First discover the properties on this device.

DOCS="/mnt/us/documents"
LOG="$DOCS/RR-JS-Smoke-Test.log"
mkdir -p "$DOCS"
: >> "$LOG"

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

  # Probe only the named service, without -v. Never dump the entire LIPC
  # registry: it can contain unrelated account/session properties.
  OUTPUT="$(lipc-probe "$SERVICE" 2>&1)"
  STATUS=$?
  if [ "$STATUS" -ne 0 ] || [ -z "$OUTPUT" ]; then
    say "Service could not be queried (exit code $STATUS)."
    return 1
  fi

  # Print the service's property names and access types, but suppress any
  # possible values. This diagnostic must never print tokens/cookies.
  printf '%s\n' "$OUTPUT" |
    sed -E 's/[[:space:]]*\|[[:space:]]*Value.*$//' |
    grep -E '(^Name|^[[:space:]]*[-|]+|^[[:space:]]*[A-Za-z][A-Za-z0-9_]*[[:space:]]*\|)' |
    while IFS= read -r LINE; do say "$LINE"; done

  if printf '%s\n' "$OUTPUT" | grep -Eiq '(^|[|[:space:]])gotoURL([|[:space:]]|$)'; then
    say "FINDING: this service appears to expose gotoURL."
  fi
  if printf '%s\n' "$OUTPUT" | grep -Eiq '(^|[|[:space:]])invokeAction([|[:space:]]|$)'; then
    say "FINDING: this service exposes invokeAction; its accepted payload is still unknown."
  fi
  return 0
}

say "============================================================"
say "ROYAL ROAD — READ-ONLY BROWSER LIPC DIAGNOSTIC"
say "No browser command, navigation, refresh, bookmark, or JavaScript injection will be sent."
say "Your current browser page should remain untouched."

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
say "Reading the browser's last-open page (URL query parameters are omitted)..."
LAST_URL="$(lipc-get-prop com.lab126.kppbrowser getLastOpenPage 2>/dev/null | tr -d '\r\n')"
if [ -n "$LAST_URL" ]; then
  SAFE_URL="$(printf '%s' "$LAST_URL" | sed -E 's/[?#].*$//')"
  say "Last-open page: $SAFE_URL"
else
  say "The KPP browser did not return a last-open page."
fi

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
say "Nothing was sent to the browser, so its page should not have been interrupted."
say "Log saved to: $LOG"
say "Please share this log's contents. It contains only the active app, page address without query parameters, and browser LIPC property names."
exit 0
