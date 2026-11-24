#!/bin/sh
# KPP Native Browser FULL Export
# Build: 4.0
# Start from the Kindle library BEFORE opening the built-in browser.
# The background worker waits for KPPMainApp, then makes straightforward file
# copies of the app executable, all file-backed ELF files mapped by KPP
# (regardless of mapping permissions), and every shared-library candidate in
# the standard Kindle/app library roots. No ELF parsing, symbol extraction,
# disassembly, hashing, archive compression, or sync is done on the Kindle.
# All actual analysis is intended to happen off-device after USB transfer.
set -u

if [ -n "${KPP_NATIVE_TEST_ROOT:-}" ]; then
  TEST_ROOT="$KPP_NATIVE_TEST_ROOT"
  DOCS="$TEST_ROOT/documents"
  PROC_ROOT="$TEST_ROOT/proc"
  FS_ROOT="$TEST_ROOT/rootfs"
  APP_ROOT="$FS_ROOT/app"
  WAIT_SECONDS="${KPP_NATIVE_WAIT_SECONDS:-0}"
  SETTLE_SECONDS="${KPP_NATIVE_TEST_SETTLE_SECONDS:-0}"
else
  TEST_ROOT=""
  DOCS="/mnt/us/documents"
  PROC_ROOT="/proc"
  FS_ROOT=""
  APP_ROOT="/app"
  WAIT_SECONDS="900"
  SETTLE_SECONDS="3"
fi

INTERNAL="$DOCS/.royalroadtools"
SUMMARY="$DOCS/KPP-Native-Bridge-Full-Export.txt"
LAUNCHER="$DOCS/KPP-Native-Bridge-Export.sh"
LOCK_DIR="$INTERNAL/native-full-export.lock"
WORKER_LOG="$INTERNAL/native-full-export.log"

umask 077
mkdir -p "$DOCS" "$INTERNAL" 2>/dev/null || {
  echo "FAILURE: Cannot prepare Kindle Documents."
  exit 1
}
chmod 700 "$INTERNAL" 2>/dev/null || true

show_progress() {
  TITLE="$1"
  MESSAGE="$2"
  if command -v fbink >/dev/null 2>&1; then
    fbink -S 3 -m -M "$TITLE\n$MESSAGE" >/dev/null 2>&1 || true
  elif command -v eips >/dev/null 2>&1; then
    eips 1 1 "$TITLE" >/dev/null 2>&1 || true
    eips 1 3 "$MESSAGE" >/dev/null 2>&1 || true
  fi
}

write_failure() {
  WHY="$1"
  {
    echo "KPP NATIVE BROWSER FULL EXPORT"
    echo "Result: FAILURE"
    echo "Exporter build: 4.0"
    echo "Reason: $WHY"
    echo "No process memory, webpage text, HTML, cookies, or browser history was collected."
  } > "$SUMMARY"
  chmod 644 "$SUMMARY" 2>/dev/null || true
  show_progress "NATIVE EXPORT FAILED" "$WHY"
  echo "FAILURE: $WHY"
}

