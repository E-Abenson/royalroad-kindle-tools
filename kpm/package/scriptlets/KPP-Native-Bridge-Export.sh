#!/bin/sh
# Name: KPP-Native-Bridge-Export
# Build: 1.0
# Copies only the running KPP executable and relevant loaded ELF libraries
# into a private USB-transfer archive for offline inspection on Windows.
# No URL, cookie, page text, process ID, command line, or runtime property value
# is collected. No application file is changed and nothing is uploaded.
DOCS="/mnt/us/documents"
INTERNAL="$DOCS/.royalroadtools"
WORK="$INTERNAL/native-bridge-export.$$"
ARCHIVE="$DOCS/KPP-Native-Bridge-Binaries.tar.gz"
ARCHIVE_TMP="$ARCHIVE.new.$$"
SUMMARY="$DOCS/KPP-Native-Bridge-Export.txt"
umask 077
mkdir -p "$DOCS" "$INTERNAL" 2>/dev/null || { echo "FAILURE: Cannot prepare Kindle Documents."; exit 1; }
chmod 700 "$INTERNAL" 2>/dev/null || true
mkdir -p "$WORK/files" || { echo "FAILURE: Cannot create temporary export folder."; exit 1; }
cleanup() { rm -rf "$WORK"; rm -f "$ARCHIVE_TMP"; }
trap cleanup 0 HUP INT TERM
for TOOL in awk sort tar sha256sum wc cp; do
  command -v "$TOOL" >/dev/null 2>&1 || { echo "FAILURE: Required utility '$TOOL' is unavailable."; exit 1; }
done

# Locate KPPMainApp using /proc comm; PID is used locally but never recorded.
KPP_PID=""
for COMM_FILE in /proc/[0-9]*/comm; do
  [ -r "$COMM_FILE" ] || continue
  COMM=""
  IFS= read -r COMM < "$COMM_FILE" || true
  case "$COMM" in
    KPPMainApp|KPPMainAppV2)
      KPP_PID="${COMM_FILE#/proc/}"
      KPP_PID="${KPP_PID%/comm}"
      break
      ;;
  esac
done
if [ -z "$KPP_PID" ] || [ ! -r "/proc/$KPP_PID/maps" ]; then
  echo "FAILURE: KPPMainApp is not running. Open the Kindle browser, then run this launcher again."
  exit 1
fi

APP_EXE="/app/bin/KPPMainAppV2"
if [ -r "/proc/$KPP_PID/exe" ] && command -v readlink >/dev/null 2>&1; then
  RESOLVED_EXE="$(readlink -f "/proc/$KPP_PID/exe" 2>/dev/null)"
  [ -r "$RESOLVED_EXE" ] && APP_EXE="$RESOLVED_EXE"
fi
[ -r "$APP_EXE" ] || { echo "FAILURE: The running KPP executable could not be read."; exit 1; }

MAX_FILES=64
MAX_FILE_BYTES=80000000
MAX_TOTAL_BYTES=180000000
FILE_COUNT=0
TOTAL_BYTES=0
SKIPPED_FILES=0
copy_candidate() {
  SRC="$1"
  ROLE="$2"
  [ -r "$SRC" ] || return 0
  SIZE="$(wc -c < "$SRC" 2>/dev/null | tr -d ' ')"
  case "$SIZE" in ""|*[!0-9]*) return 0 ;; esac
  [ "$SIZE" -gt 0 ] || return 0
  if [ "$FILE_COUNT" -ge "$MAX_FILES" ] || [ "$SIZE" -gt "$MAX_FILE_BYTES" ] ||
     [ $((TOTAL_BYTES + SIZE)) -gt "$MAX_TOTAL_BYTES" ]; then
    SKIPPED_FILES=$((SKIPPED_FILES + 1)); return 0
  fi
  BASE="$(basename "$SRC" 2>/dev/null)"
  [ -n "$BASE" ] || BASE="native-file"
  INDEX="$(printf '%03d' $((FILE_COUNT + 1)))"
  DEST="$WORK/files/${INDEX}_${BASE}.elf"
  if ! cp "$SRC" "$DEST" 2>/dev/null; then
    SKIPPED_FILES=$((SKIPPED_FILES + 1)); return 0
  fi
  HASH="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"
  if [ -z "$HASH" ]; then
    rm -f "$DEST"; SKIPPED_FILES=$((SKIPPED_FILES + 1)); return 0
  fi
  printf '%s\t%s\t%s\t%s\n' "$ROLE" "$BASE" "$SIZE" "$HASH" >> "$WORK/manifest.tsv"
  FILE_COUNT=$((FILE_COUNT + 1))
  TOTAL_BYTES=$((TOTAL_BYTES + SIZE))
}
: > "$WORK/manifest.tsv"
copy_candidate "$APP_EXE" "main-executable"

