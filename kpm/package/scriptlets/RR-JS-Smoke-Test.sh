#!/bin/sh
# Name: RR-JS-Smoke-Test
# Author: E-Abenson
# Test shell-to-native-browser JavaScript injection through the Kindle LIPC API.
# This does NOT use a bookmarklet and does NOT modify browser databases or rootfs.

DOCS="/mnt/us/documents"
LOG="$DOCS/RR-JS-Smoke-Test.log"
mkdir -p "$DOCS"
: >> "$LOG"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

get_last_page() {
  if command -v lipc-get-prop >/dev/null 2>&1; then
    lipc-get-prop com.lab126.kppbrowser getLastOpenPage 2>/dev/null | tr -d '\r\n'
  fi
}

say "============================================================"
say "ROYAL ROAD — NATIVE BROWSER LIPC JAVASCRIPT TEST"
say "This test does not use a bookmarklet."
say "It sends a tiny, reversible page overlay through the browser's LIPC gotoURL property."
say "No cookies, credentials, chapter text, or browser database are read or changed."

if ! command -v lipc-get-prop >/dev/null 2>&1 || ! command -v lipc-set-prop >/dev/null 2>&1; then
  say "ERROR: Kindle LIPC command-line tools were not found."
  say "No browser action was attempted."
  exit 1
fi

LAST_URL="$(get_last_page)"
if [ -z "$LAST_URL" ]; then
  say "Could not read com.lab126.kppbrowser getLastOpenPage."
  say "No injection was attempted."
  say "See $LOG."
  exit 1
fi

case "$LAST_URL" in
  *://www.royalroad.com/*chapter/*|*://royalroad.com/*chapter/*)
    say "Last-open page is a Royal Road chapter."
    ;;
  *)
    say "The last-open page is not a Royal Road chapter."
    say "No injection was attempted."
    say "Open a Royal Road chapter in the built-in browser, leave it as the last page, return Home, then run RR-JS-Smoke-Test again."
    exit 0
    ;;
esac

say "Bringing the built-in browser to the foreground..."
if lipc-set-prop com.lab126.appmgrd start app://com.lab126.browser >> "$LOG" 2>&1; then
  say "Browser launch/focus request accepted."
else
  say "WARNING: Browser focus request failed; trying the LIPC URL action anyway."
fi
sleep 2

# The injected code only adds a small on-page label. It does not replace chapter text.
# Reloading the page removes the label.
JS_URL='javascript:(function(){try{if((location.hostname.toLowerCase()!=="www.royalroad.com"&&location.hostname.toLowerCase()!=="royalroad.com")||location.pathname.indexOf("/chapter/")<0){return;}var d=document,e=d.getElementById("rr-lipc-injection-test");if(!e){e=d.createElement("div");e.id="rr-lipc-injection-test";(d.body||d.documentElement).appendChild(e);}e.textContent="RR JS INJECTED VIA LIPC";e.style.cssText="position:fixed;top:4%;left:4%;right:4%;z-index:2147483647;background:#fff;color:#000;border:3px solid #000;padding:18px;font:24px sans-serif;text-align:center";}catch(x){}})()'

say "Sending JavaScript to com.lab126.browser gotoURL..."
if lipc-set-prop com.lab126.browser gotoURL "$JS_URL" >> "$LOG" 2>&1; then
  say "LIPC gotoURL command returned success."
  say "CHECK THE BROWSER: look for a white label reading RR JS INJECTED VIA LIPC."
  say "If it appears, shell-to-page JavaScript injection works without bookmarks."
  say "Reloading the chapter removes the label."
else
  STATUS=$?
  say "LIPC gotoURL command failed (exit code $STATUS)."
  say "The browser may expose a different LIPC interface on this firmware."
fi

say "Checking for an already-enabled local Chromium DevTools endpoint..."
FOUND_CDP=0
if command -v wget >/dev/null 2>&1; then
  for PORT in 9222 9223 9224 9333; do
    RESPONSE="$(wget -q -T 2 -O - "http://127.0.0.1:$PORT/json/version" 2>/dev/null)"
    case "$RESPONSE" in
      *webSocketDebuggerUrl*)
        say "DevTools endpoint detected on localhost port $PORT."
        FOUND_CDP=1
        ;;
    esac
  done
else
  say "wget is unavailable; local DevTools endpoint check was skipped."
fi
if [ "$FOUND_CDP" -eq 0 ]; then
  say "No DevTools JSON endpoint was found on the tested local ports."
fi

say "Checking browser process for a remote-debugging command-line flag..."
FOUND_FLAG=0
for PROC_FILE in /proc/[0-9]*/cmdline; do
  [ -r "$PROC_FILE" ] || continue
  CMD_LINE="$(tr '\000' ' ' < "$PROC_FILE" 2>/dev/null)"
  case "$CMD_LINE" in
    *--remote-debugging-port=*)
      FLAG="$(printf '%s\n' "$CMD_LINE" | sed -n 's/.*\(--remote-debugging-port=[0-9][0-9]*\).*/\1/p')"
      say "Browser process has $FLAG."
      FOUND_FLAG=1
      ;;
  esac
done
if [ "$FOUND_FLAG" -eq 0 ]; then
  say "No --remote-debugging-port flag was visible in process command lines."
fi

say "Finished: $(date)"
say "Full diagnostic saved to $LOG."
say "This test did not change system files, browser settings, bookmarks, or cookies."
exit 0