run_worker() {
  WORK=""
  LOCK_OWNED=1
  worker_cleanup() {
    [ -n "$WORK" ] && [ -d "$WORK" ] && rm -rf "$WORK"
    if [ "$LOCK_OWNED" -eq 1 ]; then
      rm -f "$LOCK_DIR/pid" 2>/dev/null || true
      rmdir "$LOCK_DIR" 2>/dev/null || true
    fi
  }
  trap worker_cleanup 0 HUP INT TERM

  for TOOL in awk sort find cp od tr readlink wc date sleep; do
    command -v "$TOOL" >/dev/null 2>&1 || {
      write_failure "Required utility '$TOOL' is unavailable."
      return 1
    }
  done

  # Wait for the process to be launched after this library item exits.
  show_progress "WAITING FOR BROWSER" "Open the built-in Kindle browser now."
  KPP_PID=""
  WAITED=0
  while [ "$WAITED" -le "$WAIT_SECONDS" ]; do
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
    [ -n "$KPP_PID" ] && [ -r "$PROC_ROOT/$KPP_PID/maps" ] && break
    KPP_PID=""
    [ "$WAITED" -ge "$WAIT_SECONDS" ] && break
    sleep 2
    WAITED=$((WAITED + 2))
  done

  if [ -z "$KPP_PID" ] || [ ! -r "$PROC_ROOT/$KPP_PID/maps" ]; then
    write_failure "Browser was not detected within the waiting period. Start the launcher, then open the browser."
    return 1
  fi
  # Give the app a moment to complete its initial dynamic-library loading.
  sleep "$SETTLE_SECONDS"
  [ -r "$PROC_ROOT/$KPP_PID/maps" ] || {
    write_failure "The browser exited before its file map could be captured."
    return 1
  }

  STAMP="$(date '+%Y%m%d-%H%M%S')"
  OUTPUT="$DOCS/KPP-Native-Bridge-FULL-$STAMP"
  [ ! -e "$OUTPUT" ] || {
    write_failure "An export folder with this timestamp already exists."
    return 1
  }
  WORK="$INTERNAL/native-full-export.$$"
  mkdir -p "$WORK/files" "$WORK/metadata" || {
    write_failure "Cannot create the temporary export folder."
    return 1
  }
  : > "$WORK/manifest.tsv"
  : > "$WORK/skipped.tsv"
  printf 'category\texported_path\toriginal_path\tbytes\n' > "$WORK/manifest.tsv"
  printf 'category\toriginal_path\treason\n' > "$WORK/skipped.tsv"

  # Resource limits are generous safety guards. Any limit-based omission is
  # explicitly recorded so a partial export cannot look complete.
  MAX_FILES=1800
  MAX_FILE_BYTES=250000000
  MAX_TOTAL_BYTES=1800000000
  FILE_COUNT=0
  TOTAL_BYTES=0
  MAP_CANDIDATES=0
  MAP_ELF_COPIED=0
  LIB_CANDIDATES=0
  LIB_ELF_COPIED=0
  SKIPPED_NOT_ELF=0
  SKIPPED_UNREADABLE=0
  SKIPPED_LIMITS=0
  DUPLICATES=0
  FIND_ROOT_ERRORS=0
  LAST_STATUS=""

  # Copy one ELF object unchanged. ELF signature checking is only a 4-byte
  # read; no executable parsing or checksum calculation is performed here.
  copy_elf() {
    SRC="$1"
    DISPLAY_PATH="$2"
    CATEGORY="$3"
    LAST_STATUS=""

    [ -r "$SRC" ] || { LAST_STATUS="unreadable"; return 1; }
    MAGIC="$(od -An -tx1 -N4 "$SRC" 2>/dev/null | tr -d ' \n')"
    [ "$MAGIC" = "7f454c46" ] || { LAST_STATUS="not-elf"; return 1; }

    case "$DISPLAY_PATH" in
      /*) REL_PATH="${DISPLAY_PATH#/}" ;;
      *) REL_PATH="mapped/$(printf '%s' "$DISPLAY_PATH" | tr -c 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-' '_')" ;;
    esac
    # Guard against unusual procfs paths escaping the export folder.
    case "/$REL_PATH/" in
      *"/../"*) REL_PATH="mapped/$(printf '%s' "$REL_PATH" | tr '/ ' '__')" ;;
    esac
    DEST="$WORK/files/$REL_PATH"
    if [ -s "$DEST" ]; then
      DUPLICATES=$((DUPLICATES + 1))
      LAST_STATUS="duplicate"
      return 0
    fi

    SIZE="$(wc -c < "$SRC" 2>/dev/null | tr -d ' ')"
    case "$SIZE" in
      ''|*[!0-9]*) SIZE=0 ;;
    esac
    if [ "$FILE_COUNT" -ge "$MAX_FILES" ] ||
       { [ "$SIZE" -gt 0 ] && [ "$SIZE" -gt "$MAX_FILE_BYTES" ]; } ||
       { [ "$SIZE" -gt 0 ] && [ $((TOTAL_BYTES + SIZE)) -gt "$MAX_TOTAL_BYTES" ]; }; then
      printf '%s\t%s\t%s\n' "$CATEGORY" "$DISPLAY_PATH" "safety-limit" >> "$WORK/skipped.tsv"
      SKIPPED_LIMITS=$((SKIPPED_LIMITS + 1))
      LAST_STATUS="limit"
      return 1
    fi

    DEST_DIR="${DEST%/*}"
    mkdir -p "$DEST_DIR" || { LAST_STATUS="unreadable"; return 1; }
    if ! cp -L "$SRC" "$DEST" 2>/dev/null; then
      rm -f "$DEST"
      LAST_STATUS="unreadable"
      return 1
    fi
    COPIED_SIZE="$(wc -c < "$DEST" 2>/dev/null | tr -d ' ')"
    case "$COPIED_SIZE" in ''|*[!0-9]*) COPIED_SIZE="$SIZE" ;; esac
    if [ "$SIZE" -gt 0 ] && [ "$COPIED_SIZE" -ne "$SIZE" ]; then
      rm -f "$DEST"
      LAST_STATUS="incomplete-copy"
      printf '%s\t%s\t%s\n' "$CATEGORY" "$DISPLAY_PATH" "copy-size-mismatch" >> "$WORK/skipped.tsv"
      SKIPPED_UNREADABLE=$((SKIPPED_UNREADABLE + 1))
      return 1
    fi
    chmod 644 "$DEST" 2>/dev/null || true
    printf '%s\t%s\t%s\t%s\n' "$CATEGORY" "$REL_PATH" "$DISPLAY_PATH" "$COPIED_SIZE" >> "$WORK/manifest.tsv"
    FILE_COUNT=$((FILE_COUNT + 1))
    TOTAL_BYTES=$((TOTAL_BYTES + COPIED_SIZE))
    LAST_STATUS="copied"
    if [ $((FILE_COUNT % 10)) -eq 0 ]; then
      show_progress "COPYING NATIVE FILES" "$FILE_COUNT files copied so far."
    fi
    return 0
  }

  show_progress "BROWSER FOUND" "Capturing loaded native files."

  # Resolve and copy the exact executable used by the live process.
  PROCESS_EXE="$PROC_ROOT/$KPP_PID/exe"
  APP_EXE=""
  if [ -r "$PROCESS_EXE" ]; then
    APP_EXE="$(readlink -f "$PROCESS_EXE" 2>/dev/null || true)"
  fi
  [ -n "$APP_EXE" ] || APP_EXE="$APP_ROOT/bin/KPPMainAppV2"
  copy_elf "$APP_EXE" "$APP_EXE" "main-executable" || {
    write_failure "The running KPP executable could not be copied as an ELF file."
    return 1
  }

  # Snapshot the raw mapping list for offline correlation. It contains mapping
  # metadata and file paths only; it is NOT process memory or page contents.
  cp "$PROC_ROOT/$KPP_PID/maps" "$WORK/metadata/process-maps.txt" || {
    write_failure "Could not snapshot the KPP mapping list."
    return 1
  }
  chmod 644 "$WORK/metadata/process-maps.txt" 2>/dev/null || true

  # Collect every file-backed mapping with a nonzero inode, regardless of
  # r/w/x permissions. This also retains named/deleted file-backed mappings
  # so map_files can be attempted. Only ELF files pass the 4-byte signature
  # filter; databases and page data are not copied.
  awk '
    NF >= 5 && $5 != "0" {
      path = ""
      if (NF >= 6) {
        path = $6
        for (i = 7; i <= NF; i++) path = path " " $i
      }
      sub(/ \(deleted\)$/, "", path)
      if (path == "") path = "unlabelled-file-backed-map"
      key = $4 ":" $5
      if (!seen[key]++) print $1 "\t" path
    }
  ' "$WORK/metadata/process-maps.txt" > "$WORK/metadata/mapped-files.tsv"
  MAP_CANDIDATES="$(wc -l < "$WORK/metadata/mapped-files.tsv" | tr -d ' ')"
  TAB="$(printf '\t')"
  while IFS="$TAB" read -r MAP_RANGE MAP_PATH; do
    [ -n "$MAP_RANGE" ] && [ -n "$MAP_PATH" ] || continue
    MAP_SOURCE="$PROC_ROOT/$KPP_PID/map_files/$MAP_RANGE"
    if [ -r "$MAP_SOURCE" ]; then
      if copy_elf "$MAP_SOURCE" "$MAP_PATH" "process-map"; then
        [ "$LAST_STATUS" = "copied" ] && MAP_ELF_COPIED=$((MAP_ELF_COPIED + 1))
        continue
      fi
    fi
    if copy_elf "$MAP_PATH" "$MAP_PATH" "process-map"; then
      [ "$LAST_STATUS" = "copied" ] && MAP_ELF_COPIED=$((MAP_ELF_COPIED + 1))
    else
      case "$LAST_STATUS" in
        not-elf) SKIPPED_NOT_ELF=$((SKIPPED_NOT_ELF + 1)) ;;
        limit) : ;;
        *) SKIPPED_UNREADABLE=$((SKIPPED_UNREADABLE + 1)) ;;
      esac
      printf 'process-map\t%s\t%s\n' "$MAP_PATH" "$LAST_STATUS" >> "$WORK/skipped.tsv"
    fi
  done < "$WORK/metadata/mapped-files.tsv"

  # Find all shared-library candidates in the usual Kindle, Amazon and app
  # roots, not merely files whose current mappings happen to be executable.
  : > "$WORK/metadata/library-candidates.txt"
  : > "$WORK/metadata/search-roots.txt"
  add_library_root() {
    ROOT_PATH="$1"
    [ -d "$ROOT_PATH" ] || return 0
    ROOT_REAL="$(readlink -f "$ROOT_PATH" 2>/dev/null || true)"
    [ -n "$ROOT_REAL" ] && [ -d "$ROOT_REAL" ] || return 0
    if ! grep -Fqx "$ROOT_REAL" "$WORK/metadata/search-roots.txt" 2>/dev/null; then
      printf '%s\n' "$ROOT_REAL" >> "$WORK/metadata/search-roots.txt"
      if ! find "$ROOT_REAL" \( -type f -o -type l \) \( -name '*.so' -o -name '*.so.*' -o -name '*.node' -o -name '*.dylib' \) -print >> "$WORK/metadata/library-candidates.txt" 2>> "$WORK/metadata/library-search-errors.txt"; then
        FIND_ROOT_ERRORS=$((FIND_ROOT_ERRORS + 1))
      fi
    fi
  }

  if [ -n "$TEST_ROOT" ]; then
    add_library_root "$FS_ROOT/lib"
    add_library_root "$FS_ROOT/usr/lib"
    add_library_root "$FS_ROOT/usr/local/lib"
    add_library_root "$FS_ROOT/app"
    add_library_root "$FS_ROOT/opt"
    add_library_root "$FS_ROOT/var/local/lib"
  else
    add_library_root "/lib"
    add_library_root "/usr/lib"
    add_library_root "/usr/local/lib"
    add_library_root "/app"
    add_library_root "/opt"
    add_library_root "/var/local/lib"
  fi
  sort -u "$WORK/metadata/library-candidates.txt" -o "$WORK/metadata/library-candidates.txt"
  LIB_CANDIDATES="$(wc -l < "$WORK/metadata/library-candidates.txt" | tr -d ' ')"
  while IFS= read -r LIB_PATH; do
    [ -n "$LIB_PATH" ] || continue
    if copy_elf "$LIB_PATH" "$LIB_PATH" "library-search"; then
      [ "$LAST_STATUS" = "copied" ] && LIB_ELF_COPIED=$((LIB_ELF_COPIED + 1))
    else
      case "$LAST_STATUS" in
        not-elf) SKIPPED_NOT_ELF=$((SKIPPED_NOT_ELF + 1)) ;;
        limit) : ;;
        *) SKIPPED_UNREADABLE=$((SKIPPED_UNREADABLE + 1)) ;;
      esac
      printf 'library-search\t%s\t%s\n' "$LIB_PATH" "$LAST_STATUS" >> "$WORK/skipped.tsv"
    fi
  done < "$WORK/metadata/library-candidates.txt"

  # Copy the dynamic-linker cache/config (not user databases) for off-device
  # resolution of library SONAMEs and their installed paths.
  if [ -n "$TEST_ROOT" ]; then
    ETC_ROOT="$FS_ROOT/etc"
  else
    ETC_ROOT="/etc"
  fi
  for META_FILE in "$ETC_ROOT/ld.so.cache" "$ETC_ROOT/ld.so.conf"; do
    if [ -r "$META_FILE" ]; then
      META_REL="${META_FILE#"$ETC_ROOT"/}"
      mkdir -p "$WORK/metadata/etc" 2>/dev/null || true
      cp -L "$META_FILE" "$WORK/metadata/etc/$META_REL" 2>/dev/null || true
    fi
  done
  if [ -d "$ETC_ROOT/ld.so.conf.d" ]; then
    mkdir -p "$WORK/metadata/etc/ld.so.conf.d" 2>/dev/null || true
    find "$ETC_ROOT/ld.so.conf.d" -type f -name '*.conf' -exec cp -f '{}' "$WORK/metadata/etc/ld.so.conf.d/" \; 2>/dev/null || true
  fi

  # Do not keep temporary candidate lists in the delivered folder; retain maps,
  # linker metadata, inventory, and a full accounting of skipped candidates.
  rm -f "$WORK/metadata/mapped-files.tsv" "$WORK/metadata/library-candidates.txt"
  cat > "$WORK/README.txt" <<EOF2
KPP NATIVE BROWSER — COMPREHENSIVE OFFLINE INSPECTION EXPORT
Exporter build: 4.0
KPP process: detected (PID intentionally not recorded)

Files copied: $FILE_COUNT
  Main KPP executable: 1
  ELF files copied from live process mappings: $MAP_ELF_COPIED
  ELF shared-library candidates copied from library roots: $LIB_ELF_COPIED
File-backed mapping candidates examined: $MAP_CANDIDATES
Shared-library filename candidates examined: $LIB_CANDIDATES
Library-root traversal errors: $FIND_ROOT_ERRORS
Duplicate paths avoided: $DUPLICATES
Non-ELF candidates skipped: $SKIPPED_NOT_ELF
Unreadable/incomplete candidates skipped: $SKIPPED_UNREADABLE
Safety-limit omissions: $SKIPPED_LIMITS
Total copied bytes: $TOTAL_BYTES

The export includes the running KPP executable, ELF objects from ALL
file-backed process mappings with nonzero inodes (read-only, writable, and
executable mappings, plus named/deleted file-backed mappings where map_files
permits access), and shared-library candidates found recursively under the
recorded Kindle/app library roots. The original file hierarchy is preserved
under files/.

manifest.tsv lists each copied file, source path, category, and byte count.
skipped.tsv records each candidate that could not be copied or was excluded.
metadata/process-maps.txt is a snapshot of mapping metadata, not memory.
metadata/search-roots.txt records the library roots searched.
metadata/etc contains dynamic-linker cache/config files when present.

No process memory, browser database, history records, URLs, cookies, current
page text, HTML, JavaScript runtime values, command lines, or environment
variables were read or exported. Only ELF files and linker metadata were
copied. No application files were modified.

IMPORTANT: No ELF parsing, readelf, symbol extraction, disassembly, checksum,
archive compression, or sync operation was run on the Kindle. All substantive
inspection is intended to happen on the computer after USB transfer.

On Windows, right-click this entire KPP-Native-Bridge-FULL folder and choose
Compress to ZIP. Upload that single ZIP for offline analysis.
EOF2

  chmod 644 "$WORK/manifest.tsv" "$WORK/skipped.tsv" "$WORK/README.txt" 2>/dev/null || true
  chmod 755 "$WORK" "$WORK/files" "$WORK/metadata" 2>/dev/null || true
  mv "$WORK" "$OUTPUT" || {
    write_failure "Could not move the completed export folder into Documents."
    return 1
  }
  WORK=""

  {
    echo "KPP NATIVE BROWSER FULL EXPORT"
    echo "Result: SUCCESS"
    echo "Exporter build: 4.0"
    echo "Files copied: $FILE_COUNT"
    echo "Mapped ELF files copied: $MAP_ELF_COPIED"
    echo "Shared-library candidates copied: $LIB_ELF_COPIED"
    echo "Mapped file candidates examined: $MAP_CANDIDATES"
    echo "Shared-library candidates examined: $LIB_CANDIDATES"
    echo "Library-root traversal errors: $FIND_ROOT_ERRORS"
    echo "Unreadable/incomplete: $SKIPPED_UNREADABLE"
    echo "Non-ELF skipped: $SKIPPED_NOT_ELF"
    echo "Safety-limit omissions: $SKIPPED_LIMITS"
    echo "Total copied bytes: $TOTAL_BYTES"
    echo "Output folder: ${OUTPUT##*/}"
    echo "On-device work: file copies and brief metadata capture only; no parsing, hashing, disassembly, compression, or sync."
  } > "$SUMMARY"
  chmod 644 "$SUMMARY" 2>/dev/null || true
  show_progress "EXPORT COMPLETE" "$FILE_COUNT native files copied. Connect USB."
  echo "SUCCESS: Full native export is in Documents/${OUTPUT##*/}"
  echo "Files copied: $FILE_COUNT; mapped ELF: $MAP_ELF_COPIED; library files: $LIB_ELF_COPIED."
  echo "Connect USB. Zip the entire KPP-Native-Bridge-FULL folder on Windows and upload that one ZIP."
  return 0
}

