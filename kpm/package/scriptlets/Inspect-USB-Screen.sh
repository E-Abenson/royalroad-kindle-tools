#!/bin/sh
# Name: Inspect-USB-Screen
# Build: 1.1
# Read-only inventory of the stock USB-mode display assets.
# Uploads only the text report to pasters.io with a one-day expiry.
# The image files themselves remain in a local Documents archive.

DOCS="/mnt/us/documents"
USB_DIR="/usr/share/blanket/usb"
WORK="$DOCS/.usb-screen-inspection.$$"
ARCHIVE="$DOCS/USB-Screen-Inspection.tar.gz"
ARCHIVE_TEMP="$ARCHIVE.new.$$"
REPORT="$WORK/USB-Screen-Inspection.txt"
LOCAL_REPORT="$DOCS/USB-Screen-Inspection.txt"
PASTE_NOTE="$DOCS/USB-Screen-Inspection-Paste.txt"
PASTE_NOTE_TEMP="$PASTE_NOTE.new.$"
DELETE_FILE="$DOCS/.USB-Screen-Inspection-delete-url.txt"
DELETE_TEMP="$DELETE_FILE.new.$"
ENDPOINT="https://pasters.io/?expires=1d"

umask 077

cleanup() {
  rm -f "$ARCHIVE_TEMP" "$PASTE_NOTE_TEMP" "$DELETE_TEMP"
  rm -rf "$WORK"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

mkdir -p "$DOCS" || {
  printf '%s\n' "FAILURE: Could not create the Documents folder."
  exit 1
}
if ! mkdir -m 700 "$WORK" 2>/dev/null; then
  printf '%s\n' "FAILURE: Could not create a private temporary directory."
  exit 1
fi
rm -f "$PASTE_NOTE" "$PASTE_NOTE_TEMP" "$LOCAL_REPORT" "$DELETE_FILE" "$DELETE_TEMP"
: > "$REPORT"

say() {
  printf '%s\n' "$*" | tee -a "$REPORT"
}

first_line() {
  FILE="$1"
  if [ -r "$FILE" ]; then
    sed -n '1p' "$FILE" | tr -d '\r'
  else
    printf '%s' "Not found"
  fi
}

png_dimensions() {
  FILE="$1"
  if command -v od >/dev/null 2>&1; then
    set -- $(od -An -tu1 -j16 -N8 "$FILE" 2>/dev/null)
    if [ "$#" -eq 8 ]; then
      WIDTH=$(( $1 * 16777216 + $2 * 65536 + $3 * 256 + $4 ))
      HEIGHT=$(( $5 * 16777216 + $6 * 65536 + $7 * 256 + $8 ))
      printf '%s x %s' "$WIDTH" "$HEIGHT"
      return 0
    fi
  fi
  printf '%s' "unavailable"
}

say "KINDLE USB DISPLAY — READ-ONLY INSPECTION"
say "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
say ""
say "DEVICE"
say "Model: $(first_line /var/local/deviceType.txt)"
say "Firmware: $(first_line /etc/prettyversion.txt)"
say "Architecture: $(uname -m 2>/dev/null || echo unavailable)"
say ""
say "DISPLAY INFORMATION"
if [ -x /usr/sbin/eips ]; then
  say "eips -i:"
  /usr/sbin/eips -i 2>&1 | tee -a "$REPORT"
else
  say "eips: not found at /usr/sbin/eips"
fi
if [ -x /usr/bin/fbink ]; then
  say "fbink -i:"
  /usr/bin/fbink -i 2>&1 | tee -a "$REPORT"
elif command -v fbink >/dev/null 2>&1; then
  say "fbink -i:"
  fbink -i 2>&1 | tee -a "$REPORT"
else
  say "fbink: not found"
fi
say ""
say "USB DISPLAY ASSET DIRECTORY"
say "Expected path: $USB_DIR"
if [ -d "$USB_DIR" ]; then
  say "Directory: present"
  ls -ldn "$USB_DIR" 2>&1 | tee -a "$REPORT"
  say "Directory listing:"
  ls -lan "$USB_DIR" 2>&1 | tee -a "$REPORT"
  say ""
  say "Individual files (permissions, size, SHA256/checksum, PNG dimensions):"
  if command -v find >/dev/null 2>&1; then
    find "$USB_DIR" -type f -print | sort | while IFS= read -r ITEM; do
      [ -r "$ITEM" ] || {
        printf 'UNREADABLE: %s\n' "$ITEM" >> "$REPORT"
        continue
      }
      printf 'FILE: %s\n' "$ITEM" >> "$REPORT"
      ls -ln "$ITEM" 2>&1 >> "$REPORT"
      case "$ITEM" in
        *.png|*.PNG)
          printf 'PNG dimensions: %s\n' "$(png_dimensions "$ITEM")" >> "$REPORT"
          ;;
      esac
      if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$ITEM" 2>&1 >> "$REPORT"
      elif command -v cksum >/dev/null 2>&1; then
        cksum "$ITEM" 2>&1 >> "$REPORT"
      else
        printf 'Checksum utility: unavailable\n' >> "$REPORT"
      fi
      if command -v file >/dev/null 2>&1; then
        file "$ITEM" 2>&1 >> "$REPORT"
      fi
      printf '\n' >> "$REPORT"
    done
  else
    say "find is unavailable; recursive file inventory could not be produced."
  fi
  if cp -pR "$USB_DIR" "$WORK/" 2>/dev/null; then
    say "A copy of the complete USB asset folder is included in the local archive."
  else
    say "WARNING: The USB folder could not be copied in full. The report still contains the accessible listing."
  fi
