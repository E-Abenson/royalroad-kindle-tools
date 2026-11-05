#!/bin/sh
# Installs or updates only the Royal Road Session Test bookmark.
# Progress is printed to the Kindle display and mirrored to both log files.

DB="/var/local/KPPBrowser.db"
DOCS="/mnt/us/documents"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
URL_FILE="$ROOT/bookmarklets/chapter-session-test.jsurl"
BOOKMARK_LOG="$DOCS/RoyalRoadTools-bookmark.log"
PACKAGE_LOG="$DOCS/RoyalRoadTools.log"

mkdir -p "$DOCS"

log() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$PACKAGE_LOG" "$BOOKMARK_LOG"
}

log "Royal Road bookmark setup started."
log "Checking browser database and bookmarklet source..."

if [ ! -f "$DB" ]; then log "ERROR: Browser database not found at $DB."; exit 1; fi
if ! command -v sqlite3 >/dev/null 2>&1; then log "ERROR: sqlite3 is unavailable."; exit 1; fi
if [ ! -r "$URL_FILE" ]; then log "ERROR: Bookmarklet source is missing."; exit 1; fi

BOOKMARK_URL="$(tr -d '\r\n' < "$URL_FILE")"
case "$BOOKMARK_URL" in javascript:*) ;; *) log "ERROR: Bookmarklet source does not begin with javascript:."; exit 1 ;; esac
URL_HEX="$(printf '%s' "$BOOKMARK_URL" | od -An -tx1 | tr -d ' \n')"
if [ -z "$URL_HEX" ]; then log "ERROR: Could not encode bookmarklet."; exit 1; fi

BOOKMARK_LENGTH="$(printf '%s' "$BOOKMARK_URL" | wc -c | tr -d ' ')"
log "Bookmarklet source checked; length: $BOOKMARK_LENGTH characters."
if command -v sha256sum >/dev/null 2>&1; then
  HASH="$(printf '%s' "$BOOKMARK_URL" | sha256sum | awk '{print $1}')"
  log "Bookmarklet SHA256: $HASH"
fi

log "Checking browser bookmark table..."
TABLE_COUNT="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='bookmark';" 2>/dev/null)"
if [ "$TABLE_COUNT" != "1" ]; then log "ERROR: Expected bookmark table was not found."; exit 1; fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" "SELECT title FROM bookmark LIMIT 0;" >/dev/null 2>&1; then
  log "ERROR: Bookmark table has no expected title column."
  exit 1
fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" "SELECT url FROM bookmark LIMIT 0;" >/dev/null 2>&1; then
  log "ERROR: Bookmark table has no expected url column."
  exit 1
fi

EXACT="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
TITLE_COUNT="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test';" 2>/dev/null)"
if [ "$EXACT" = "1" ] && [ "$TITLE_COUNT" = "1" ]; then
  log "The correct Royal Road Session Test bookmark is already installed."
  log "No database change was needed."
  log "Bookmark setup finished successfully."
  exit 0
fi

log "Preparing a safety backup before modifying the bookmark..."
mkdir -p "$BACKUP_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$BACKUP_DIR/KPPBrowser-before-RR-bookmark-$STAMP.db"
if [ -e "$BACKUP" ]; then BACKUP="$BACKUP-$$.db"; fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1; then
  log "ERROR: Could not back up the browser database; no changes made."
  rm -f "$BACKUP"
  exit 1
fi
log "Safety backup created: $BACKUP"

log "Writing the Royal Road Session Test bookmark..."
if ! sqlite3 -cmd '.timeout 5000' "$DB" "DELETE FROM bookmark WHERE title='Royal Road Session Test'; INSERT INTO bookmark(title,url) VALUES('Royal Road Session Test',CAST(X'$URL_HEX' AS TEXT));" >/dev/null 2>&1; then
  log "ERROR: Could not update bookmark. Backup retained."
  exit 1
fi

log "Verifying the bookmark..."
VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$VERIFY" != "1" ]; then
  log "ERROR: Bookmark verification failed. Backup retained."
  exit 1
fi

log "SUCCESS: Royal Road Session Test bookmark installed/updated and verified."
log "Return to the browser and tap the bookmark on an open Royal Road chapter."
log "Bookmark setup finished OK."