# Worker mode is used by the background watcher.
if [ "${1:-}" = "--worker" ]; then
  run_worker
  exit $?
fi

# Running this script from the Kindle library must return immediately so the
# user can open the browser. Install a reusable copy in Documents first.
case "${0##*/}" in
  RUNME.sh)
    cp "$0" "$LAUNCHER" || {
      write_failure "Could not install the reusable full exporter in Documents."
      exit 1
    }
    chmod 755 "$LAUNCHER" 2>/dev/null || true
    ;;
esac

if [ -d "$LOCK_DIR" ]; then
  OLD_PID=""
  [ -r "$LOCK_DIR/pid" ] && IFS= read -r OLD_PID < "$LOCK_DIR/pid" || true
  case "$OLD_PID" in
    ''|*[!0-9]*)
      rm -f "$LOCK_DIR/pid" 2>/dev/null || true
      rmdir "$LOCK_DIR" 2>/dev/null || true
      ;;
    *)
      if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "A full native-export watcher is already running. Open the built-in browser."
        show_progress "WATCHER ALREADY RUNNING" "Open the built-in Kindle browser now."
        exit 0
      fi
      rm -f "$LOCK_DIR/pid" 2>/dev/null || true
      rmdir "$LOCK_DIR" 2>/dev/null || true
      ;;
  esac
fi
mkdir "$LOCK_DIR" 2>/dev/null || {
  write_failure "Could not create the background-watcher lock."
  exit 1
}

if ! command -v nohup >/dev/null 2>&1; then
  rmdir "$LOCK_DIR" 2>/dev/null || true
  write_failure "This Kindle does not provide nohup; cannot safely wait in the background."
  exit 1
fi

nohup /bin/sh "$LAUNCHER" --worker </dev/null > "$WORKER_LOG" 2>&1 &
WATCHER_PID=$!
printf '%s\n' "$WATCHER_PID" > "$LOCK_DIR/pid" 2>/dev/null || true
sleep 1
if ! kill -0 "$WATCHER_PID" 2>/dev/null; then
  rm -f "$LOCK_DIR/pid" 2>/dev/null || true
  rmdir "$LOCK_DIR" 2>/dev/null || true
  write_failure "The background watcher did not start. See Documents/.royalroadtools/native-full-export.log."
  exit 1
fi

show_progress "FULL EXPORT READY" "Now open the built-in Kindle browser."
echo "Full native exporter is waiting in the background."
echo "Now open the built-in browser and leave it open. Do not run this launcher again."
echo "It will copy the complete native library set automatically."
exit 0
