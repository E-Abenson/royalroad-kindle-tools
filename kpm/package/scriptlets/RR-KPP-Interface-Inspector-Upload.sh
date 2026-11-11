#!/bin/sh
# Name: RR-KPP-Interface-Inspector-Upload
# Deliberately uploads only the sanitised static-inspector report to pasters.io.
#
# PRIVACY:
# - This is a separate launcher; the inspector itself remains offline.
# - The report contains fixed marker names and installed file paths, not raw strings.
# - The paste is readable by anyone who obtains its link; it is not password protected.
# - Pastes are requested with a one-week expiry.
# - The private deletion URL is stored separately with mode 600 and never printed.

DOCS="/mnt/us/documents"
LOG="$DOCS/RR-KPP-Interface-Inspector.log"
DELETE_FILE="$DOCS/.RR-KPP-Interface-Inspector-delete-url.txt"
TMP="/tmp/rr_kpp_inspector_upload_$$"
NEW_LOG="$DOCS/.RR-KPP-Interface-Inspector.log.new.$$"
ENDPOINT="https://pasters.io/?expires=1w"

umask 077
mkdir -p "$DOCS" 2>/dev/null
if ! mkdir -m 700 "$TMP" 2>/dev/null; then
  echo "ERROR: Could not create a private temporary directory."
  exit 1
fi
trap 'rm -rf "$TMP"; rm -f "$NEW_LOG"' 0 HUP INT TERM

UPLOAD_SOURCE="$TMP/inspector-report.txt"
HEADERS="$TMP/response-headers.txt"
BODY="$TMP/response-body.txt"
CURL_ERROR="$TMP/curl-error.txt"

echo "============================================================"
echo "KPP INTERFACE INSPECTOR — OPTIONAL PASters.IO UPLOAD"
echo "This sends only the static inspector report."
echo "Anyone who obtains the returned link can read it."
echo "The paste is requested to expire after one week."
echo "============================================================"

if [ ! -s "$LOG" ]; then
  echo "ERROR: The inspector report does not exist or is empty."
  echo "Run RR-KPP-Interface-Inspector first."
  exit 1
fi
if ! grep -Fq "KPP BROWSER INTERFACE INSPECTOR" "$LOG" 2>/dev/null; then
  echo "ERROR: The selected log does not look like the expected inspector report."
  echo "Nothing was uploaded."
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl is not installed; nothing was uploaded."
  exit 1
fi

# Strip the previous share-link block so repeated uploads never include old links.
awk '
  $0 == "--- PASTERS.IO SHARE LINK ---" { in_share = 1; next }
  $0 == "--- END PASTERS.IO SHARE LINK ---" { in_share = 0; next }
  !in_share { print }
' "$LOG" > "$UPLOAD_SOURCE"

if [ ! -s "$UPLOAD_SOURCE" ]; then
  echo "ERROR: The sanitised report is empty; nothing was uploaded."
  exit 1
fi

echo
echo "Uploading the sanitised report..."
HTTP_CODE="$(curl -sS --connect-timeout 10 --max-time 60 \
  -D "$HEADERS" -o "$BODY" -w '%{http_code}' \
  --data-binary "@$UPLOAD_SOURCE" "$ENDPOINT" 2>"$CURL_ERROR")"
CURL_STATUS=$?

if [ "$CURL_STATUS" -ne 0 ]; then
  echo "ERROR: The upload request failed (curl exit code $CURL_STATUS)."
  if [ -s "$CURL_ERROR" ]; then cat "$CURL_ERROR"; fi
  echo "The local inspector log was not changed."
  exit 1
fi

if [ "$HTTP_CODE" = "206" ]; then
  echo "ERROR: pasters.io returned HTTP 206: the paste was truncated."
  echo "No link was added to the local log."
  if [ -s "$BODY" ]; then cat "$BODY"; fi
  exit 1
fi
if [ "$HTTP_CODE" != "201" ]; then
  echo "ERROR: pasters.io returned HTTP $HTTP_CODE; a complete upload was not confirmed."
  if [ -s "$BODY" ]; then cat "$BODY"; fi
  echo "The local inspector log was not changed."
  exit 1
fi

PASTE_URL="$(sed -n '1p' "$BODY" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
case "$PASTE_URL" in
  https://pasters.io/*) PASTE_ID="${PASTE_URL#https://pasters.io/}" ;;
  *)
    echo "ERROR: Upload returned HTTP 201, but the response did not contain a recognised pasters.io link."
    echo "The local inspector log was not changed."
    exit 1
    ;;
esac
case "$PASTE_ID" in
  ""|*/*|*[!A-Za-z0-9_-]*)
    echo "ERROR: The returned paste link had an unexpected format."
    echo "The local inspector log was not changed."
    exit 1
    ;;
esac

EXPIRES="$(awk 'tolower($1) == "x-paste-expires-in:" { sub(/\r$/, "", $2); print $2; exit }' "$HEADERS" 2>/dev/null)"
[ -n "$EXPIRES" ] || EXPIRES="Not reported; one-week expiry was requested"

DELETE_URL="$(awk 'tolower($1) == "x-delete-url:" { sub(/\r$/, "", $2); print $2; exit }' "$HEADERS" 2>/dev/null)"
DELETE_NOTE="No delete URL was returned; the paste will expire automatically."
case "$DELETE_URL" in
  https://pasters.io/d/*)
    DELETE_PATH="${DELETE_URL#https://pasters.io/d/}"
    case "$DELETE_PATH" in
      ""|*[!A-Za-z0-9._~/?=&%+-]*)
        rm -f "$DELETE_FILE"
        ;;
      *)
        if printf '%s\n' "$DELETE_URL" > "$TMP/delete-url" &&
           chmod 600 "$TMP/delete-url" 2>/dev/null &&
           mv -f "$TMP/delete-url" "$DELETE_FILE"; then
          chmod 600 "$DELETE_FILE" 2>/dev/null || true
          DELETE_NOTE="A private remote-delete link was saved locally."
        else
          rm -f "$DELETE_FILE"
          DELETE_NOTE="The delete URL could not be saved; the paste will expire automatically."
        fi
        ;;
    esac
    ;;
  *)
    rm -f "$DELETE_FILE"
    ;;
esac

{
  echo "--- PASTERS.IO SHARE LINK ---"
  echo "PASTERS.IO SHARE LINK: $PASTE_URL"
  echo "Upload result: HTTP 201 (complete)"
  echo "Requested expiry: 1 week"
  echo "Server-reported remaining lifetime: $EXPIRES"
  echo "Access: anyone with this link can read the report; it is not password protected."
  echo "$DELETE_NOTE"
  echo "--- END PASTERS.IO SHARE LINK ---"
  echo
  cat "$UPLOAD_SOURCE"
} > "$NEW_LOG"

if ! chmod 600 "$NEW_LOG" 2>/dev/null || ! mv -f "$NEW_LOG" "$LOG"; then
  echo "ERROR: The paste was created, but the local log could not be updated."
  echo "The share link is: $PASTE_URL"
  echo "The paste will expire after the requested one-week period."
  exit 1
fi
chmod 600 "$LOG" 2>/dev/null || true
sync 2>/dev/null

echo
echo "SUCCESS: A complete paste was created."
echo "The share link has been saved at the very top of:"
echo "$LOG"
echo
sed -n '1,8p' "$LOG"
exit 0
