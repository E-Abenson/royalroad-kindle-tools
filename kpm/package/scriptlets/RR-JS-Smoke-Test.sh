#!/bin/sh
# Temporary JavaScript-bookmark execution test for Royal Road Kindle Tools.
# Run RR-JS-Smoke-Test from the Kindle library, then tap the existing
# Royal Road Session Test bookmark on an open Royal Road chapter.
# Restore the full diagnostic by opening RoyalRoadTools from the library.

DB="/var/local/KPPBrowser.db"
DOCS="/mnt/us/documents"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
LOG="$DOCS/RR-JS-Smoke-Test.log"
TITLE="Royal Road Session Test"
BOOKMARK_URL="javascript:alert('RR JS EXECUTED')"

mkdir -p "$DOCS"
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG"; }
log "Smoke-test bookmark setup started."

if [ ! -f "$DB" ]; then
  log "ERROR: Browser database not found at $DB."
  exit 1
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
  log "ERROR: sqlite3 is unavailable."
  exit 1
fi

URL_HEX="$(printf '%s' "$BOOKMARK_URL" | od -An -tx1 | tr -d ' \n')"
if [ -z "$URL_HEX" ]; then
  log "ERROR: Could not encode the smoke-test bookmarklet."
  exit 1
fi

if [ "$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='bookmark';" 2>/dev/null)" != "1" ]; then
  log "ERROR: Expected browser bookmark table was not found."
  exit 1
fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" "SELECT title FROM bookmark LIMIT 0;" >/dev/null 2>&1 ||
   ! sqlite3 -cmd '.timeout 5000' "$DB" "SELECT url FROM bookmark LIMIT 0;" >/dev/null 2>&1; then
  log "ERROR: Browser bookmark table does not have the expected columns."
  exit 1
fi

mkdir -p "$BACKUP_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$BACKUP_DIR/KPPBrowser-before-JS-smoke-test-$STAMP.db"
if [ -e "$BACKUP" ]; then BACKUP="$BACKUP-$$.db"; fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1; then
  log "ERROR: Could not back up the browser database; no changes made."
  rm -f "$BACKUP"
  exit 1
fi
log "Browser database backup: $BACKUP"

if ! sqlite3 -cmd '.timeout 5000' "$DB" "BEGIN IMMEDIATE; DELETE FROM bookmark WHERE title='$TITLE'; INSERT INTO bookmark(title,url) VALUES('$TITLE',CAST(X'$URL_HEX' AS TEXT)); COMMIT;" >/dev/null 2>&1; then
  log "ERROR: Could not install the smoke-test bookmark. Backup retained."
  exit 1
fi
VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='$TITLE' AND url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$VERIFY" != "1" ]; then
  log "ERROR: Smoke-test bookmark verification failed. Backup retained."
  exit 1
fi
log "SUCCESS: The bookmark now contains only javascript:alert('RR JS EXECUTED')."
log "Next: open a Royal Road chapter and tap Royal Road Session Test."
log "To restore: open RoyalRoadTools from the Kindle library."

ALERT='/usr/bin/lipc-set-prop'
if [ ! -x "$ALERT" ]; then ALERT="$(command -v lipc-set-prop 2>/dev/null || true)"; fi
if [ -n "$ALERT" ] && [ -x "$ALERT" ]; then
  "$ALERT" com.lab126.pillow pillowAlert '{"clientParams":{"alertId":"rrJsSmokeTest","show":true,"customStrings":[{"matchStr":"alertTitle","replaceStr":"Smoke test installed"},{"matchStr":"alertText","replaceStr":"Open browser and tap Royal Road Session Test"}]}}' >/dev/null 2>&1 || true
  sleep 6
  "$ALERT" com.lab126.pillow pillowAlert '{"clientParams":{"alertId":"rrJsSmokeTest","show":false}}' >/dev/null 2>&1 || true
fi

exit 0
