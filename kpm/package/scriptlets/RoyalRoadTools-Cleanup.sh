#!/bin/sh
# Name: RoyalRoadTools-Cleanup
# Persistent cleanup queue for retired Royal Road Kindle test artifacts.
# Each queue item is removed only after its deletion has been verified.
# Failed or unverifiable items stay queued for the next run.

DOCS="/mnt/us/documents"
DB="/var/local/KPPBrowser.db"
PACKAGE_DIR="/mnt/us/kmc/kpm/packages/royalroad-kindle-tools"
QUEUE="$DOCS/RoyalRoadTools-Cleanup-Queue.txt"
COMPLETED="$DOCS/RoyalRoadTools-Cleanup-Completed.txt"
LOG="$DOCS/RoyalRoadTools-Cleanup.log"
QUEUE_TMP="$QUEUE.tmp.$$"

umask 077
mkdir -p "$DOCS" 2>/dev/null
: > "$LOG"
trap 'rm -f "$QUEUE_TMP"' EXIT HUP INT TERM

say() {
  printf '%s\n' "$*" | tee -a "$LOG"
}

valid_doc_name() {
  case "$1" in
    ""|"."|".."|*/*|*[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

valid_pkg_path() {
  case "$1" in
    ""|/*|..|../*|*/..|*/../*|*[!A-Za-z0-9._/-]*) return 1 ;;
    *) return 0 ;;
  esac
}

remove_doc_file() {
  VALUE="$1"
  valid_doc_name "$VALUE" || {
    say "  INVALID DOC filename; left queued: $VALUE"
    return 1
  }

  # Keep a public paste URL available while its matching remote deletion
  # remains pending. The queue is read from its original on-disk copy here,
  # so this also works when the DOC item appears before REMOTE_DELETE.
  DELETE_LINK_NAME=""
  case "$VALUE" in
    RR-JS-Smoke-Test-upload-url.txt)
      DELETE_LINK_NAME="RR-JS-Smoke-Test-delete-url.txt"
      ;;
    RR-KPP-Bundle-Scan-upload-url.txt)
      DELETE_LINK_NAME="RR-KPP-Bundle-Scan-delete-url.txt"
      ;;
    RR-LIPC-READONLY-UPLOAD-URL.txt)
      DELETE_LINK_NAME="RR-LIPC-READONLY-UPLOAD-DELETE-URL.txt"
      ;;
    RR-KPP-Interface-Inspector.log)
      DELETE_LINK_NAME=".RR-KPP-Interface-Inspector-delete-url.txt"
      ;;
  esac
  if [ -n "$DELETE_LINK_NAME" ] &&
     grep -Fqx "REMOTE_DELETE|$DELETE_LINK_NAME" "$QUEUE" 2>/dev/null; then
    say "  Retained paste URL while remote deletion is pending: $VALUE"
    return 1
  fi

  TARGET="$DOCS/$VALUE"
  if [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    say "  Already absent: $VALUE"
    return 0
  fi
  if rm -f "$TARGET" 2>/dev/null && [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    say "  Removed: $VALUE"
    return 0
  fi
  say "  FAILED to remove: $VALUE"
  return 1
}

remove_doc_glob() {
  VALUE="$1"
  case "$VALUE" in
    ""|*/*|*[!A-Za-z0-9._*-]*)
      say "  INVALID DOCGLOB pattern; left queued: $VALUE"
      return 1
      ;;
  esac

  FOUND=0
  FAILED_GLOB=0
  for TARGET in "$DOCS"/$VALUE; do
    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
      FOUND=1
      if rm -f "$TARGET" 2>/dev/null && [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
        say "  Removed generated file: $(basename "$TARGET")"
      else
        say "  FAILED to remove generated file: $(basename "$TARGET")"
        FAILED_GLOB=1
      fi
    fi
  done

  if [ "$FAILED_GLOB" -eq 1 ]; then
    return 1
  fi
  if [ "$FOUND" -eq 0 ]; then
    say "  No matching generated files remain: $VALUE"
  fi
  return 0
}

