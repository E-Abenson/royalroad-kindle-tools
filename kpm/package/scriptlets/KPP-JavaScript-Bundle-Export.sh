#!/bin/sh
# Name: KPP-JavaScript-Bundle-Export
# Build: 2.0
# Copies the installed KPP Hermes JavaScript bundle to USB-visible Documents.
# Deliberately lightweight: one file copy, no hashing, parsing, sync, or upload.
# The original /app file is only read and is never modified or executed.
set -u

TEST_ROOT="$KPP_BUNDLE_EXPORT_TEST_ROOT"
if [ -n "$TEST_ROOT" ]; then
  DOCS="$TEST_ROOT/documents"
  SOURCE="$TEST_ROOT/app/KPPMainApp/js/KPPMainApp.js.hbc"
else
  DOCS="/mnt/us/documents"
  SOURCE="/app/KPPMainApp/js/KPPMainApp.js.hbc"
fi

DEST="$DOCS/KPPMainApp.js.hbc"
REPORT="$DOCS/KPP-JavaScript-Bundle-Export.txt"
TMP_DEST="$DOCS/.KPPMainApp.js.hbc.tmp.$$"
TMP_REPORT="$DOCS/.KPP-JavaScript-Bundle-Export.txt.tmp.$$"

# Prefer FBInk for large, centered text. Fall back to eips if FBInk is absent.
FBINK_BIN=""
if [ -x /usr/bin/fbink ]; then
  FBINK_BIN="/usr/bin/fbink"
elif command -v fbink >/dev/null 2>&1; then
  FBINK_BIN="$(command -v fbink)"
fi
EIPS_BIN=""
if [ -x /usr/sbin/eips ]; then
  EIPS_BIN="/usr/sbin/eips"
elif command -v eips >/dev/null 2>&1; then
  EIPS_BIN="$(command -v eips)"
fi

umask 022

cleanup() {
  rm -f "$TMP_DEST" "$TMP_REPORT"
}
trap cleanup 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

display() {
  HEADING="$1"
  DETAIL="$2"
  MESSAGE="KPP BUNDLE EXPORT

$HEADING

$DETAIL"
  printf '\n%s\n%s\n\n' "$HEADING" "$DETAIL"

  if [ -n "$FBINK_BIN" ]; then
    # Font scale 3; center horizontally and place the message around mid-screen.
    # Do not clear the whole display or wait for a full-screen refresh.
    "$FBINK_BIN" -S 3 -m -M "$MESSAGE" >/dev/null 2>&1 || true
  elif [ -n "$EIPS_BIN" ]; then
    # Small fallback for Kindles without the FBInk command-line utility.
    "$EIPS_BIN" 1 1 "KPP EXPORT: $HEADING - $DETAIL" >/dev/null 2>&1 || true
  fi
}

write_report() {
  STATUS="$1"
  DETAILS="$2"
  {
    printf '%s\n' "KPP JAVASCRIPT BUNDLE EXPORT"
    printf 'Generated: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Status: %s\n' "$STATUS"
    printf 'Details: %s\n' "$DETAILS"
    printf 'Source: %s\n' "$SOURCE"
    printf 'USB transfer copy: %s\n' "$DEST"
    printf '%s\n' "Method: one copy to a temporary Documents file, then rename into place."
    printf '%s\n' "On-Kindle hashing, bytecode parsing, extra file reads, and sync are not performed."
    printf '%s\n' "The original /app application file was not changed or executed."
    printf '%s\n' "No browser page data, cookies, history, account data, or network upload is involved."
  } > "$TMP_REPORT" || return 1
  chmod 644 "$TMP_REPORT" 2>/dev/null || true
  mv -f "$TMP_REPORT" "$REPORT"
}

fail() {
  FAILURE_DETAILS="$1"
  display "EXPORT FAILED" "$FAILURE_DETAILS"
  write_report "FAILED" "$FAILURE_DETAILS" 2>/dev/null || true
  exit 1
}

display "STEP 1 OF 3" "Checking that the original bundle is readable."
if [ ! -d "$DOCS" ]; then
  fail "Kindle Documents folder is unavailable. No copy was attempted."
fi
if [ ! -r "$SOURCE" ]; then
  fail "The original KPP bundle is not readable. No copy was attempted."
fi

# Copy exactly once. A temporary destination preserves any previous good copy
# if the new copy fails or is interrupted before the final rename.
rm -f "$TMP_DEST"
display "STEP 2 OF 3" "Copying the bundle once to Documents. Please keep the Kindle awake."
if ! cp "$SOURCE" "$TMP_DEST"; then
  fail "The file copy failed. Any previous Documents copy has been retained."
fi
if [ ! -s "$TMP_DEST" ]; then
  fail "The copy did not produce a non-empty file. Any previous copy has been retained."
fi
if ! mv -f "$TMP_DEST" "$DEST"; then
  fail "Could not place the copied file in Documents. Any previous copy has been retained."
fi

if ! write_report "SUCCESS — COPIED" "The bundle was copied once to Documents; no checksum or bytecode processing was run."; then
  display "COPY FINISHED" "The bundle is in Documents, but the small report could not be saved."
  exit 1
fi

display "STEP 3 OF 3 — COMPLETE" "KPPMainApp.js.hbc is in Documents. Connect USB and upload it here."
exit 0
