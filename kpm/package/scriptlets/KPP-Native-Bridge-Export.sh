#!/bin/sh
# Name: KPP-Native-Bridge-Export
# Build: 2.0
# Copies every readable ELF file with an executable mapping in the running
# KPPMainApp process, including generic-named system and app shared libraries.
# Read-only: no process memory, URLs, page text, cookies, command lines,
# LIPC values, browser actions or uploads are collected.
set -u

if [ -n "${KPP_EXPORT_TEST_ROOT:-}" ]; then
  DOCS="${KPP_EXPORT_TEST_ROOT}/documents"
  PROC_ROOT="${KPP_EXPORT_TEST_ROOT}/proc"
  APP_ROOT="${KPP_EXPORT_TEST_ROOT}/app"
else
  DOCS="/mnt/us/documents"
  PROC_ROOT="/proc"
  APP_ROOT="/app"
fi
INTERNAL="$DOCS/.royalroadtools"
WORK="$INTERNAL/native-bridge-export.$$"
ARCHIVE="$DOCS/KPP-Native-Bridge-Binaries.tar.gz"
ARCHIVE_TMP="$ARCHIVE.new.$$"
SUMMARY="$DOCS/KPP-Native-Bridge-Export.txt"

umask 077
mkdir -p "$DOCS" "$INTERNAL" 2>/dev/null || {
  echo "FAILURE: Cannot prepare Kindle Documents."
  exit 1
}
chmod 700 "$INTERNAL" 2>/dev/null || true
mkdir -p "$WORK/files" || {
  echo "FAILURE: Cannot create temporary export folder."
  exit 1
}
cleanup() {
  rm -rf "$WORK"
  rm -f "$ARCHIVE_TMP"
}
trap cleanup 0 HUP INT TERM

for TOOL in awk sort tar sha256sum wc cp od tr readlink; do
  command -v "$TOOL" >/dev/null 2>&1 || {
    echo "FAILURE: Required utility '$TOOL' is unavailable."
    exit 1
  }
done

# Locate KPPMainApp locally. The PID is never written to the archive or report.
KPP_PID=""
for COMM_FILE in "$PROC_ROOT"/[0-9]*/comm; do
  [ -r "$COMM_FILE" ] || continue
  COMM=""
  IFS= read -r COMM < "$COMM_FILE" || true
  case "$COMM" in
    KPPMainApp|KPPMainAppV2)
      KPP_PID="${COMM_FILE#"$PROC_ROOT"/}"
      KPP_PID="${KPP_PID%/comm}"
      break
      ;;
  esac
done

if [ -z "$KPP_PID" ] || [ ! -r "$PROC_ROOT/$KPP_PID/maps" ]; then
  echo "FAILURE: KPPMainApp is not running. Open the Kindle browser, then run this launcher again."
  exit 1
fi

APP_EXE="$APP_ROOT/bin/KPPMainAppV2"
PROCESS_EXE="$PROC_ROOT/$KPP_PID/exe"
if [ -r "$PROCESS_EXE" ]; then
  RESOLVED_EXE="$(readlink -f "$PROCESS_EXE" 2>/dev/null || true)"
  [ -r "$RESOLVED_EXE" ] && APP_EXE="$RESOLVED_EXE"
fi
[ -r "$APP_EXE" ] || {
  echo "FAILURE: The running KPP executable could not be read."
  exit 1
}

# Resource caps are deliberately generous enough for the complete mapped
# native dependency set, but prevent an accidental unbounded archive.
MAX_FILES=128
MAX_FILE_BYTES=120000000
MAX_TOTAL_BYTES=400000000
FILE_COUNT=0
TOTAL_BYTES=0
SKIPPED_UNREADABLE=0
SKIPPED_NOT_ELF=0
SKIPPED_LIMITS=0
DUPLICATE_FILES=0
COPY_REASON=""

: > "$WORK/manifest.tsv"

