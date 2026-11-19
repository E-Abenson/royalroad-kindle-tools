#!/bin/sh
# Name: KPP-JavaScript-Bundle-Export
# Build: 1.0
# Copies the installed KPP Hermes JavaScript bundle to USB-visible Documents.
# Read-only: the original application file is never changed or executed.
# No page content, browser state, cookies, history, or network upload is involved.
set -u

KPP_BUNDLE_EXPORT_TEST_ROOT="$(env | sed -n 's/^KPP_BUNDLE_EXPORT_TEST_ROOT=//p' | sed -n '1p')"
if [ -n "$KPP_BUNDLE_EXPORT_TEST_ROOT" ]; then
  DOCS="$KPP_BUNDLE_EXPORT_TEST_ROOT/documents"
  SOURCE="$KPP_BUNDLE_EXPORT_TEST_ROOT/app/KPPMainApp/js/KPPMainApp.js.hbc"
else
  DOCS="/mnt/us/documents"
  SOURCE="/app/KPPMainApp/js/KPPMainApp.js.hbc"
fi

DEST="$DOCS/KPPMainApp.js.hbc"
REPORT="$DOCS/KPP-JavaScript-Bundle-Export.txt"
TMP_DEST="$DOCS/.KPPMainApp.js.hbc.tmp.$$"
TMP_REPORT="$DOCS/.KPP-JavaScript-Bundle-Export.txt.tmp.$$"
MAX_BYTES=52428800
EXPECTED_MAGIC="c61fbc03c103191f"

umask 077
mkdir -p "$DOCS" 2>/dev/null || {
  echo "FAILURE: Could not prepare Kindle Documents."
  exit 1
}
trap 'rm -f "$TMP_DEST" "$TMP_REPORT"' 0 HUP INT TERM

write_report() {
  STATUS="$1"
  {
    echo "KPP JAVASCRIPT BUNDLE EXPORT"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Status: $STATUS"
    echo "Source: $SOURCE"
    echo "USB transfer copy: $DEST"
    echo "The original /app application file was not changed."
    echo "The bundle was not executed, modified, disassembled, or uploaded."
    echo "No page URL, page text, cookies, browser history, or runtime data was collected."
  } > "$TMP_REPORT"
  chmod 644 "$TMP_REPORT" 2>/dev/null || true
  mv -f "$TMP_REPORT" "$REPORT" || return 1
  chmod 644 "$REPORT" 2>/dev/null || true
}

if [ ! -r "$SOURCE" ]; then
  write_report "SOURCE NOT READABLE — no copy made."
  echo "KPP bundle export: source not readable."
  exit 1
fi

SIZE="$(wc -c < "$SOURCE" 2>/dev/null | tr -d ' ')"
case "$SIZE" in
  ''|*[!0-9]*)
    write_report "COULD NOT DETERMINE SOURCE SIZE — no copy made."
    echo "KPP bundle export: could not determine file size."
    exit 1
    ;;
esac

if [ "$SIZE" -le 0 ] || [ "$SIZE" -gt "$MAX_BYTES" ]; then
  write_report "SOURCE SIZE OUTSIDE SAFE LIMIT (bytes=$SIZE) — no copy made."
  echo "KPP bundle export: source size outside the 50 MB safety limit."
  exit 1
fi

for TOOL in sha256sum od awk tr cp wc mv env sed; do
  if ! command -v "$TOOL" >/dev/null 2>&1; then
    write_report "Required utility '$TOOL' is missing — no copy made."
    echo "KPP bundle export: required utility '$TOOL' is unavailable."
    exit 1
  fi
done

MAGIC="$(od -An -tx1 -N8 "$SOURCE" 2>/dev/null | tr -d '[:space:]')"
if [ "$MAGIC" != "$EXPECTED_MAGIC" ]; then
  write_report "SOURCE DOES NOT HAVE THE EXPECTED HERMES MAGIC — no copy made."
  echo "KPP bundle export: source did not match the expected Hermes HBC header."
  exit 1
fi

SOURCE_SHA="$(sha256sum "$SOURCE" 2>/dev/null | awk '{print $1}')"
if [ -z "$SOURCE_SHA" ]; then
  write_report "COULD NOT HASH SOURCE — no copy made."
  echo "KPP bundle export: could not hash source."
  exit 1
fi

if [ -s "$DEST" ]; then
  DEST_SHA="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"
else
  DEST_SHA=""
fi

if [ "$SOURCE_SHA" != "$DEST_SHA" ]; then
  if ! cp "$SOURCE" "$TMP_DEST"; then
    write_report "COPY FAILED — previous Documents copy retained."
    echo "KPP bundle export: copy failed."
    exit 1
  fi
  chmod 644 "$TMP_DEST" 2>/dev/null || true
  COPIED_SHA="$(sha256sum "$TMP_DEST" 2>/dev/null | awk '{print $1}')"
  if [ "$COPIED_SHA" != "$SOURCE_SHA" ]; then
    write_report "COPY VERIFICATION FAILED — previous Documents copy retained."
    echo "KPP bundle export: copy verification failed."
    exit 1
  fi
  if ! mv -f "$TMP_DEST" "$DEST"; then
    write_report "COULD NOT REPLACE DOCUMENTS COPY — previous copy retained."
    echo "KPP bundle export: could not replace destination."
    exit 1
  fi
  RESULT="COPIED TO DOCUMENTS AND SHA256 VERIFIED"
else
  RESULT="ALREADY CURRENT — SHA256 MATCH"
fi

HBC_VERSION="$(od -An -tu4 -j8 -N4 "$DEST" 2>/dev/null | tr -d ' ')"
[ -n "$HBC_VERSION" ] || HBC_VERSION="unavailable"
FINAL_SIZE="$(wc -c < "$DEST" 2>/dev/null | tr -d ' ')"
FINAL_SHA="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"

{
  echo "KPP JAVASCRIPT BUNDLE EXPORT"
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Status: $RESULT"
  echo "Source: $SOURCE"
  echo "USB transfer copy: $DEST"
  echo "File size: $FINAL_SIZE bytes"
  echo "Hermes bytecode version (header field): $HBC_VERSION"
  echo "SHA256: $FINAL_SHA"
  echo "The original /app KPP application file was not changed."
  echo "The bundle was not executed, modified, disassembled, or uploaded."
  echo "No page URL, page text, cookies, browser history, or runtime data was collected."
  echo "Next: connect the Kindle by USB and attach KPPMainApp.js.hbc to the ChatGPT conversation."
} > "$TMP_REPORT"
chmod 644 "$TMP_REPORT" 2>/dev/null || true
if ! mv -f "$TMP_REPORT" "$REPORT"; then
  echo "KPP bundle copied, but export report could not be replaced."
  exit 1
fi
chmod 644 "$REPORT" "$DEST" 2>/dev/null || true

sync 2>/dev/null
echo "SUCCESS: KPP bundle export — $RESULT."
echo "File: $DEST"
echo "Bytes: $FINAL_SIZE; Hermes version: $HBC_VERSION."
echo "Attach KPPMainApp.js.hbc directly in ChatGPT after USB transfer."
exit 0
