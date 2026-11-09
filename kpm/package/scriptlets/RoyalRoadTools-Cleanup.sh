#!/bin/sh
# Name: RoyalRoadTools-Cleanup
# One-time cleanup of completed Royal Road Kindle experiments.
# Preserves the pending KPP bundle scan, KPM updater and KOReader repair utility.

DOCS="/mnt/us/documents"
DB="/var/local/KPPBrowser.db"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
DONE_FILE="$DOCS/.RoyalRoadTools-Cleanup.done"
PACKAGE_DIR="/mnt/us/kmc/kpm/packages/royalroad-kindle-tools"
OLD_DELETE_FILE="$DOCS/RR-JS-Smoke-Test-delete-url.txt"
CLEANUP_OK=1
say() { printf '%s\n' "$*"; }

say "============================================================"
say "ROYAL ROAD KINDLE TOOLS — CLEANUP OF FINISHED TESTS"
say "Preserving: RR-KPP-Bundle-Scan, its uploader, KPM-Update-All and KindleBatchPrepareFix."

# Delete the old temporary diagnostic paste if its private deletion URL was saved.
if [ -s "$OLD_DELETE_FILE" ] && command -v curl >/dev/null 2>&1; then
  DELETE_URL="$(sed -n '1p' "$OLD_DELETE_FILE" | tr -d '\r\n')"
  case "$DELETE_URL" in
    https://pasters.io/d/*)
      DELETE_STATUS="$(curl -sS --connect-timeout 8 --max-time 20 -X DELETE -o /dev/null -w '%{http_code}' "$DELETE_URL" 2>/dev/null)"
      case "$DELETE_STATUS" in
        2??) say "Deleted the old temporary pasters.io diagnostic paste." ;;
        404|410) say "The old temporary diagnostic paste has already expired or been deleted." ;;
        *) say "Could not confirm remote paste deletion; it expires automatically." ;;
      esac
      ;;
    *) say "Saved deletion URL was not a recognized pasters.io delete URL; remote paste was not contacted." ;;
  esac
fi

# The old installer used this exact title for its JavaScript bookmark.
# Back up the browser database before deleting only that test bookmark.
if [ -f "$DB" ] && command -v sqlite3 >/dev/null 2>&1; then
  TABLE_COUNT="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='bookmark';" 2>/dev/null)"
  if [ "$TABLE_COUNT" = "1" ]; then
    EXISTING="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" 2>/dev/null)"
    case "$EXISTING" in
      ''|*[!0-9]*)
        say "WARNING: Could not verify the old bookmark; browser database was not changed."
        CLEANUP_OK=0
        ;;
      0)
        say "The old Royal Road Session Test bookmark is already absent."
        ;;
      *)
        mkdir -p "$BACKUP_DIR"
        BACKUP="$BACKUP_DIR/KPPBrowser-before-RR-cleanup-$(date '+%Y%m%d-%H%M%S').db"
        if sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1; then
          if sqlite3 -cmd '.timeout 5000' "$DB" "DELETE FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" >/dev/null 2>&1; then
            VERIFY="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" 2>/dev/null)"
            if [ "$VERIFY" = "0" ]; then
              say "Removed and verified the old Royal Road Session Test bookmark."
              rm -f "$BACKUP"
            else
              say "WARNING: Verification failed; safety backup retained at $BACKUP"
              CLEANUP_OK=0
            fi
          else
            say "WARNING: Bookmark deletion failed; safety backup retained at $BACKUP"
            CLEANUP_OK=0
          fi
        else
          say "WARNING: Could not create a browser database backup; no bookmark was changed."
          CLEANUP_OK=0
        fi
        ;;
    esac
  else
    say "WARNING: Browser bookmark table not found; database was not changed."
    CLEANUP_OK=0
  fi
else
  say "WARNING: Browser database or sqlite3 unavailable; bookmark removal could not be verified."
  CLEANUP_OK=0
fi

# Remove only database backups made by the retired bookmark experiment.
if [ "$CLEANUP_OK" -eq 1 ] && [ -d "$BACKUP_DIR" ]; then
  for FILE in "$BACKUP_DIR"/KPPBrowser-before-RR-bookmark-*.db "$BACKUP_DIR"/KPPBrowser-before-RR-bookmark-removal-*.db "$BACKUP_DIR"/KPPBrowser-before-RR-cleanup-*.db; do
    [ -f "$FILE" ] && rm -f "$FILE"
  done
  rmdir "$BACKUP_DIR" 2>/dev/null || true
fi

# Retired launchers.
for ITEM in RR-JS-Smoke-Test.sh RR-LIPC-Metadata-Check.sh RR-Upload-Diagnostic.sh \
  RoyalRoadTools.sh KindleBatchPrepareDiagnostics.sh; do
  [ -f "$DOCS/$ITEM" ] && rm -f "$DOCS/$ITEM"
done

# Retired logs, links and temporary files. Keep logs for scripts still in use.
for ITEM in RR-JS-Smoke-Test.log RR-JS-Smoke-Test-upload-url.txt RR-JS-Smoke-Test-delete-url.txt \
  RR-Upload-Diagnostic.log KindleBatchPrepareDiagnostics.log RoyalRoadTools-installed-version.txt \
  RoyalRoadTools-package.log RoyalRoadTools-install.log RoyalRoadTools-launch.log \
  RoyalRoadTools-bookmark.log RoyalRoadTools.log; do
  [ -f "$DOCS/$ITEM" ] && rm -f "$DOCS/$ITEM"
done
for FILE in "$DOCS"/RoyalRoadTools-test-*.log "$DOCS"/.RoyalRoadTools-launch-status.* \
  "$DOCS"/.RoyalRoadTools-install-status.* "$DOCS"/.KindleBatchPrepareFix-status.* \
  "$DOCS"/.RR-JS-Smoke-Test-upload-*.txt "$DOCS"/.RR-JS-Smoke-Test-response-*.txt \
  "$DOCS"/.RR-JS-Smoke-Test-headers-*.txt; do
  [ -f "$FILE" ] && rm -f "$FILE"
done

# Remove obsolete feature files from the unpacked KPM package, if present.
if [ -d "$PACKAGE_DIR" ]; then
  rm -f "$PACKAGE_DIR/bookmarklets/chapter-session-test.jsurl"
  rm -f "$PACKAGE_DIR/tools/add-browser-bookmark.sh" "$PACKAGE_DIR/tools/remove-browser-bookmark.sh"
  rmdir "$PACKAGE_DIR/bookmarklets" "$PACKAGE_DIR/tools" 2>/dev/null || true
fi
rm -f "$OLD_DELETE_FILE" "$DOCS/RR-JS-Smoke-Test-upload-url.txt"

if [ "$CLEANUP_OK" -eq 1 ]; then
  printf 'completed=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" > "$DONE_FILE"
  chmod 600 "$DONE_FILE" 2>/dev/null || true
  say ""
  say "CLEANUP SUCCESSFUL."
  say "Old smoke/LIPC tests, bookmarklet files, obsolete logs/links and test backups are removed."
  say "KPM-Update-All.log and KindleBatchPrepareFix.log were kept because those tools remain in use."
  say "The unfinished KPP bundle scan and uploader were preserved."
  rm -f "$DOCS/RoyalRoadTools-Cleanup.sh"
  exit 0
fi

say ""
say "CLEANUP PARTIAL: old test files were removed, but bookmark removal could not be verified."
say "The cleanup launcher remains so this can be retried."
exit 1
