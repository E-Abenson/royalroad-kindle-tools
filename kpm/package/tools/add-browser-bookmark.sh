#!/bin/sh
# Installs or updates only the Royal Road Session Test bookmark.
DB="/var/local/KPPBrowser.db"
DOCS="/mnt/us/documents"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
URL_FILE="$ROOT/bookmarklets/chapter-session-test.jsurl"
BOOKMARK_LOG="$DOCS/RoyalRoadTools-bookmark.log"
PACKAGE_LOG="$DOCS/RoyalRoadTools.log"
log() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$LINE" >> "$PACKAGE_LOG"
  echo "$LINE" >> "$BOOKMARK_LOG"
  echo "$*"
}
log "Bookmark setup started."
if [ ! -f "$DB" ]; then log "ERROR: Browser database not found at $DB."; exit 1; fi
if ! command -v sqlite3 >/dev/null 2>&1; then log "ERROR: sqlite3 is unavailable."; exit 1; fi
if [ ! -r "$URL_FILE" ]; then log "ERROR: Bookmarklet source is missing."; exit 1; fi
BOOKMARK_URL="$(tr -d '\r\n' < "$URL_FILE")"
case "$BOOKMARK_URL" in javascript:*) ;; *) log "ERROR: Bookmarklet source does not begin with javascript:."; exit 1 ;; esac
URL_HEX="$(printf '%s' "$BOOKMARK_URL" | od -An -tx1 | tr -d ' \n')"
if [ -z "$URL_HEX" ]; then log "ERROR: Could not encode bookmarklet."; exit 1; fi
BOOKMARK_LENGTH="$(printf '%s' "$BOOKMARK_URL" | wc -c | tr -d ' ')"
log "New bookmarklet length: $BOOKMARK_LENGTH characters."
if command -v sha256sum >/dev/null 2>&1; then
  HASH="$(printf '%s' "$BOOKMARK_URL" | sha256sum | awk '{print $1}')"
  log "New bookmarklet SHA256: $HASH"
fi
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
  log "Bookmark already matches the installed test version; no database change."
  log "Bookmark setup finished OK."
  exit 0
fi
mkdir -p "$BACKUP_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$BACKUP_DIR/KPPBrowser-before-RR-bookmark-$STAMP.db"
if [ -e "$BACKUP" ]; then BACKUP="$BACKUP-$$.db"; fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1; then
  log "ERROR: Could not back up the browser database; no changes made."
  rm -f "$BACKUP"
  exit 1
fi
log "Browser database backup: $BACKUP"
if ! sqlite3 -cmd '.timeout 5000' "$DB" "DELETE FROM bookmark WHERE title='Royal Road Session Test'; INSERT INTO bookmark(title,url) VALUES('Royal Road Session Test',CAST(X'$URL_HEX' AS TEXT));" >/dev/null 2>&1; then
  log "ERROR: Could not update bookmark. Backup retained."
  exit 1
fi
VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$VERIFY" != "1" ]; then
  log "ERROR: Bookmark verification failed. Backup retained."
  exit 1
fi
log "SUCCESS: Installed/updated the Royal Road Session Test bookmark."
log "Bookmark setup finished OK."
