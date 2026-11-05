#!/bin/sh
# Visible-DOM JavaScript bookmark test for Royal Road Kindle Tools.
# Run this library item, then tap Royal Road Session Test on a chapter.
# If JavaScript runs, a large RR JS EXECUTED panel is added to the chapter.
# Open RoyalRoadTools from the library afterward to restore the real test.

DB="/var/local/KPPBrowser.db"
DOCS="/mnt/us/documents"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
LOG="$DOCS/RR-JS-Smoke-Test.log"
TITLE="Royal Road Session Test"
BOOKMARK_URL="javascript:(function(){var d=document,e=d.getElementById('rr-js-smoke-test');if(e){e.parentNode.removeChild(e);return;}e=d.createElement('div');e.id='rr-js-smoke-test';e.appendChild(d.createTextNode('RR JS EXECUTED'));e.style.position='fixed';e.style.top='8px';e.style.left='8px';e.style.right='8px';e.style.zIndex='2147483647';e.style.background='#fff';e.style.color='#000';e.style.border='4px solid #000';e.style.padding='20px';e.style.font='bold 24px sans-serif';document.body.appendChild(e);})();"

mkdir -p "$DOCS"
log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$LOG"; }
log "Visible-DOM smoke-test bookmark setup started."

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
  log "ERROR: Could not encode the visible-DOM bookmarklet."
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
  log "ERROR: Could not install the visible-DOM smoke-test bookmark. Backup retained."
  exit 1
fi
VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='$TITLE' AND url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$VERIFY" != "1" ]; then
  log "ERROR: Visible-DOM smoke-test bookmark verification failed. Backup retained."
  exit 1
fi
log "SUCCESS: Installed visible-DOM bookmarklet ($(( $(printf '%s' "$BOOKMARK_URL" | wc -c) )) characters)."
log "Next: open a Royal Road chapter and tap Royal Road Session Test."
log "Expected result: a large white panel reading RR JS EXECUTED appears on the chapter."
log "To restore the real diagnostic: open RoyalRoadTools from the Kindle library."
log "No alert dialog is used by this test."

exit 0
