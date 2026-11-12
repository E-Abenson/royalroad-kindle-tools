#!/bin/sh
# Name: RR-KPP-Bytecode-Export
# Manually make a private, read-only copy of the exact KPP Hermes bundle.
# Run this launcher only when you explicitly want to refresh the local research copy.
#
# PRIVACY / SAFETY:
# - Reads only /app/KPPMainApp/js/KPPMainApp.js.hbc.
# - Does not modify the original application or remount the root filesystem.
# - Does not execute or disassemble the bundle.
# - Validates the Hermes magic and reads the version field at byte offset 8.
# - Does not upload the file or send it to a public paste service.
# - Stores the copy in a private directory under Kindle Documents.

DOCS="/mnt/us/documents"
SOURCE="/app/KPPMainApp/js/KPPMainApp.js.hbc"
OUTDIR="$DOCS/.rr-kpp-research"
DEST="$OUTDIR/KPPMainApp.js.hbc"
REPORT="$DOCS/KPP-Bytecode-Export.txt"
TMP_DEST="$OUTDIR/.KPPMainApp.js.hbc.tmp.$$"
TMP_REPORT="$DOCS/.KPP-Bytecode-Export.txt.tmp.$$"
MAX_BYTES=52428800

umask 077
mkdir -p "$DOCS" "$OUTDIR" 2>/dev/null
chmod 700 "$OUTDIR" 2>/dev/null || true
trap 'rm -f "$TMP_DEST" "$TMP_REPORT"' 0 HUP INT TERM

write_report() {
  STATUS="$1"
  {
    echo "KPP HERMES BYTECODE EXPORT"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Status: $STATUS"
    echo "Source: $SOURCE"
    echo "Private copy: $DEST"
    echo "Original application was not changed."
    echo "No network upload was performed."
  echo "Disassembly status: waiting for a private authenticated analysis receiver."
  } > "$TMP_REPORT"
  chmod 600 "$TMP_REPORT" 2>/dev/null || true
  mv -f "$TMP_REPORT" "$REPORT" || return 1
  chmod 600 "$REPORT" 2>/dev/null || true
}

if [ ! -r "$SOURCE" ]; then
  write_report "SOURCE NOT READABLE — no copy made."
  echo "KPP bundle export: source not readable; package installation continues."
  exit 0
fi

SIZE="$(wc -c < "$SOURCE" 2>/dev/null | tr -d ' ')"
case "$SIZE" in
  ''|*[!0-9]*)
    write_report "COULD NOT DETERMINE SOURCE SIZE — no copy made."
    echo "KPP bundle export: could not determine file size."
    exit 0
    ;;
esac

if [ "$SIZE" -le 0 ] || [ "$SIZE" -gt "$MAX_BYTES" ]; then
  write_report "SOURCE SIZE OUTSIDE SAFE LIMIT (bytes=$SIZE) — no copy made."
  echo "KPP bundle export: source size outside the 50 MB safety limit."
  exit 0
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  write_report "SHA256 UTILITY MISSING — no copy made."
  echo "KPP bundle export: sha256sum unavailable; skipped."
  exit 0
fi

MAGIC="$(od -An -tx1 -N 8 "$SOURCE" 2>/dev/null | tr -d '[:space:]')"
if [ "$MAGIC" != "c61fbc03c103191f" ]; then
  write_report "SOURCE DOES NOT HAVE THE EXPECTED HERMES MAGIC — no copy made."
  echo "KPP bundle export: source did not match the Hermes HBC magic."
  exit 0
fi

SOURCE_SHA="$(sha256sum "$SOURCE" 2>/dev/null | awk '{print $1}')"
if [ -z "$SOURCE_SHA" ]; then
  write_report "COULD NOT HASH SOURCE — no copy made."
  echo "KPP bundle export: could not hash source."
  exit 0
fi

if [ -s "$DEST" ]; then
  DEST_SHA="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"
else
  DEST_SHA=""
fi

if [ "$SOURCE_SHA" != "$DEST_SHA" ]; then
  if ! cp "$SOURCE" "$TMP_DEST"; then
    write_report "COPY FAILED — previous private copy retained."
    echo "KPP bundle export: copy failed."
    exit 0
  fi
  chmod 600 "$TMP_DEST" 2>/dev/null || true
  COPIED_SHA="$(sha256sum "$TMP_DEST" 2>/dev/null | awk '{print $1}')"
  if [ "$COPIED_SHA" != "$SOURCE_SHA" ]; then
    write_report "COPY VERIFICATION FAILED — previous private copy retained."
    echo "KPP bundle export: copy verification failed."
    exit 0
  fi
  if ! mv -f "$TMP_DEST" "$DEST"; then
    write_report "COULD NOT REPLACE PRIVATE COPY — previous copy retained."
    echo "KPP bundle export: could not replace destination."
    exit 0
  fi
  chmod 600 "$DEST" 2>/dev/null || true
  RESULT="COPIED AND SHA256 VERIFIED"
else
  RESULT="ALREADY CURRENT — SHA256 MATCH"
fi

HBC_VERSION="unavailable"
if command -v od >/dev/null 2>&1; then
  HBC_VERSION="$(od -An -tu4 -j 8 -N 4 "$DEST" 2>/dev/null | tr -d ' ')"
  [ -n "$HBC_VERSION" ] || HBC_VERSION="unavailable"
fi
FINAL_SIZE="$(wc -c < "$DEST" 2>/dev/null | tr -d ' ')"
FINAL_SHA="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"

{
  echo "KPP HERMES BYTECODE EXPORT"
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Status: $RESULT"
  echo "Source: $SOURCE"
  echo "Private copy: $DEST"
  echo "File size: $FINAL_SIZE bytes"
  echo "Hermes bytecode version (header field): $HBC_VERSION"
  echo "SHA256: $FINAL_SHA"
  echo "Original application was not changed."
  echo "No bytecode was executed, disassembled, patched, or uploaded."
  echo "Disassembly status: waiting for a private authenticated analysis receiver."
} > "$TMP_REPORT"
chmod 600 "$TMP_REPORT" 2>/dev/null || true
if ! mv -f "$TMP_REPORT" "$REPORT"; then
  echo "KPP bundle copied, but export report could not be replaced."
  exit 0
fi
chmod 600 "$REPORT" "$DEST" 2>/dev/null || true
sync 2>/dev/null
echo "KPP bundle export: $RESULT; $FINAL_SIZE bytes; Hermes version $HBC_VERSION."
exit 0