else
  say "Directory: NOT FOUND"
  say "No system files were changed."
fi

say ""
say "SAFETY AND SHARING"
say "This inspection only reads system metadata and files under $USB_DIR."
say "It does not remount / read-write, replace images, change permissions, restart services, or alter the USB connection."
say "Only this text report is uploaded to pasters.io. The image files are not uploaded."
say "The paste is readable by anyone who obtains its link and is requested to expire after one day."
say ""
say "NEXT STEP"
say "Paste the PASTERS.IO link printed at the end of this run into the ChatGPT conversation."

ARCHIVE_OK=0
if command -v tar >/dev/null 2>&1 &&
   tar -czf "$ARCHIVE_TEMP" -C "$WORK" . 2>/dev/null &&
   tar -tzf "$ARCHIVE_TEMP" >/dev/null 2>&1 &&
   mv -f "$ARCHIVE_TEMP" "$ARCHIVE"; then
  ARCHIVE_OK=1
  say ""
  say "Local image archive: $ARCHIVE"
  if command -v sha256sum >/dev/null 2>&1; then
    say "Archive SHA256: $(sha256sum "$ARCHIVE" | awk '{print $1}')"
  fi
else
  say "WARNING: The local tar.gz archive could not be created."
fi

if ! command -v curl >/dev/null 2>&1; then
  cp "$REPORT" "$LOCAL_REPORT" 2>/dev/null || true
  chmod 600 "$LOCAL_REPORT" 2>/dev/null || true
  printf '%s\n' "UPLOAD FAILURE: curl is unavailable; the report remains in Documents."
  exit 1
fi

HEADERS="$WORK/response-headers.txt"
BODY="$WORK/response-body.txt"
CURL_ERROR="$WORK/curl-error.txt"

say ""
say "Uploading the text report to pasters.io (one-day expiry requested)..."
HTTP_CODE="$(curl -sS --connect-timeout 15 --max-time 90 \
  -D "$HEADERS" -o "$BODY" -w '%{http_code}' \
  --data-binary "@$REPORT" "$ENDPOINT" 2>"$CURL_ERROR")"
CURL_STATUS=$?

if [ "$CURL_STATUS" -ne 0 ]; then
  cp "$REPORT" "$LOCAL_REPORT" 2>/dev/null || true
  chmod 600 "$LOCAL_REPORT" 2>/dev/null || true
  printf '%s\n' "UPLOAD FAILURE: curl returned exit code $CURL_STATUS."
  if [ -s "$CURL_ERROR" ]; then cat "$CURL_ERROR"; fi
  printf '%s\n' "Local report: $LOCAL_REPORT"
  [ "$ARCHIVE_OK" -eq 1 ] && printf '%s\n' "Local image archive: $ARCHIVE"
  exit 1
fi

if [ "$HTTP_CODE" = "206" ]; then
  cp "$REPORT" "$LOCAL_REPORT" 2>/dev/null || true
  chmod 600 "$LOCAL_REPORT" 2>/dev/null || true
  printf '%s\n' "UPLOAD FAILURE: pasters.io returned HTTP 206; the paste was truncated."
  [ -s "$BODY" ] && cat "$BODY"
  exit 1
