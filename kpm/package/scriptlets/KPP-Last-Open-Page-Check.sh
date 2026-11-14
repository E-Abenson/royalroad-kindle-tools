#!/bin/sh
# Name: KPP-Last-Open-Page-Check
# Build: 1.0
# Read-only test of com.lab126.kppbrowser.getLastOpenPage.
# The exact returned value is stored privately on the Kindle and is never uploaded.

DOCS="/mnt/us/documents"
INTERNAL="$DOCS/.royalroadtools"
REPORT="$DOCS/KPP-Last-Open-Page-Check.txt"
REPORT_TMP="$DOCS/.KPP-Last-Open-Page-Check.txt.tmp.$$"
PRIVATE="$INTERNAL/last-open-page-private.txt"
TMP="$INTERNAL/.last-open-page-check.$$"

umask 077
mkdir -p "$DOCS" "$INTERNAL" 2>/dev/null || {
  echo "FAILURE: Cannot prepare the private Kindle Documents folder."
  exit 1
}
chmod 700 "$INTERNAL" 2>/dev/null || true
mkdir "$TMP" 2>/dev/null || {
  echo "FAILURE: Cannot create the temporary test folder."
  exit 1
}
cleanup() {
  rm -rf "$TMP"
  rm -f "$REPORT_TMP"
}
trap cleanup 0 HUP INT TERM

RAW="$TMP/property-value.txt"
ERR="$TMP/property-error.txt"
HEADERS="$TMP/paste-headers.txt"
RESPONSE="$TMP/paste-response.txt"
CURL_ERROR="$TMP/curl-error.txt"

# Do not let a failed run leave a previous page value looking current.
rm -f "$PRIVATE" 2>/dev/null

if ! command -v lipc-get-prop >/dev/null 2>&1; then
  echo "FAILURE: lipc-get-prop is unavailable; no property query was made."
  exit 1
fi

echo "Testing the read-only KPP last-open-page property..."
if lipc-get-prop com.lab126.kppbrowser getLastOpenPage > "$RAW" 2> "$ERR"; then
  COMMAND_STATUS=0
else
  COMMAND_STATUS=$?
fi

OUTPUT_BYTES="$(wc -c < "$RAW" 2>/dev/null | tr -d ' ')"
OUTPUT_LINES="$(awk 'END { print NR+0 }' "$RAW" 2>/dev/null)"
case "$OUTPUT_BYTES" in ""|*[!0-9]*) OUTPUT_BYTES=0 ;; esac
case "$OUTPUT_LINES" in ""|*[!0-9]*) OUTPUT_LINES=0 ;; esac

save_private_value() {
  if [ "$OUTPUT_BYTES" -gt 0 ]; then
    if cp "$RAW" "$TMP/private-result.tmp" &&
       chmod 600 "$TMP/private-result.tmp" &&
       mv -f "$TMP/private-result.tmp" "$PRIVATE"; then
      return 0
    fi
    return 1
  fi
  return 0
}

# A simple one-line success or failure is shown directly and is not uploaded.
if [ "$OUTPUT_LINES" -le 1 ]; then
  if [ "$OUTPUT_BYTES" -gt 0 ] && ! save_private_value; then
    echo "FAILURE: The property returned data, but the private result could not be saved."
    exit 1
  fi
  if [ "$COMMAND_STATUS" -eq 0 ] && [ "$OUTPUT_BYTES" -gt 0 ]; then
    echo "SUCCESS: getLastOpenPage returned a value; the exact value is saved privately on the Kindle. No paste was uploaded (one-line result)."
    sync 2>/dev/null
    exit 0
  fi
  if [ "$COMMAND_STATUS" -ne 0 ]; then
    echo "FAILURE: getLastOpenPage returned exit code $COMMAND_STATUS and no usable one-line result. No paste was uploaded (one-line result)."
  else
    echo "FAILURE: getLastOpenPage returned an empty value. No paste was uploaded (one-line result)."
  fi
  exit 1
fi

# Multiline command output is kept private. Only counts and coarse classifications
# are included in the report; neither the URL nor the raw error text is uploaded.
if ! save_private_value; then
  echo "FAILURE: Multiline property output was returned but could not be saved privately."
  exit 1
fi

if [ -s "$ERR" ]; then
  if grep -qi 'permission denied\|access denied\|not authorized' "$ERR"; then
    ERROR_CLASS="access-denied"
  elif grep -qi 'unknown property\|unknown method\|unknown service\|not found\|no such' "$ERR"; then
    ERROR_CLASS="property-or-service-not-found"
  elif grep -qi 'timeout\|connection\|no reply\|disconnected' "$ERR"; then
    ERROR_CLASS="communication-error"
  else
    ERROR_CLASS="other-error-text-suppressed"
  fi
