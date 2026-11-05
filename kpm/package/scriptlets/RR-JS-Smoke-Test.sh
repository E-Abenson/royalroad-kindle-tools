#!/bin/sh
# Plain-text-only bookmarklet execution test.
# Run this library item, then tap Royal Road Session Test on a chapter.
# If JavaScript executes, the page body is replaced by the words RR JS EXECUTED.
# Reload the chapter or press Back to restore its original text.
# Open RoyalRoadTools from the library afterward to restore the full diagnostic.
# All progress is printed on screen and mirrored into the log.

DB="/var/local/KPPBrowser.db"
DOCS="/mnt/us/documents"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
LOG="$DOCS/RR-JS-Smoke-Test.log"
TITLE="Royal Road Session Test"
BOOKMARK_URL="javascript:(function(){var d=document,b=d.body;if(!b){return;}b.textContent='RR JS EXECUTED';b.setAttribute('style','margin:0!important;padding:24px!important;background:#fff!important;color:#000!important;font-size:32px!important;font-weight:bold!important;font-family:sans-serif!important;text-align:center!important;');})();"

mkdir -p "$DOCS"
say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

say "============================================================"
say "ROYAL ROAD — JAVASCRIPT BOOKMARK TEST SETUP"
say "Checking Kindle browser bookmark database..."

if [ ! -f "$DB" ]; then
  say "ERROR: Browser database not found at $DB."
  exit 1
fi
if ! command -v sqlite3 >/dev/null 2>&1; then
  say "ERROR: sqlite3 is unavailable."
  exit 1
fi

say "Encoding the temporary test bookmark..."
URL_HEX="$(printf '%s' "$BOOKMARK_URL" | od -An -tx1 | tr -d ' \n')"
if [ -z "$URL_HEX" ]; then
  say "ERROR: Could not encode the bookmarklet."
  exit 1
fi

say "Checking the browser bookmark table and required columns..."
if [ "$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='bookmark';" 2>/dev/null)" != "1" ]; then
  say "ERROR: Expected browser bookmark table was not found."
  exit 1
fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" "SELECT title FROM bookmark LIMIT 0;" >/dev/null 2>&1 ||
   ! sqlite3 -cmd '.timeout 5000' "$DB" "SELECT url FROM bookmark LIMIT 0;" >/dev/null 2>&1; then
  say "ERROR: Browser bookmark table does not have the expected columns."
  exit 1
fi

say "Creating a backup before changing the one test bookmark..."
mkdir -p "$BACKUP_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$BACKUP_DIR/KPPBrowser-before-JS-smoke-test-$STAMP.db"
if [ -e "$BACKUP" ]; then BACKUP="$BACKUP-$$.db"; fi
if ! sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1; then
  say "ERROR: Could not back up the browser database; no changes made."
  rm -f "$BACKUP"
  exit 1
fi
say "Backup created: $BACKUP"

say "Installing the temporary page-replacement bookmark..."
if ! sqlite3 -cmd '.timeout 5000' "$DB" "BEGIN IMMEDIATE; DELETE FROM bookmark WHERE title='$TITLE'; INSERT INTO bookmark(title,url) VALUES('$TITLE',CAST(X'$URL_HEX' AS TEXT)); COMMIT;" >/dev/null 2>&1; then
  say "ERROR: Could not install test bookmark. Backup retained."
  exit 1
fi

say "Verifying the saved bookmark..."
VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='$TITLE' AND url=CAST(X'$URL_HEX' AS TEXT);" 2>/dev/null)"
if [ "$VERIFY" != "1" ]; then
  say "ERROR: Test bookmark verification failed. Backup retained."
  exit 1
fi

say "SUCCESS — temporary bookmark installed and verified."
say ""
say "NEXT:"
say "1. Open a Royal Road chapter in the Kindle browser."
say "2. Tap Royal Road Session Test in the browser bookmarks."
say "3. If JavaScript runs, the chapter text will be replaced by:"
say "   RR JS EXECUTED"
say "4. Reload the chapter or press Back to restore it."
say ""
say "To restore the full diagnostic bookmark, open RoyalRoadTools in the library."
say "No chapter text, cookies, credentials, or browser history were read."
say "Finished: $(date)"
exit 0