remove_package_file() {
  VALUE="$1"
  valid_pkg_path "$VALUE" || {
    say "  INVALID package path; left queued: $VALUE"
    return 1
  }
  TARGET="$PACKAGE_DIR/$VALUE"
  if [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    say "  Already absent from package cache: $VALUE"
    return 0
  fi
  if rm -f "$TARGET" 2>/dev/null && [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    say "  Removed cached package file: $VALUE"
    return 0
  fi
  say "  FAILED to remove cached package file: $VALUE"
  return 1
}

remove_package_dir() {
  VALUE="$1"
  valid_pkg_path "$VALUE" || {
    say "  INVALID package directory; left queued: $VALUE"
    return 1
  }
  TARGET="$PACKAGE_DIR/$VALUE"
  if [ ! -d "$TARGET" ]; then
    say "  Package directory already absent: $VALUE"
    return 0
  fi
  if rmdir "$TARGET" 2>/dev/null; then
    say "  Removed empty package directory: $VALUE"
    return 0
  fi
  say "  Package directory is not empty or could not be removed: $VALUE"
  return 1
}

delete_remote_paste() {
  VALUE="$1"
  valid_doc_name "$VALUE" || {
    say "  INVALID deletion-link filename; left queued: $VALUE"
    return 1
  }
  LINK_FILE="$DOCS/$VALUE"
  if [ ! -s "$LINK_FILE" ]; then
    say "  No saved remote deletion link is available; paste deletion cannot be confirmed: $VALUE"
    say "  Kept the task queued and retained its public paste URL for manual recovery."
    return 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    say "  curl unavailable; remote deletion remains queued: $VALUE"
    return 1
  fi

  DELETE_URL="$(sed -n '1p' "$LINK_FILE" | tr -d '\r\n')"
  case "$DELETE_URL" in
    https://pasters.io/d/*) ;;
    *)
      say "  Unrecognized deletion URL; not contacted and left queued: $VALUE"
      return 1
      ;;
  esac

  HTTP_CODE="$(curl -sS --connect-timeout 8 --max-time 20 -X DELETE -o /dev/null -w '%{http_code}' "$DELETE_URL" 2>/dev/null)"
  CURL_STATUS=$?
  if [ "$CURL_STATUS" -eq 0 ]; then
    case "$HTTP_CODE" in
      2??|404|410)
        if rm -f "$LINK_FILE" 2>/dev/null && [ ! -e "$LINK_FILE" ]; then
          say "  Remote paste deletion confirmed; removed local deletion link: $VALUE"
          return 0
        fi
        ;;
    esac
  fi
  say "  Remote paste deletion not confirmed; kept link and queue item: $VALUE"
  return 1
}

remove_old_bookmark() {
  VALUE="$1"
  if [ "$VALUE" != "Royal Road Session Test" ]; then
    say "  Unknown bookmark target; left queued: $VALUE"
    return 1
  fi
  if [ ! -f "$DB" ] || ! command -v sqlite3 >/dev/null 2>&1; then
    say "  Browser database or sqlite3 unavailable; bookmark check remains queued."
    return 1
  fi

  TABLE_COUNT="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='bookmark';" 2>/dev/null)"
  [ "$TABLE_COUNT" = "1" ] || {
    say "  Bookmark table not found or unreadable; item remains queued."
    return 1
  }

  EXISTING="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" 2>/dev/null)"
  case "$EXISTING" in
    0)
      say "  Exact old JavaScript test bookmark is already absent."
      return 0
      ;;
    ''|*[!0-9]*)
      say "  Could not verify the exact old bookmark; item remains queued."
      return 1
      ;;
  esac

  BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
  mkdir -p "$BACKUP_DIR"
  BACKUP="$BACKUP_DIR/KPPBrowser-before-RR-cleanup-$(date '+%Y%m%d-%H%M%S').db"
  if ! sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1; then
    say "  Could not create database backup; bookmark was not changed."
    return 1
  fi

  if sqlite3 -cmd '.timeout 5000' "$DB" "DELETE FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" >/dev/null 2>&1; then
    VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" 2>/dev/null)"
    if [ "$VERIFY" = "0" ]; then
      rm -f "$BACKUP"
      say "  Removed and verified the exact old JavaScript test bookmark."
      return 0
    fi
  fi

  say "  Bookmark deletion could not be verified; safety backup retained at $BACKUP"
  return 1
}

