#!/bin/sh
# Name: RR-Upload-Diagnostic
# Author: E-Abenson
# Manually upload a redacted copy of the latest browser diagnostic.
# The paste URL is unlisted-by-link, not private. Anyone with the URL can read it.
# This script runs only when the user opens RR-Upload-Diagnostic from the library.

DOCS="/mnt/us/documents"
SOURCE="$DOCS/RR-JS-Smoke-Test.log"
UPLOAD_FILE="$DOCS/.RR-JS-Smoke-Test-upload-$$.txt"
RESPONSE_FILE="$DOCS/.RR-JS-Smoke-Test-response-$$.txt"
URL_FILE="$DOCS/RR-JS-Smoke-Test-upload-url.txt"
LOG="$DOCS/RR-Upload-Diagnostic.log"

umask 077
mkdir -p "$DOCS"
: > "$LOG"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

cleanup() {
  rm -f "$UPLOAD_FILE" "$RESPONSE_FILE"
}
trap cleanup 0 HUP INT TERM

say "============================================================"
say "ROYAL ROAD — DIAGNOSTIC LOG UPLOADER"
say "This uploads only the LIPC diagnostic log, not browser data."
say "The Royal Road story/chapter path is redacted before upload."

if [ ! -s "$SOURCE" ]; then
  say "ERROR: No diagnostic log found at $SOURCE"
  say "Run RR-JS-Smoke-Test first."
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

say "Preparing a private temporary copy..."
if ! sed -E 's#(Last-open page: https?://[^/[:space:]]+)(/[^[:space:]]*)?#\1/ [story path redacted]#' "$SOURCE" > "$UPLOAD_FILE"; then
  say "ERROR: Could not prepare the redacted copy."
  exit 1
fi
chmod 600 "$UPLOAD_FILE"

if grep -Eiq '(cookie|authorization:|bearer[[:space:]]|github_pat_|gh[pousr]_[A-Za-z0-9_]+)' "$UPLOAD_FILE"; then
  say "ERROR: The redacted log contains a credential-like string; upload stopped."
  exit 1
fi

say "Uploading the redacted diagnostic to paste.rs..."
say "The upload happens only because you opened this library item."
HTTP_STATUS="$(curl -sS --connect-timeout 12 --max-time 40 \
  --data-binary "@$UPLOAD_FILE" \
  -o "$RESPONSE_FILE" -w '%{http_code}' \
  https://paste.rs/ 2>> "$LOG")"
CURL_STATUS=$?

if [ "$CURL_STATUS" -ne 0 ]; then
  say "ERROR: HTTPS upload failed (curl exit code $CURL_STATUS)."
  say "No GitHub credentials were used or stored."
  say "Check Wi-Fi and try again later."
  exit 1
fi

PASTE_URL="$(tr -d '\r\n' < "$RESPONSE_FILE" 2>/dev/null)"
if [ "$HTTP_STATUS" != "201" ]; then
  say "ERROR: paste.rs returned HTTP $HTTP_STATUS."
  say "Server response: $PASTE_URL"
  say "No GitHub credentials were used or stored."
  exit 1
fi

case "$PASTE_URL" in
  https://paste.rs/*)
    ;;
  *)
    say "ERROR: The server response was not a paste.rs HTTPS link."
    say "Response was not saved as an upload link."
    exit 1
    ;;
esac

printf '%s\n' "$PASTE_URL" > "$URL_FILE"
chmod 600 "$URL_FILE"

say "UPLOAD SUCCESSFUL."
say "TEMPORARY LINK: $PASTE_URL"
say "The link is readable by anyone who has it. It is not a private upload."
say "Send me that link; I will copy the diagnostic into your GitHub repository."
say "After I confirm the repository copy, the temporary paste can be deleted."
say "Link also saved to: $URL_FILE"
say "Uploader log: $LOG"
exit 0
