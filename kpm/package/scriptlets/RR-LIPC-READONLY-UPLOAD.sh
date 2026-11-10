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
SANITIZED="$TMP.sanitized"

umask 077
trap 'rm -f "$HEADERS" "$BODY" "$SANITIZED" "$TMP.curl-error"' EXIT HUP INT TERM

say() { printf '%s\n' "$*"; }

say "KINDLE — UPLOAD READ-ONLY LIPC DIAGNOSTIC"
say "============================================================"
say "This sends the contents of:"
say "  $LOG"
say "to pasters.io, where it can be viewed by anyone with the link."
say "The paste is requested to expire after one week."
say ""
say "The raw log contains device and LIPC information, including private Amazon credentials."
say "A sanitized copy will be uploaded: credential-bearing services, identity fields"
say "and the current browser URL are removed or redacted. The original stays local."
say "Review the sanitized copy before proceeding. No other files are uploaded."
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

# Build a share-safe copy. Entire credential-bearing service sections are omitted,
# sensitive property values are redacted, and the current browser URL is hidden.
if ! awk '
function private_service(s) {
  return s == "com.lab126.amazonRegistrationService" ||
         s == "com.lab126.DeviceAuthenticationService" ||
         s == "com.lab126.kppkaf" ||
         s == "com.lab126.household" ||
         s == "com.lab126.IdentityService" ||
         s == "com.lab126.stored" ||
         s == "com.lab126.KindleIdentity" ||
         s == "com.lab126.PasswordService" ||
         s == "com.lab126.freetime" ||
         s == "com.lab126.accountinfoprovider"
}
/^---- Browser \/ KPP \/ Chrome \/ WebKit matches ----$/ {
  print
  print "[Duplicate excerpt omitted; the complete service inventory appears above.]"
  skip_matches = 1
  next
}
skip_matches { next }
/^[^ \t]+$/ && $0 ~ /^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+)+$/ {
  service = $0
  skip = private_service(service)
  if (skip) {
    print service
    print "\t[properties omitted for credential and account safety]"
    next
  }
}
skip { next }
{
  low = tolower($0)
  if (low ~ /getlastopenpage/) {
    sub(/\[.*/, "[URL REDACTED]")
    print
    next
  }
  if (low ~ /(token|cookie|auth|password|session|secret|credential|email|primaryuserid|directedid|profile|household|user|phone|guid|ubid|passcode)/) {
    if ($0 ~ /\[/) sub(/\[.*/, "[REDACTED]")
    else if ($0 ~ /=/) sub(/=.*/, "=[REDACTED]")
    else $0 = "[REDACTED]"
  }
  print
}
' "$LOG" > "$SANITIZED"; then
  say "ERROR: Could not create sanitized diagnostic copy."
  exit 1
fi
if [ ! -s "$SANITIZED" ]; then
  say "ERROR: Sanitization produced an empty file; nothing was uploaded."
  exit 1
fi

if [ -t 0 ]; then
  printf 'To upload the SANITIZED log, type UPLOAD exactly: '
  IFS= read -r CONFIRM
  if [ "$CONFIRM" != "UPLOAD" ]; then
    say "Cancelled. Nothing was uploaded."
    exit 0
  fi
else
  say "No keyboard prompt is available in this launcher."
  say "Opening this dedicated uploader is treated as confirmation to upload the SANITIZED copy."
fi

mkdir -p "$DOCS" 2>/dev/null
say ""
say "Uploading the sanitized LIPC diagnostic copy..."

HTTP_CODE="$(curl -sS --connect-timeout 10 --max-time 45 \
  -D "$HEADERS" -o "$BODY" -w '%{http_code}' \
  --data-binary "@$SANITIZED" "$UPLOAD_URL" 2>"$TMP.curl-error")"
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
say "Only the sanitized diagnostic copy was uploaded. The original log was not changed and remains local."
sync 2>/dev/null
exit 0