process_item() {
  ITEM_TYPE="$1"
  ITEM_VALUE="$2"
  case "$ITEM_TYPE" in
    DOC) remove_doc_file "$ITEM_VALUE" ;;
    DOCGLOB) remove_doc_glob "$ITEM_VALUE" ;;
    PKG) remove_package_file "$ITEM_VALUE" ;;
    PKGDIR) remove_package_dir "$ITEM_VALUE" ;;
    REMOTE_DELETE) delete_remote_paste "$ITEM_VALUE" ;;
    BOOKMARK) remove_old_bookmark "$ITEM_VALUE" ;;
    *)
      say "  Unknown queue type; left queued: $ITEM_TYPE"
      return 1
      ;;
  esac
}

say "============================================================"
say "ROYAL ROAD KINDLE TOOLS — CLEANUP QUEUE"
say "Device time: $(date)"
say "Queue: $QUEUE"
say "Successfully completed items are removed from the queue."
say "Failed or unverifiable items remain queued for the next run."
say "============================================================"

if [ ! -f "$QUEUE" ]; then
  printf '%s\n' '# Add cleanup targets here as TYPE|VALUE entries.' > "$QUEUE"
fi
if [ ! -f "$COMPLETED" ]; then
  printf '%s\n' '# Items successfully removed from the cleanup queue.' > "$COMPLETED"
fi

: > "$QUEUE_TMP"
FAILED=0
while IFS= read -r ENTRY || [ -n "$ENTRY" ]; do
  case "$ENTRY" in
    ""|\#*)
      printf '%s\n' "$ENTRY" >> "$QUEUE_TMP"
      continue
      ;;
  esac

  case "$ENTRY" in
    *'|'*) ;;
    *)
      say "INVALID queue line; kept for manual correction: $ENTRY"
      printf '%s\n' "$ENTRY" >> "$QUEUE_TMP"
      FAILED=$((FAILED + 1))
      continue
      ;;
  esac

  ITEM_TYPE="$(printf '%s\n' "$ENTRY" | cut -d '|' -f 1)"
  ITEM_VALUE="$(printf '%s\n' "$ENTRY" | cut -d '|' -f 2-)"
  case "$ITEM_VALUE" in
    *'|'*)
      say "INVALID queue line with too many fields; kept: $ENTRY"
      printf '%s\n' "$ENTRY" >> "$QUEUE_TMP"
      FAILED=$((FAILED + 1))
      continue
      ;;
  esac

  say ""
  say "Processing: $ENTRY"
  if process_item "$ITEM_TYPE" "$ITEM_VALUE"; then
    if ! grep -Fqx "$ENTRY" "$COMPLETED" 2>/dev/null; then
      printf '%s\n' "$ENTRY" >> "$COMPLETED"
    fi
    say "  DONE — removed from pending queue."
  else
    printf '%s\n' "$ENTRY" >> "$QUEUE_TMP"
    FAILED=$((FAILED + 1))
    say "  PENDING — will be retried next time."
  fi
done < "$QUEUE"

if mv -f "$QUEUE_TMP" "$QUEUE"; then
  say ""
  if [ "$FAILED" -eq 0 ]; then
    say "CLEANUP COMPLETE — no pending cleanup actions remain."
  else
    say "CLEANUP PARTIAL — $FAILED item(s) remain queued for retry."
  fi
  say "Pending queue: $QUEUE"
  say "Completed-item ledger: $COMPLETED"
else
  say "ERROR: Could not replace the queue file; original queue was preserved."
  exit 1
fi

sync 2>/dev/null
[ "$FAILED" -eq 0 ]
