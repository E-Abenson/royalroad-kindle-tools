#!/bin/sh
# Capture the most recent Royal Road chapter URL known to KPP.
# Uses a separate GTK offscreen WebKit view; it never injects into or navigates KPP.
set -u
umask 077

DOCS="/mnt/us/documents"
INTERNAL="$DOCS/.royalroadtools"
HELPER="$INTERNAL/kpp-page-capture"

say() { printf '%s\n' "$*"; }
fail() { say "CAPTURE NOT COMPLETED: $*"; exit 1; }

[ -x "$HELPER" ] || fail "The private WebKit helper is missing. Run KPM Update All to repair the package."
command -v lipc-get-prop >/dev/null 2>&1 || fail "Kindle's lipc-get-prop utility is unavailable."
command -v grep >/dev/null 2>&1 || fail "grep is unavailable."
command -v head >/dev/null 2>&1 || fail "head is unavailable."
command -v sed >/dev/null 2>&1 || fail "sed is unavailable."
command -v date >/dev/null 2>&1 || fail "date is unavailable."

say "Reading KPP's most recent browser address (read-only)..."
PAGE_INFO="$(lipc-get-prop com.lab126.kppbrowser getLastOpenPage 2>/dev/null)" ||
  fail "KPP did not return its last-open page. Make sure the built-in browser has been used."

# getLastOpenPage is a history metadata getter. Extract only HTTPS Royal Road URLs.
URL="$(printf '%s\n' "$PAGE_INFO" | grep -Eo 'https://www[.]royalroad[.]com/[^"[:space:],}]+' | head -n 1 | sed 's/[]}),;]*$//' | sed 's/[?#].*$//')"
[ -n "$URL" ] || fail "The most recent history entry was not a readable HTTPS Royal Road URL."
case "$URL" in
  https://www.royalroad.com/*) ;;
  *) fail "For safety, this capture tool only accepts www.royalroad.com pages." ;;
esac

# Kindle GTK applications use the local display. Preserve an existing display setting.
[ -n "${DISPLAY:-}" ] || DISPLAY=":0"
export DISPLAY

STAMP="$(date '+%Y%m%d-%H%M%S' 2>/dev/null)"
[ -n "$STAMP" ] || STAMP="capture"
OUT="$DOCS/RoyalRoad-Page-Capture-$STAMP.txt"
TEMP="$OUT.partial.$$"
rm -f "$TEMP"

say "Opening the saved address in a separate invisible WebKit view..."
say "Your existing KPP browser window will not be navigated or modified."
if "$HELPER" "$URL" "$TEMP"; then
  [ -s "$TEMP" ] || { rm -f "$TEMP"; fail "The helper reported success but produced no text."; }
  chmod 600 "$TEMP" 2>/dev/null || true
  if mv -f "$TEMP" "$OUT"; then
    chmod 600 "$OUT" 2>/dev/null || true
    say "SUCCESS — Royal Road page text saved to:"
    say "$OUT"
    exit 0
  fi
  rm -f "$TEMP"
  fail "Could not move the captured text into Kindle Documents."
fi

rm -f "$TEMP"
fail "The separate WebKit view could not retrieve readable chapter text. Royal Road may require your existing login session, may show a bot challenge, or this firmware may lack the GTK offscreen runtime support. Your original browser page was left alone."
