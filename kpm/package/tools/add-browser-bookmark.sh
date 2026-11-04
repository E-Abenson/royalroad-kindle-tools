#!/bin/sh
# Inserts exactly one JavaScript bookmark into KPPBrowser.db.
# It never reads or changes cookies, history, credentials, or page contents.
DB="/var/local/KPPBrowser.db"
DOCS="/mnt/us/documents"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
URL_FILE="$ROOT/bookmarklets/chapter-session-test.jsurl"
LOG="$DOCS/RoyalRoadTools.log"
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
  echo "$*"
}
if [ ! -f "$DB" ]; then log "Browser database not found at $DB; no changes made."; exit 1; fi
if ! command -v sqlite3 >/dev/null 2>&1; then log "sqlite3 is unavailable; no changes made."; exit 1; fi
if [ ! -r "$URL_FILE" ]; then log "Bookmarklet source is missing; no changes made."; exit 1; fi
BOOKMARK_URL="$(tr -d '\r\n' < "$URL_FILE")"
case "$BOOKMARK_URL" in javascript:*) ;; *) log "Bookmarklet source did not begin with javascript:; no changes made."; exit 1 ;; esac
URL_HEX="$(printf '%s' "$BOOKMARK_URL" | od -An -tx1 | tr -d ' \n')"
if [ -z "$URL_HEX" ]; then log "Could not encode bookmarklet; no changes made."; exit 1; fi
TABLE_COUNT="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='bookmark';" 2>/dev/null)"
if [ "$TABLE_COUNT" != "1" ]; then log "Expected bookmark table was not found; no changes made."; exit 1; fi
# Use simple SELECT checks instead of table-valued PRAGMA functions so this
# also works with older SQLite builds supplied on some Kindle firmware.
if ! sqlite3 -cmd '.timeout 5000' "$DB" "SELECT title FROM bookmark LIMIT 0;" >/dev/null 2>&1; then
  log "Bookmark table does not expose the expected title column; no changes made."
  exit 1
fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" "SELECT url FROM bookmark LIMIT 0;" >/dev/null 2>&1; then
  log "Bookmark table does not expose the expected url column; no changes made."
  exit 1
fi
EXISTING="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$EXISTING" = "1" ]; then log "Browser test bookmark is already installed. No database change was needed."; exit 0; fi
mkdir -p "$BACKUP_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$BACKUP_DIR/KPPBrowser-before-RR-bookmark-$STAMP.db"
if ! sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1; then
  log "Could not back up the browser bookmark database; no changes made."
  rm -f "$BACKUP"
  exit 1
fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" "INSERT OR IGNORE INTO bookmark(title,url) VALUES('Royal Road Session Test',CAST(X'$URL_HEX' AS TEXT));" >/dev/null 2>&1; then
  log "Could not insert test bookmark. Backup retained at $BACKUP"
  exit 1
fi
VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$VERIFY" != "1" ]; then log "Bookmark verification failed. Backup retained at $BACKUP"; exit 1; fi
log "Installed one bookmark: Royal Road Session Test."
log "Database backup: $BACKUP"
log "Only the bookmark table was changed. No cookies, history, or page text were read or transmitted."
