#!/bin/sh
# Removes only this package's exact bookmark URL, after backing up the database.
DB="/var/local/KPPBrowser.db"
DOCS="/mnt/us/documents"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
URL_FILE="$ROOT/bookmarklets/chapter-session-test.jsurl"
LOG="$DOCS/RoyalRoadTools.log"

mkdir -p "$DOCS"
log() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

log "Starting safe removal of the Royal Road Session Test bookmark."
if [ ! -f "$DB" ]; then
  log "ERROR: Browser database not found; bookmark was not removed."
  exit 1
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR: sqlite3 is unavailable; bookmark was not removed."
  exit 1
fi
if [ ! -r "$URL_FILE" ]; then
  log "ERROR: Bookmarklet source is unavailable; bookmark was not removed."
  exit 1
fi

BOOKMARK_URL="$(tr -d '\r\n' < "$URL_FILE")"
URL_HEX="$(printf '%s' "$BOOKMARK_URL" | od -An -tx1 | tr -d ' \n')"
log "Checking whether the exact package bookmark is present..."
EXISTING="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$EXISTING" = "0" ]; then
  log "The package bookmark is already absent; nothing to remove."
  exit 0
fi

log "Creating a safety backup..."
mkdir -p "$BACKUP_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$BACKUP_DIR/KPPBrowser-before-RR-bookmark-removal-$STAMP.db"
if ! sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1; then
  log "ERROR: Could not back up browser database; bookmark was not removed."
  exit 1
fi
log "Safety backup created: $BACKUP"

log "Removing only the exact Royal Road Session Test URL..."
if ! sqlite3 -cmd '.timeout 5000' "$DB" "DELETE FROM bookmark WHERE url=CAST(X'$URL_HEX' AS TEXT);" >/dev/null 2>&1; then
  log "ERROR: SQLite could not remove the bookmark. Backup retained."
  exit 1
fi

log "Verifying removal..."
VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$VERIFY" != "0" ]; then
  log "ERROR: Bookmark removal verification failed; backup retained at $BACKUP"
  exit 1
fi

log "SUCCESS: Removed only the Royal Road Session Test bookmark."
log "Other bookmarks, cookies and browser history were not changed."