else
  ERROR_CLASS="none-or-no-stderr"
fi

if grep -Eiq 'https?://' "$RAW"; then
  URL_SCHEME="present; host and path withheld"
else
  URL_SCHEME="not detected"
fi

: > "$REPORT_TMP"
{
  echo "KPP READ-ONLY LAST-OPEN-PAGE PROPERTY CHECK"
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
  echo "Tool build: 1.0"
  echo "Property: com.lab126.kppbrowser.getLastOpenPage"
  echo "Command exit status: $COMMAND_STATUS"
  echo "Captured stdout: $OUTPUT_BYTES bytes; $OUTPUT_LINES lines"
  echo "URL scheme: $URL_SCHEME"
  echo "Stderr classification: $ERROR_CLASS"
  if [ "$COMMAND_STATUS" -eq 0 ] && [ "$OUTPUT_BYTES" -gt 0 ]; then
    echo "Result: property returned multiline data."
  else
    echo "Result: property query did not complete successfully."
  fi
  echo "Exact property value: withheld from this report and from the upload."
  echo "Private result file: Documents/.royalroadtools/last-open-page-private.txt"
  echo "No property was written; no browser action, navigation, refresh, or JavaScript was attempted."
} > "$REPORT_TMP"
chmod 600 "$REPORT_TMP" 2>/dev/null || true
if ! mv -f "$REPORT_TMP" "$REPORT"; then
  echo "FAILURE: Multiline diagnostic was collected but could not be saved."
  exit 1
fi

# Keep this rule explicit: a one-line SUCCESS/FAILURE never creates a paste.
REPORT_LINES="$(awk 'END { print NR+0 }' "$REPORT" 2>/dev/null)"
if [ "$REPORT_LINES" -eq 1 ] && grep -Eq '^(SUCCESS|FAILURE):' "$REPORT"; then
  cat "$REPORT"
  exit 0
fi

echo "Multiline result collected. Uploading the sanitized report to pasters.io..."
if ! command -v curl >/dev/null 2>&1; then
  echo "UPLOAD NOT DONE: curl is unavailable. Local sanitized report retained."
  exit 0
fi

HTTP_STATUS="$(curl -sS --connect-timeout 10 --max-time 45 \
  -X POST \
  -H "Content-Type: text/plain; charset=utf-8" \
  -H "Accept: text/plain" \
  --data-binary "@$REPORT" \
  -D "$HEADERS" -o "$RESPONSE" -w '%{http_code}' \
  'https://pasters.io/?expires=1w' 2> "$CURL_ERROR")"
CURL_STATUS=$?

if [ "$CURL_STATUS" -ne 0 ]; then
  echo "UPLOAD FAILED: HTTPS request failed. Local sanitized report retained at $REPORT"
  exit 0
fi

PASTE_URL="$(tr -d '\r\n' < "$RESPONSE" 2>/dev/null)"
case "$PASTE_URL" in
  https://pasters.io/*) ;;
  *)
    PASTE_URL="$(tr -d '\r' < "$HEADERS" | awk 'tolower($1)=="location:" {sub(/^[^:]*:[ \t]*/, ""); print; exit}')"
    ;;
esac
DELETE_URL="$(tr -d '\r' < "$HEADERS" | awk 'tolower($1)=="x-delete-url:" {sub(/^[^:]*:[ \t]*/, ""); print; exit}')"

if [ "$HTTP_STATUS" = "201" ]; then
  case "$PASTE_URL" in
    https://pasters.io/*)
      printf '%s\n' "$PASTE_URL" > "$TMP/paste-url.txt"
      chmod 600 "$TMP/paste-url.txt"
      mv -f "$TMP/paste-url.txt" "$DOCS/KPP-Last-Open-Page-Check-upload-url.txt"
      case "$DELETE_URL" in
        https://pasters.io/d/*)
          printf '%s\n' "$DELETE_URL" > "$TMP/delete-url.txt"
          chmod 600 "$TMP/delete-url.txt"
          mv -f "$TMP/delete-url.txt" "$DOCS/KPP-Last-Open-Page-Check-delete-url.txt"
          ;;
      esac
      echo "UPLOAD COMPLETE (HTTP 201)."
      echo "Paste link: $PASTE_URL"
      echo "The paste contains only the sanitized multiline report; the page value remains private on the Kindle."
      echo "One-week expiry was requested."
      ;;
    *)
      echo "UPLOAD UNVERIFIED (HTTP 201): no valid Pasters.io link was returned."
      echo "Local sanitized report retained at $REPORT"
      ;;
  esac
else
  echo "UPLOAD NOT VERIFIED (HTTP $HTTP_STATUS)."
  echo "Local sanitized report retained at $REPORT"
fi

sync 2>/dev/null
exit 0
