#!/bin/sh
# Name: RR-KPP-Interface-Inspector
# Read-only static inspection of Kindle KPP/browser application files.
#
# PRIVACY / SAFETY:
# - Does not run lipc-probe or lipc-get-prop.
# - Does not read LIPC property values, browser settings, URLs, cookies,
#   history, bookmarks, browser databases, credentials, or page contents.
# - Does not set LIPC properties, send events, navigate, refresh, or execute JS.
# - Does not use the network and has no uploader.
# - Reads static strings from a small set of system application files, but
#   writes only fixed indicator names and file paths to the report. Raw strings
#   are kept in a private temporary file and removed on exit.

DOCS="/mnt/us/documents"
LOG="$DOCS/RR-KPP-Interface-Inspector.log"
TMP="/tmp/rr_kpp_interface_inspector_$$"

umask 077
mkdir -p "$DOCS" 2>/dev/null
if ! mkdir -m 700 "$TMP" 2>/dev/null; then
  printf '%s\n' "ERROR: Could not create a private temporary directory." > "$LOG"
  chmod 600 "$LOG" 2>/dev/null || true
  exit 1
fi
trap 'rm -rf "$TMP"' 0 HUP INT TERM

: > "$LOG"

{
  echo "============================================================"
  echo "KINDLE — KPP BROWSER INTERFACE INSPECTOR"
  date 2>&1
  echo "============================================================"
  echo
  echo "MODE: READ-ONLY STATIC FILE INSPECTION"
  echo "No LIPC commands or browser actions are executed."
  echo "No browser URL, settings, cookies, history, database, or page text is read."
  echo "No network connection or upload is performed."
  echo "Raw strings are not written to this report."
  echo
  echo "KNOWN FROM THE PREVIOUS READ-ONLY INVESTIGATION"
  echo "Service: com.lab126.kppbrowser"
  echo "Property: invokeAction (write-only string)"
  echo "Accepted action format: not established; this inspector will not guess or send one."
  echo
  echo "DEVICE / TOOL AVAILABILITY"
  echo "Architecture: $(uname -m 2>/dev/null || echo unavailable)"
  if command -v find >/dev/null 2>&1; then echo "find: available"; else echo "find: unavailable"; fi
  if command -v strings >/dev/null 2>&1; then echo "strings: available"; else echo "strings: unavailable"; fi
  if command -v sha256sum >/dev/null 2>&1; then echo "sha256sum: available"; else echo "sha256sum: unavailable"; fi
  echo

  echo "KPP APPLICATION FILE"
  APP="/app/bin/KPPMainAppV2"
  if [ -r "$APP" ]; then
    echo "Found: $APP"
    if command -v sha256sum >/dev/null 2>&1; then
      sha256sum "$APP" 2>/dev/null | awk '{print "SHA256: " $1}'
    else
      echo "Fingerprint: sha256sum unavailable"
    fi
  else
    echo "Not readable at the previously observed path: $APP"
  fi
  echo

  echo "STATIC FILE SCAN"
  echo "Search roots: /app, /opt/amazon, /usr/share/amazon, /usr/lib"
  echo "Candidate filenames are limited to KPP/browser/WebKit/Chromium/Juno names."
  echo "At most 80 files are inspected; files larger than about 50 MB are skipped."
  echo

  {
    for ROOT in /app /opt/amazon /usr/share/amazon /usr/lib; do
      [ -d "$ROOT" ] || continue
      find "$ROOT" -maxdepth 5 -type f -size -50000k \( \
        -iname '*kpp*' -o -iname '*browser*' -o -iname '*webkit*' \
        -o -iname '*chrom*' -o -iname '*juno*' \) -print 2>/dev/null
    done
  } | sort -u | head -n 80 > "$TMP/files"

  FILE_COUNT="$(wc -l < "$TMP/files" 2>/dev/null | tr -d ' ')"
  echo "Candidate files selected: ${FILE_COUNT:-0}"
  if [ ! -s "$TMP/files" ]; then
    echo "No candidate files were found under the inspected roots."
  elif ! command -v strings >/dev/null 2>&1; then
    echo "The strings utility is unavailable; static string inspection was skipped."
  else
    while IFS= read -r FILE; do
      [ -r "$FILE" ] || continue
      echo
      echo "FILE: $FILE"
      : > "$TMP/strings"
      if strings -a "$FILE" > "$TMP/strings" 2>/dev/null; then
        FOUND=0
        for MARKER in \
          invokeAction \
          com.lab126.kppbrowser \
          getAllSettings \
          getLastOpenPage \
          evaluateJavascript \
          evaluateJavaScript \
          executeJavaScript \
          runJavaScript \
          javascript: \
          loadUrl \
          loadURL \
          navigate \
          WebView \
          WebKit \
          Chromium \
          remote-debugging \
          DevTools \
          chrome.send \
          postMessage; do
          if grep -Fiq "$MARKER" "$TMP/strings" 2>/dev/null; then
            echo "  indicator present: $MARKER"
            FOUND=1
          fi
        done
        if [ "$FOUND" -eq 0 ]; then
          echo "  No target interface markers found."
        fi
      else
        echo "  String extraction failed or this file is not inspectable."
      fi
    done < "$TMP/files"
  fi

  echo
  echo "============================================================"
  echo "INTERPRETATION"
  echo "A marker only proves that text is embedded in a file; it does not prove"
  echo "that an action is callable, supported, or safe to invoke."
  echo "No invokeAction payload was constructed or sent."
  echo "Use this report to choose the next narrow source file to inspect."
  echo
  echo "Do not share a full lipc-probe -a -v dump or any browser database."
  echo "This report is designed to contain only file paths and fixed marker names."
  echo "Saved to: $LOG"
  echo "============================================================"
} > "$LOG" 2>&1

chmod 600 "$LOG" 2>/dev/null || true
sync 2>/dev/null
cat "$LOG"
exit 0