fi
if [ "$HTTP_CODE" != "201" ]; then
  cp "$REPORT" "$LOCAL_REPORT" 2>/dev/null || true
  chmod 600 "$LOCAL_REPORT" 2>/dev/null || true
  printf '%s\n' "UPLOAD FAILURE: pasters.io returned HTTP $HTTP_CODE; a complete upload was not confirmed."
  [ -s "$BODY" ] && cat "$BODY"
  printf '%s\n' "Local report: $LOCAL_REPORT"
  [ "$ARCHIVE_OK" -eq 1 ] && printf '%s\n' "Local image archive: $ARCHIVE"
  exit 1
fi

PASTE_URL="$(sed -n '1p' "$BODY" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
case "$PASTE_URL" in
  https://pasters.io/*) PASTE_ID="$(printf '%s\n' "$PASTE_URL" | sed 's#^https://pasters.io/##')" ;;
  *)
    cp "$REPORT" "$LOCAL_REPORT" 2>/dev/null || true
    chmod 600 "$LOCAL_REPORT" 2>/dev/null || true
    printf '%s\n' "UPLOAD FAILURE: HTTP 201 was returned, but no recognised pasters.io link was received."
    printf '%s\n' "The local report remains at $LOCAL_REPORT"
    exit 1
    ;;
esac
case "$PASTE_ID" in
  ""|*/*|*[!A-Za-z0-9_-]*)
    cp "$REPORT" "$LOCAL_REPORT" 2>/dev/null || true
    chmod 600 "$LOCAL_REPORT" 2>/dev/null || true
    printf '%s\n' "UPLOAD FAILURE: The returned paste link had an unexpected format."
    exit 1
    ;;
esac

EXPIRES="$(awk 'tolower($1) == "x-paste-expires-in:" { sub(/\r$/, "", $2); print $2; exit }' "$HEADERS" 2>/dev/null)"
[ -n "$EXPIRES" ] || EXPIRES="Not reported; one-day expiry was requested"

# Save Pasters' per-paste deletion URL privately; never print or upload it.
DELETE_URL="$(awk 'tolower($1) == "x-delete-url:" { sub(/\r$/, "", $2); print $2; exit }' "$HEADERS" 2>/dev/null)"
DELETE_SAVED=0
case "$DELETE_URL" in
  https://pasters.io/d/*)
    DELETE_PATH="${DELETE_URL#https://pasters.io/d/}"
    case "$DELETE_PATH" in
      ""|*[!A-Za-z0-9._~/?=\&%+-]*)
        rm -f "$DELETE_TEMP"
        ;;
      *)
        if printf '%s\\n' "$DELETE_URL" > "$DELETE_TEMP" &&
           chmod 600 "$DELETE_TEMP" 2>/dev/null &&
           mv -f "$DELETE_TEMP" "$DELETE_FILE"; then
          DELETE_SAVED=1
        else
          rm -f "$DELETE_TEMP" "$DELETE_FILE"
        fi
        ;;
    esac
    ;;
  *)
    rm -f "$DELETE_FILE" "$DELETE_TEMP"
    ;;
esac

{
  printf 'PASTERS.IO SHARE LINK\n'
  printf '%s\n' "$PASTE_URL"
  printf 'Upload result: HTTP 201 (complete)\n'
  printf 'Requested expiry: one day\n'
  printf 'Server-reported remaining lifetime: %s\n' "$EXPIRES"
  printf 'Access: anyone who obtains this link can read the text report.\n'
  printf 'Only the text report was uploaded; the image files remain in the local archive.\n'
} > "$PASTE_NOTE_TEMP"

if ! chmod 600 "$PASTE_NOTE_TEMP" 2>/dev/null ||
   ! mv -f "$PASTE_NOTE_TEMP" "$PASTE_NOTE"; then
  printf '%s\n' "WARNING: The paste was created, but its link could not be saved locally."
fi

say ""
say "SUCCESS: The complete text report was uploaded."
say "PASTERS.IO LINK: $PASTE_URL"
say "Requested expiry: one day. Server report: $EXPIRES"
say "Paste link saved to: $PASTE_NOTE"
if [ "$DELETE_SAVED" -eq 1 ]; then
  say "Private early-deletion link saved with restricted permissions."
else
  say "Pasters did not return a private deletion link; the paste will expire as requested."
fi
say "Local text report: $LOCAL_REPORT"
if [ "$ARCHIVE_OK" -eq 1 ]; then
  say "Local image archive: $ARCHIVE"
fi

cp "$REPORT" "$LOCAL_REPORT" 2>/dev/null || true
chmod 600 "$LOCAL_REPORT" 2>/dev/null || true
sync 2>/dev/null || true
exit 0
