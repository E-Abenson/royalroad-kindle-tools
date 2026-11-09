#!/bin/sh
# Name: RR-LIPC-READONLY-UPLOAD
# Uploads only the read-only LIPC diagnostic log to pasters.io.
# The user starts this dedicated launcher; it prompts when interactive input is available. It does not run the probe.

DOCS="/mnt/us/documents"
LOG="$DOCS/RR-LIPC-READONLY-PROBE.log"
URL_FILE="$DOCS/RR-LIPC-READONLY-UPLOAD-URL.txt"
DELETE_FILE="$DOCS/RR-LIPC-READONLY-UPLOAD-DELETE-URL.txt"
UPLOAD_URL="https://pasters.io/?expires=1w"
TMP="/tmp/rr_lipc_upload_$$"
HEADERS="$TMP.headers"
BODY="$TMP.body"

umask 077
trap 'rm -f "$HEADERS" "$BODY" "$TMP.curl-error"' EXIT HUP INT TERM

say() { printf '%s\n' "$*"; }

say "KINDLE — UPLOAD READ-ONLY LIPC DIAGNOSTIC"
say "============================================================"
say "This sends the contents of:"
say "  $LOG"
say "to pasters.io, where it can be viewed by anyone with the link."
say "The paste is requested to expire after one week."
say ""
say "The log contains device, process and LIPC inventory information."
say "Review it before proceeding. No other files are uploaded."
say "This script does not run the diagnostic or interact with the browser."
say ""

if [ ! -s "$LOG" ]; then
  say "ERROR: Diagnostic log not found or empty."
  say "Open RR-LIPC-READONLY-PROBE first, then run this uploader."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  say "ERROR: curl is not installed; nothing was uploaded."
  exit 1
fi

if [ -t 0 ]; then
  printf 'To upload this log, type UPLOAD exactly: '
  IFS= read -r CONFIRM
  if [ "$CONFIRM" != "UPLOAD" ]; then
    say "Cancelled. Nothing was uploaded."
    exit 0
  fi
else
  say "No keyboard prompt is available in this launcher."
  say "Opening this dedicated uploader is treated as confirmation to upload the displayed log."
fi

mkdir -p "$DOCS" 2>/dev/null
say ""
say "Uploading the LIPC diagnostic log..."

HTTP_CODE="$(curl -sS --connect-timeout 10 --max-time 45 \
  -D "$HEADERS" -o "$BODY" -w '%{http_code}' \
  --data-binary "@$LOG" "$UPLOAD_URL" 2>"$TMP.curl-error")"
CURL_STATUS=$?

if [ "$CURL_STATUS" -ne 0 ]; then
  say "ERROR: Upload request failed (curl status $CURL_STATUS)."
  if [ -s "$TMP.curl-error" ]; then cat "$TMP.curl-error"; fi
  rm -f "$TMP.curl-error"
  exit 1
fi
rm -f "$TMP.curl-error"

header_value() {
  HEADER_NAME="$1"
  tr -d '\r' < "$HEADERS" | awk -v wanted="$HEADER_NAME" '
    BEGIN { wanted=tolower(wanted) }
    {
      name=$0
      sub(/:.*/, "", name)
      if (tolower(name) == wanted) {
        sub(/^[^:]*:[[:space:]]*/, "")
        print
        exit
      }
    }'
}

PASTE_URL="$(header_value Location)"
case "$PASTE_URL" in
  https://pasters.io/*) ;;
  *)
    PASTE_URL="$(sed -n 's@.*\(https://pasters\.io/[A-Za-z0-9_-][A-Za-z0-9_-]*\).*@\1@p' "$BODY" | head -n 1)"
    ;;
esac

DELETE_URL="$(header_value X-Delete-Url)"

if [ -z "$PASTE_URL" ]; then
  say "ERROR: pasters.io returned HTTP $HTTP_CODE, but no paste link could be read."
  say "Nothing was saved as a successful upload. Response:"
  cat "$BODY"
  exit 1
fi

printf '%s\n' "$PASTE_URL" > "$URL_FILE.new.$$"
chmod 600 "$URL_FILE.new.$$"
mv -f "$URL_FILE.new.$$" "$URL_FILE"

case "$DELETE_URL" in
  https://pasters.io/d/*)
    printf '%s\n' "$DELETE_URL" > "$DELETE_FILE.new.$$"
    chmod 600 "$DELETE_FILE.new.$$"
    mv -f "$DELETE_FILE.new.$$" "$DELETE_FILE"
    ;;
  *)
    rm -f "$DELETE_FILE"
    ;;
esac

say ""
case "$HTTP_CODE" in
  201)
    say "SUCCESS — complete diagnostic uploaded."
    ;;
  206)
    say "WARNING — pasters.io reports that the paste was truncated."
    say "The uploaded diagnostic may be incomplete."
    ;;
  *)
    say "WARNING — pasters.io returned HTTP $HTTP_CODE."
    say "A paste link was returned, but verify that it opens correctly."
    ;;
esac

say "Paste link:"
say "$PASTE_URL"
say ""
say "The link is also saved privately in:"
say "  $URL_FILE"
if [ -s "$DELETE_FILE" ]; then
  say "A private delete link is saved in:"
  say "  $DELETE_FILE"
  say "The cleanup utility can use it if you later queue this paste for deletion."
else
  say "No remote delete link was returned by the service."
fi
say ""
say "Only the diagnostic log was uploaded. No other files were sent."
sync 2>/dev/null
exit 0