copy_candidate() {
  SRC="$1"
  ROLE="$2"
  DISPLAY_NAME="$3"
  COPY_REASON=""

  [ -r "$SRC" ] || {
    COPY_REASON="unreadable"
    return 1
  }

  MAGIC="$(od -An -tx1 -N4 "$SRC" 2>/dev/null | tr -d ' \n')"
  [ "$MAGIC" = "7f454c46" ] || {
    COPY_REASON="not-elf"
    return 1
  }

  SIZE="$(wc -c < "$SRC" 2>/dev/null | tr -d ' ')"
  case "$SIZE" in
    ""|*[!0-9]*) COPY_REASON="unreadable"; return 1 ;;
  esac
  [ "$SIZE" -gt 0 ] || {
    COPY_REASON="unreadable"
    return 1
  }

  if [ "$FILE_COUNT" -ge "$MAX_FILES" ] ||
     [ "$SIZE" -gt "$MAX_FILE_BYTES" ] ||
     [ $((TOTAL_BYTES + SIZE)) -gt "$MAX_TOTAL_BYTES" ]; then
    COPY_REASON="limit"
    return 1
  fi

  INDEX="$(printf '%03d' $((FILE_COUNT + 1)))"
  BASE="${DISPLAY_NAME##*/}"
  [ -n "$BASE" ] || BASE="native-file"
  BASE="$(printf '%s' "$BASE" | tr -c 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-' '_')"
  DEST="$WORK/files/${INDEX}_${BASE}.elf"

  if ! cp "$SRC" "$DEST" 2>/dev/null; then
    rm -f "$DEST"
    COPY_REASON="unreadable"
    return 1
  fi

  HASH="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"
  if [ -z "$HASH" ]; then
    rm -f "$DEST"
    COPY_REASON="unreadable"
    return 1
  fi

  # Avoid duplicate copies when multiple mappings or symlinks point to the
  # same ELF object. The main executable is kept as the canonical first copy.
  if awk -F '\t' -v hash="$HASH" '$4 == hash { found=1; exit } END { exit !found }' "$WORK/manifest.tsv"; then
    rm -f "$DEST"
    DUPLICATE_FILES=$((DUPLICATE_FILES + 1))
    COPY_REASON="duplicate"
    return 0
  fi

  printf '%s\t%s\t%s\t%s\n' "$ROLE" "$BASE" "$SIZE" "$HASH" >> "$WORK/manifest.tsv"
  FILE_COUNT=$((FILE_COUNT + 1))
  TOTAL_BYTES=$((TOTAL_BYTES + SIZE))
  COPY_REASON="copied"
  return 0
}

copy_candidate "$APP_EXE" "main-executable" "$APP_EXE" || {
  echo "FAILURE: The KPP executable is not a readable ELF file."
  exit 1
}

# Take one maps snapshot. Only file-backed executable mappings are candidates:
# those are the native code objects the process has actually mapped. The awk
# parser keeps the full pathname (including spaces), deduplicates by device and
# inode, and emits only a temporary local list; it is not archived.
cp "$PROC_ROOT/$KPP_PID/maps" "$WORK/maps.snapshot" || {
  echo "FAILURE: Could not snapshot the KPP process memory-map list."
  exit 1
}

awk '
  NF >= 6 && $2 ~ /x/ && $5 != "0" {
    path = $6
    for (i = 7; i <= NF; i++) path = path " " $i
    sub(/ \(deleted\)$/, "", path)
    if (substr(path, 1, 1) == "/") {
      key = $4 ":" $5
      if (!seen[key]++) print $1 "\t" path
    }
  }
' "$WORK/maps.snapshot" | sort -u > "$WORK/mapped-elf-candidates.tsv"

MAPPED_CANDIDATES="$(wc -l < "$WORK/mapped-elf-candidates.tsv" | tr -d ' ')"
while IFS="$(printf '\t')" read -r MAP_RANGE MAPPED_PATH; do
  [ -n "$MAP_RANGE" ] && [ -n "$MAPPED_PATH" ] || continue

  # map_files refers to the exact mapped inode and can still work for a file
  # that was renamed or unlinked after mapping. Fall back to its pathname.
  MAP_SOURCE="$PROC_ROOT/$KPP_PID/map_files/$MAP_RANGE"
  if copy_candidate "$MAP_SOURCE" "mapped-executable" "$MAPPED_PATH"; then
    continue
  fi

  if copy_candidate "$MAPPED_PATH" "mapped-executable" "$MAPPED_PATH"; then
    continue
  fi

  case "$COPY_REASON" in
    not-elf) SKIPPED_NOT_ELF=$((SKIPPED_NOT_ELF + 1)) ;;
    limit) SKIPPED_LIMITS=$((SKIPPED_LIMITS + 1)) ;;
    *) SKIPPED_UNREADABLE=$((SKIPPED_UNREADABLE + 1)) ;;
  esac
