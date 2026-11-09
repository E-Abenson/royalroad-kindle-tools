#!/bin/sh
# Name: RR-Upload-Bundle-Scan
# Author: E-Abenson
# Manually upload the filtered output of the KPP bundle scan.
# The paste URL is unlisted-by-link, not private. Anyone with the URL can read it.
# This script runs only when the user opens RR-Upload-Bundle-Scan from the library.

DOCS="/mnt/us/documents"
SOURCE="$DOCS/RR-KPP-Bundle-Scan.log"
UPLOAD_FILE="$DOCS/.RR-KPP-Bundle-Scan-upload-$$.txt"
RESPONSE_FILE="$DOCS/.RR-KPP-Bundle-Scan-response-$$.txt"
HEADERS_FILE="$DOCS/.RR-KPP-Bundle-Scan-headers-$$.txt"
URL_FILE="$DOCS/RR-KPP-Bundle-Scan-upload-url.txt"
DELETE_FILE="$DOCS/RR-KPP-Bundle-Scan-delete-url.txt"
LOG="$DOCS/RR-Upload-Bundle-Scan.log"

umask 077
mkdir -p "$DOCS"
: > "$LOG"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

cleanup() {
  rm -f "$UPLOAD_FILE" "$RESPONSE_FILE" "$HEADERS_FILE"
}
trap cleanup 0 HUP INT TERM

say "============================================================"
say "ROYAL ROAD — KPP BUNDLE SCAN UPLOADER"
say "This uploads only the filtered KPP bundle scan log, not browser data."
say "The scanner filters results and omits Royal Road page paths before upload."

if [ ! -s "$SOURCE" ]; then
  say "ERROR: No diagnostic log found at $SOURCE"
  say "Run RR-KPP-Bundle-Scan first."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  say "ERROR: curl is not installed; no upload was attempted."
  exit 1
fi

SIZE="$(wc -c < "$SOURCE" | tr -d ' ')"
case "$SIZE" in
  ''|*[!0-9]*) say "ERROR: Could not determine log size."; exit 1 ;;
esac
if [ "$SIZE" -gt 65536 ]; then
  say "ERROR: Diagnostic log is larger than 64 KiB; no upload was attempted."
  exit 1
fi

say "Preparing a temporary copy..."
if ! sed -E 's#(Last-open page: https?://[^/[:space:]]+)(/[^[:space:]]*)?#\1/ [story path redacted]#' "$SOURCE" > "$UPLOAD_FILE"; then
  say "ERROR: Could not prepare the redacted copy."
  exit 1
fi
chmod 600 "$UPLOAD_FILE"

if grep -Eiq '(cookie|authorization:|bearer[[:space:]]|github_pat_|gh[pousr]_[A-Za-z0-9_]+)' "$UPLOAD_FILE"; then
  say "ERROR: The redacted log contains a credential-like string; upload stopped."
  exit 1
fi

say "Uploading the redacted diagnostic to pasters.io (expires in one week)..."
say "The upload happens only because you opened this library item."
HTTP_STATUS="$(curl -sS --connect-timeout 12 --max-time 40 \
  -X POST \
  -H "Content-Type: text/plain; charset=utf-8" \
  -H "Accept: text/plain" \
  --data-binary "@$UPLOAD_FILE" \
  -D "$HEADERS_FILE" -o "$RESPONSE_FILE" -w '%{http_code}' \
  'https://pasters.io/?expires=1w' 2>> "$LOG")"
CURL_STATUS=$?

if [ "$CURL_STATUS" -ne 0 ]; then
  say "ERROR: HTTPS upload failed (curl exit code $CURL_STATUS)."
  say "No GitHub credentials were used or stored."
  say "Check Wi-Fi and try again later."
  exit 1
fi

PASTE_URL="$(tr -d '\r\n' < "$RESPONSE_FILE" 2>/dev/null)"
if [ "$HTTP_STATUS" != "201" ]; then
  say "ERROR: pasters.io returned HTTP $HTTP_STATUS."
  say "Server response: $PASTE_URL"
  say "No GitHub credentials were used or stored."
  exit 1
fi

case "$PASTE_URL" in
  https://pasters.io/*)
    ;;
  *)
    say "ERROR: The server did not return a pasters.io HTTPS link."
    say "Response was not saved as an upload link."
    exit 1
    ;;
esac

DELETE_URL="$(awk 'tolower($1) == "x-delete-url:" {sub(/\r$/, "", $2); print $2; exit}' "$HEADERS_FILE")"
if [ -z "$DELETE_URL" ]; then
  say "ERROR: Upload may have succeeded, but the service did not return its deletion URL."
  say "The paste link is: $PASTE_URL"
  say "Keep this link private and tell me; it expires in one week."
  exit 1
fi

printf '%s\n' "$PASTE_URL" > "$URL_FILE"
printf '%s\n' "$DELETE_URL" > "$DELETE_FILE"
chmod 600 "$URL_FILE" "$DELETE_FILE"

say "UPLOAD SUCCESSFUL."
say "TEMPORARY LINK: $PASTE_URL"
say "The link is readable by anyone who has it; it is not private."
say "It expires in one week. A separate deletion URL is saved locally on the Kindle; do not share it."
say "Send me the temporary link so I can review the scan results."
say "After I confirm the repository copy, I can guide you to delete the temporary paste."
say "Paste link saved to: $URL_FILE"
say "Deletion URL saved to: $DELETE_FILE"
say "Uploader log: $LOG"
exit 0