# All app-bundled .so files plus browser/JS/LIPC-related system libraries
# actually mapped by the running KPP process.
awk '
  NF >= 6 {
    path = $6
    sub(/ \(deleted\)$/, "", path)
    if (path ~ /^\// && path ~ /\.so([.][^/]*)?$/) {
      base = path
      sub(/^.*\//, "", base)
      low = tolower(base)
      if (path ~ /^\/app\// ||
          low ~ /(kpp|browser|webview|webkit|chrom|hermes|react|jsi|lipc|catalyst)/) print path
    }
  }
' "/proc/$KPP_PID/maps" | sort -u > "$WORK/library-paths.txt"
while IFS= read -r LIBRARY; do
  [ -n "$LIBRARY" ] || continue
  [ -r "$LIBRARY" ] || { SKIPPED_FILES=$((SKIPPED_FILES + 1)); continue; }
  [ "$LIBRARY" = "$APP_EXE" ] && continue
  copy_candidate "$LIBRARY" "loaded-library"
done < "$WORK/library-paths.txt"

[ "$FILE_COUNT" -gt 0 ] || { echo "FAILURE: No readable native ELF files were collected."; exit 1; }
cat > "$WORK/README.txt" <<EOF
KPP native bridge inspection input
Files: $FILE_COUNT
Total uncompressed bytes: $TOTAL_BYTES
Skipped because of file/size limits or unreadable files: $SKIPPED_FILES

The archive contains the KPP main executable and selected shared libraries
mapped by the running KPPMainApp process. Original absolute paths, process IDs,
memory-map rows, URLs, cookies, page text and runtime property values are not
included. The files are unchanged copies for offline static inspection only.
EOF
chmod 600 "$WORK/manifest.tsv" "$WORK/README.txt" 2>/dev/null || true
if ! tar -czf "$ARCHIVE_TMP" -C "$WORK" README.txt manifest.tsv files; then
  echo "FAILURE: Could not create the native-inspection archive."; exit 1
fi
if [ ! -s "$ARCHIVE_TMP" ] || ! tar -tzf "$ARCHIVE_TMP" >/dev/null 2>&1; then
  echo "FAILURE: The native-inspection archive failed verification."; exit 1
fi
mv -f "$ARCHIVE_TMP" "$ARCHIVE" || { echo "FAILURE: Could not save archive in Kindle Documents."; exit 1; }
chmod 600 "$ARCHIVE" 2>/dev/null || true
ARCHIVE_SIZE="$(wc -c < "$ARCHIVE" 2>/dev/null | tr -d ' ')"
ARCHIVE_HASH="$(sha256sum "$ARCHIVE" 2>/dev/null | awk '{print $1}')"
{
  echo "KPP NATIVE BRIDGE EXPORT"
  echo "Result: SUCCESS"
  echo "KPP process: detected (PID withheld)"
  echo "Files exported: $FILE_COUNT"
  echo "Files skipped: $SKIPPED_FILES"
  echo "Uncompressed bytes: $TOTAL_BYTES"
  echo "Archive bytes: $ARCHIVE_SIZE"
  echo "Archive SHA256: $ARCHIVE_HASH"
  echo "Archive: KPP-Native-Bridge-Binaries.tar.gz"
  echo "Scope: KPP executable and selected mapped shared libraries only"
  echo "No page URL, page text, cookies, account identifiers, process IDs, or command lines were collected."
  echo "No application files were modified and no network upload was performed."
} > "$SUMMARY"
chmod 600 "$SUMMARY" 2>/dev/null || true
sync 2>/dev/null
echo "SUCCESS: Native files exported to Documents/KPP-Native-Bridge-Binaries.tar.gz ($FILE_COUNT files; $SKIPPED_FILES skipped). Copy the archive to Windows and run the bundled inspection helper."
exit 0
