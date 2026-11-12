#!/bin/sh
# Name: RR-KPP-Bytecode-Export
# One-time USB investigation export: place a verified copy in Kindle Documents.
#
# PRIVACY / SAFETY:
# - Reads only /app/KPPMainApp/js/KPPMainApp.js.hbc.
# - Does not modify the original application or remount the root filesystem.
# - Does not execute or disassemble the bundle.
# - Does not upload the binary to pasters.io or any other service.
# - The Documents copy is readable over USB for this one-time transfer.

DOCS="/mnt/us/documents"
SOURCE="/app/KPPMainApp/js/KPPMainApp.js.hbc"
DEST="$DOCS/KPPMainApp.js.hbc"
REPORT="$DOCS/KPP-Bytecode-Export.txt"
TMP_DEST="$DOCS/.KPPMainApp.js.hbc.tmp.$$"
TMP_REPORT="$DOCS/.KPP-Bytecode-Export.txt.tmp.$$"
LEGACY_DIR="$DOCS/.rr-kpp-research"
LEGACY_COPY="$LEGACY_DIR/KPPMainApp.js.hbc"
MAX_BYTES=52428800

umask 077
mkdir -p "$DOCS" 2>/dev/null
trap 'rm -f "$TMP_DEST" "$TMP_REPORT"' 0 HUP INT TERM

write_report() {
  STATUS="$1"
  {
    echo "KPP HERMES BYTECODE USB EXPORT"
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Status: $STATUS"
    echo "Source: $SOURCE"
    echo "USB transfer copy: $DEST"
    echo "Original /app application was not changed."
    echo "The binary was not uploaded, executed, disassembled, or patched."
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

if ! command -v sha256sum >/dev/null 2>&1 || ! command -v od >/dev/null 2>&1; then
  write_report "Required checksum/header utilities are missing — no copy made."
  echo "KPP bundle export: sha256sum or od is unavailable."
  exit 1
fi

MAGIC="$(od -An -tx1 -N 8 "$SOURCE" 2>/dev/null | tr -d '[:space:]')"
if [ "$MAGIC" != "c61fbc03c103191f" ]; then
  write_report "SOURCE DOES NOT HAVE THE EXPECTED HERMES MAGIC — no copy made."
  echo "KPP bundle export: source did not match Hermes HBC magic."
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
  chmod 644 "$DEST" 2>/dev/null || true
  RESULT="COPIED TO DOCUMENTS AND SHA256 VERIFIED"
else
  RESULT="ALREADY CURRENT — SHA256 MATCH"
fi

HBC_VERSION="$(od -An -tu4 -j 8 -N 4 "$DEST" 2>/dev/null | tr -d ' ')"
[ -n "$HBC_VERSION" ] || HBC_VERSION="unavailable"
FINAL_SIZE="$(wc -c < "$DEST" 2>/dev/null | tr -d ' ')"
FINAL_SHA="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"

{
  echo "KPP HERMES BYTECODE USB EXPORT"
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Status: $RESULT"
  echo "Source: $SOURCE"
  echo "USB transfer copy: $DEST"
  echo "File size: $FINAL_SIZE bytes"
  echo "Hermes bytecode version (header field): $HBC_VERSION"
  echo "SHA256: $FINAL_SHA"
  echo "Original /app application file was not changed."
  echo "The binary was not executed, disassembled, patched, or uploaded."
  echo "Next: connect Kindle by USB and copy KPPMainApp.js.hbc to the Windows helper folder."
} > "$TMP_REPORT"
chmod 644 "$TMP_REPORT" 2>/dev/null || true
if ! mv -f "$TMP_REPORT" "$REPORT"; then
  echo "KPP bundle copied, but export report could not be replaced."
  exit 1
fi
chmod 644 "$REPORT" "$DEST" 2>/dev/null || true

# Remove the obsolete hidden duplicate only after the new USB copy is verified.
if [ -f "$LEGACY_COPY" ]; then
  LEGACY_SHA="$(sha256sum "$LEGACY_COPY" 2>/dev/null | awk '{print $1}')"
  if [ -n "$FINAL_SHA" ] && [ "$LEGACY_SHA" = "$FINAL_SHA" ]; then
    rm -f "$LEGACY_COPY" 2>/dev/null || true
    rmdir "$LEGACY_DIR" 2>/dev/null || true
  fi
fi

sync 2>/dev/null
echo "KPP bundle export: $RESULT; $FINAL_SIZE bytes; Hermes version $HBC_VERSION."
echo "USB copy: $DEST"
exit 0