done < "$WORK/mapped-elf-candidates.tsv"

[ "$FILE_COUNT" -gt 0 ] || {
  echo "FAILURE: No readable ELF native files were collected."
  exit 1
}

SKIPPED_FILES=$((SKIPPED_UNREADABLE + SKIPPED_NOT_ELF + SKIPPED_LIMITS))
cat > "$WORK/README.txt" <<EOF
KPP native bridge inspection input
Files exported: $FILE_COUNT
Unique file-backed executable mappings considered: $MAPPED_CANDIDATES
Duplicate mappings/files omitted by SHA256: $DUPLICATE_FILES
Unreadable mapped objects skipped: $SKIPPED_UNREADABLE
Non-ELF executable mappings skipped: $SKIPPED_NOT_ELF
Files skipped by safety limits: $SKIPPED_LIMITS
Total uncompressed bytes: $TOTAL_BYTES

The archive contains the KPP main executable and every readable ELF file
found in a file-backed executable mapping of the running KPPMainApp process,
subject to the explicit count and size caps. Selection is NOT based on the
library filename. Each object is copied unchanged for offline static analysis.

The original absolute paths, process IDs, raw memory-map rows, URLs, cookies,
page text, browser history, command lines and runtime property values are not
included. No process memory was read. Nothing was executed, modified or uploaded.
EOF

chmod 600 "$WORK/manifest.tsv" "$WORK/README.txt" 2>/dev/null || true
if ! tar -czf "$ARCHIVE_TMP" -C "$WORK" README.txt manifest.tsv files; then
  echo "FAILURE: Could not create the native-inspection archive."
  exit 1
fi
if [ ! -s "$ARCHIVE_TMP" ] || ! tar -tzf "$ARCHIVE_TMP" >/dev/null 2>&1; then
  echo "FAILURE: The native-inspection archive failed verification."
  exit 1
fi

mv -f "$ARCHIVE_TMP" "$ARCHIVE" || {
  echo "FAILURE: Could not save archive in Kindle Documents."
  exit 1
}
chmod 600 "$ARCHIVE" 2>/dev/null || true

ARCHIVE_SIZE="$(wc -c < "$ARCHIVE" 2>/dev/null | tr -d ' ')"
ARCHIVE_HASH="$(sha256sum "$ARCHIVE" 2>/dev/null | awk '{print $1}')"
{
  echo "KPP NATIVE BRIDGE EXPORT"
  echo "Result: SUCCESS"
  echo "Exporter build: 2.0"
  echo "KPP process: detected (PID withheld)"
  echo "Unique executable mappings considered: $MAPPED_CANDIDATES"
  echo "Files exported: $FILE_COUNT"
  echo "Duplicate files omitted: $DUPLICATE_FILES"
  echo "Files skipped: $SKIPPED_FILES"
  echo "  Unreadable: $SKIPPED_UNREADABLE"
  echo "  Non-ELF: $SKIPPED_NOT_ELF"
  echo "  Safety limits: $SKIPPED_LIMITS"
  echo "Uncompressed bytes: $TOTAL_BYTES"
  echo "Archive bytes: $ARCHIVE_SIZE"
  echo "Archive SHA256: $ARCHIVE_HASH"
  echo "Archive: KPP-Native-Bridge-Binaries.tar.gz"
  echo "Scope: KPP executable plus all readable ELF files with executable mappings"
  echo "Selection is based on ELF file content and executable mappings, not filenames."
  echo "No page URL, page text, cookies, browser history, account identifiers, process IDs or command lines were collected."
  echo "No application files were modified and no network upload was performed."
} > "$SUMMARY"
chmod 600 "$SUMMARY" 2>/dev/null || true
sync 2>/dev/null

echo "SUCCESS: Native files exported to Documents/KPP-Native-Bridge-Binaries.tar.gz"
echo "Files: $FILE_COUNT; mapped candidates: $MAPPED_CANDIDATES; skipped: $SKIPPED_FILES."
echo "Copy the archive to Windows and run the bundled inspection helper."
exit 0
