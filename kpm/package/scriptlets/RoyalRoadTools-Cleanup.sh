#!/bin/sh
# Name: RoyalRoadTools-Cleanup
# One-time retirement of the old smoke-test and KPP bundle-scan experiments.
# Preserves the new read-only LIPC probe and the maintenance tools.

DOCS="/mnt/us/documents"
DB="/var/local/KPPBrowser.db"
BACKUP_DIR="$DOCS/RoyalRoadTools-backups"
DONE_FILE="$DOCS/.RoyalRoadTools-Cleanup-v2.done"
PACKAGE_DIR="/mnt/us/kmc/kpm/packages/royalroad-kindle-tools"
CLEANUP_OK=1
say() { printf '%s\n' "$*"; }

say "============================================================"
say "ROYAL ROAD KINDLE TOOLS — RETIRED TEST CLEANUP"
say "Preserving: RR-LIPC-READONLY-PROBE, KPM-Update-All, KindleBatchPrepareFix and Version-Info."

# Delete previously uploaded temporary diagnostic pastes, if the local
# deletion URLs were saved. Only the pasters.io deletion endpoint is accepted.
delete_remote_paste() {
  DELETE_FILE="$1"
  if [ ! -s "$DELETE_FILE" ]; then
    return
  fi
  if ! command -v curl >/dev/null 2>&1; then
    say "curl is unavailable; a saved temporary paste could not be deleted remotely."
    return
  fi

  DELETE_URL="$(sed -n '1p' "$DELETE_FILE" | tr -d '\r\n')"
  case "$DELETE_URL" in
    https://pasters.io/d/*)
      DELETE_STATUS="$(curl -sS --connect-timeout 8 --max-time 20 -X DELETE -o /dev/null -w '%{http_code}' "$DELETE_URL" 2>/dev/null)"
      case "$DELETE_STATUS" in
        2??) say "Deleted a saved temporary diagnostic paste." ;;
        404|410) say "A saved temporary diagnostic paste has already expired or been deleted." ;;
        *) say "Could not confirm remote paste deletion; it should expire automatically." ;;
      esac
      ;;
    *) say "A saved deletion URL was not a recognized pasters.io delete URL; it was not contacted." ;;
  esac
}

delete_remote_paste "$DOCS/RR-JS-Smoke-Test-delete-url.txt"
delete_remote_paste "$DOCS/RR-KPP-Bundle-Scan-delete-url.txt"

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

# Retired test launchers. The new RR-LIPC-READONLY-PROBE is intentionally kept.
for ITEM in RR-JS-Smoke-Test.sh RR-LIPC-Metadata-Check.sh RR-Upload-Diagnostic.sh \
  RR-KPP-Bundle-Scan.sh RR-Upload-Bundle-Scan.sh KindleBatchPrepareDiagnostics.sh \
  RoyalRoadTools.sh; do
  [ -f "$DOCS/$ITEM" ] && rm -f "$DOCS/$ITEM"
done

# Retired test logs, upload links, deletion links and obsolete reports.
for ITEM in RR-JS-Smoke-Test.log RR-JS-Smoke-Test-upload-url.txt RR-JS-Smoke-Test-delete-url.txt \
  RR-KPP-Bundle-Scan.log RR-KPP-Bundle-Scan-upload-url.txt RR-KPP-Bundle-Scan-delete-url.txt \
  RR-Upload-Bundle-Scan.log RR-LIPC-Metadata-Check.log RR-Upload-Diagnostic.log \
  KindleBatchPrepareDiagnostics.log RoyalRoadTools-installed-version.txt \
  RoyalRoadTools-package.log RoyalRoadTools-install.log RoyalRoadTools-launch.log \
  RoyalRoadTools-bookmark.log RoyalRoadTools.log; do
  [ -f "$DOCS/$ITEM" ] && rm -f "$DOCS/$ITEM"
done
for FILE in "$DOCS"/RoyalRoadTools-test-*.log "$DOCS"/.RoyalRoadTools-launch-status.* \
  "$DOCS"/.RoyalRoadTools-install-status.* "$DOCS"/.KindleBatchPrepareFix-status.* \
  "$DOCS"/.RR-JS-Smoke-Test-upload-*.txt "$DOCS"/.RR-JS-Smoke-Test-response-*.txt \
  "$DOCS"/.RR-JS-Smoke-Test-headers-*.txt "$DOCS"/.RR-KPP-Bundle-Scan-upload-*.txt \
  "$DOCS"/.RR-KPP-Bundle-Scan-response-*.txt "$DOCS"/.RR-KPP-Bundle-Scan-headers-*.txt; do
  [ -f "$FILE" ] && rm -f "$FILE"
done

# Remove the old scan scripts from the installed package cache as well.
if [ -d "$PACKAGE_DIR" ]; then
  rm -f "$PACKAGE_DIR/scriptlets/RR-KPP-Bundle-Scan.sh"
  rm -f "$PACKAGE_DIR/scriptlets/RR-Upload-Bundle-Scan.sh"
  rm -f "$PACKAGE_DIR/bookmarklets/chapter-session-test.jsurl"
  rm -f "$PACKAGE_DIR/tools/add-browser-bookmark.sh" "$PACKAGE_DIR/tools/remove-browser-bookmark.sh"
  rmdir "$PACKAGE_DIR/bookmarklets" "$PACKAGE_DIR/tools" 2>/dev/null || true
fi

# Retire the old completion marker so the v2 cleanup can run once.
rm -f "$DOCS/.RoyalRoadTools-Cleanup.done"
rm -f "$DOCS/RR-JS-Smoke-Test-upload-url.txt" "$DOCS/RR-KPP-Bundle-Scan-upload-url.txt"

if [ "$CLEANUP_OK" -eq 1 ]; then
  printf 'completed=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" > "$DONE_FILE"
  chmod 600 "$DONE_FILE" 2>/dev/null || true
  say ""
  say "CLEANUP SUCCESSFUL."
  say "Old smoke/LIPC tests, KPP bundle scan/uploader, their logs, links and temporary files are removed."
  say "RR-LIPC-READONLY-PROBE.log is preserved for the new investigation."
  say "KPM-Update-All.log and KindleBatchPrepareFix.log are preserved because those tools remain in use."
  rm -f "$DOCS/RoyalRoadTools-Cleanup.sh"
  exit 0
fi

say ""
say "CLEANUP PARTIAL: old test files were removed, but bookmark removal could not be verified."
say "The cleanup launcher remains so the bookmark check can be retried."
exit 1
