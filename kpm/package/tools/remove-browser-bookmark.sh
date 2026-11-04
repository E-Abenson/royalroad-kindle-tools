#!/bin/sh
# Removes only this package's exact bookmark URL, after backing up the database.
DB="/var/local/KPPBrowser.db"
DOCS="/mnt/us/documents"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
URL_FILE="$ROOT/bookmarklets/chapter-session-test.jsurl"
LOG="$DOCS/RoyalRoadTools.log"
if [ ! -f "$DB" ] || ! command -v sqlite3 >/dev/null 2>&1 || [ ! -r "$URL_FILE" ]; then
  echo "Could not safely access browser database or bookmarklet source; no bookmark was removed." >> "$LOG"
  exit 1
fi
BOOKMARK_URL="$(tr -d '\r\n' < "$URL_FILE")"
URL_HEX="$(printf '%s' "$BOOKMARK_URL" | od -An -tx1 | tr -d ' \n')"
EXISTING="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$EXISTING" = "0" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Test bookmark was already absent." >> "$LOG"
  exit 0
fi
mkdir -p "$BACKUP_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$BACKUP_DIR/KPPBrowser-before-RR-bookmark-removal-$STAMP.db"
if ! sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1; then
  echo "Could not back up browser database; bookmark was not removed." >> "$LOG"
  exit 1
fi
sqlite3 -cmd '.timeout 5000' "$DB" "DELETE FROM bookmark WHERE url=CAST(X'$URL_HEX' AS TEXT);" >/dev/null 2>&1 || exit 1
VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$VERIFY" != "0" ]; then
  echo "Bookmark removal verification failed; backup retained at $BACKUP" >> "$LOG"
  exit 1
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Removed only Royal Road Session Test bookmark. Backup: $BACKUP" >> "$LOG"
