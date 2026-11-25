#!/bin/sh
# KPM Update All: refresh repositories, upgrade packages, clean retired files, update versions.
# Retirement rules are code in this launcher; no separate cleanup helper, queue, or completed-items log.
KPM="/var/local/kmc/bin/kpm"
DOCS="/mnt/us/documents"
INTERNAL="$DOCS/.royalroadtools"
LOG="$DOCS/KPM-Update-All.log"
VERSION_REPORT="$INTERNAL/version-info.sh"
PACKAGE_DIR="/mnt/us/kmc/kpm/packages/royalroad-kindle-tools"
mkdir -p "$DOCS" "$INTERNAL"
if [ "${1:-}" != "--cleanup-only" ]; then : > "$LOG"; fi
say() { LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"; printf '%s\n' "$LINE" | tee -a "$LOG"; }
run_and_show() {
  STATUS_FILE="$INTERNAL/.KPM-Update-All-status.$$"; rm -f "$STATUS_FILE"
  ( "$@"; RC=$?; printf '%s\n' "$RC" > "$STATUS_FILE"; exit "$RC" ) 2>&1 | tee -a "$LOG"
  if [ -f "$STATUS_FILE" ]; then RC="$(cat "$STATUS_FILE" 2>/dev/null)"; else RC=1; say "ERROR: command status was not returned."; fi
  rm -f "$STATUS_FILE"; return "$RC"
}
cleanup_retired_files() {
  CLEANED=0; FAILED=0
  remove_file() {
    TARGET="$1"
    if [ -f "$TARGET" ] || [ -L "$TARGET" ]; then
      if rm -f "$TARGET" 2>/dev/null && [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then CLEANED=$((CLEANED + 1)); else FAILED=$((FAILED + 1)); fi
    fi
  }
  remove_names() { for NAME in "$@"; do remove_file "$DOCS/$NAME"; done; }
  remove_patterns() { for PATTERN in "$@"; do for TARGET in "$DOCS"/$PATTERN; do if [ -f "$TARGET" ] || [ -L "$TARGET" ]; then remove_file "$TARGET"; fi; done; done; }

  # Try known old remote paste deletion URLs, then remove their local private URL files.
  for NAME in RR-JS-Smoke-Test-delete-url.txt RR-KPP-Bundle-Scan-delete-url.txt RR-LIPC-READONLY-UPLOAD-DELETE-URL.txt KPP-Comprehensive-Diagnostic-delete-url.txt KPP-Last-Open-Page-Check-delete-url.txt; do
    LINK="$DOCS/$NAME"
    if [ -s "$LINK" ]; then
      URL="$(sed -n '1p' "$LINK" | tr -d '\r\n')"
      case "$URL" in https://pasters.io/d/*) if command -v curl >/dev/null 2>&1; then curl -sS --connect-timeout 8 --max-time 20 -X DELETE -o /dev/null "$URL" >/dev/null 2>&1 || true; fi ;; esac
      remove_file "$LINK"
    fi
  done

  # Retired files only; working exporters, USB inspector, updater, current report,
  # KPP bundle copy, books, EPUBs and unrelated user files are not targets.
  remove_names \
    RR-JS-Smoke-Test.sh RR-JS-Smoke-Test.log RR-JS-Smoke-Test-upload-url.txt \
    RR-LIPC-Metadata-Check.sh RR-LIPC-Metadata-Check.log RR-Upload-Diagnostic.sh RR-Upload-Diagnostic.log \
    RR-KPP-Bundle-Scan.sh RR-KPP-Bundle-Scan.log RR-KPP-Bundle-Scan-upload-url.txt \
    RR-Upload-Bundle-Scan.sh RR-Upload-Bundle-Scan.log KindleBatchPrepareDiagnostics.sh KindleBatchPrepareDiagnostics.log \
    RoyalRoadTools.sh RoyalRoadTools-installed-version.txt RoyalRoadTools-package.log RoyalRoadTools-install.log \
    RoyalRoadTools-launch.log RoyalRoadTools-bookmark.log RoyalRoadTools.log RR-LIPC-READONLY-PROBE.sh \
    RR-LIPC-READONLY-PROBE.log RR-LIPC-READONLY-UPLOAD.sh RR-LIPC-READONLY-UPLOAD-URL.txt \
    RoyalRoadTools-Version-Info.sh Kindle-Version-Report.sh RR-KPP-Interface-Inspector.sh \
    RR-KPP-Interface-Inspector-Upload.sh RR-KPP-Interface-Inspector.log .RR-KPP-Interface-Inspector-delete-url.txt \
    RoyalRoadTools-Cleanup.sh RoyalRoadTools-Cleanup-Queue.txt RoyalRoadTools-Cleanup-Completed.txt RoyalRoadTools-Cleanup.log \
    Install-RoyalRoadTools.sh KPP-Comprehensive-Diagnostic-upload-url.txt KPP-Last-Open-Page-Check-upload-url.txt \
    KPP-Comprehensive-Diagnostic.txt KPP-Last-Open-Page-Check.txt KPP-Comprehensive-Diagnostic.sh KPP-Last-Open-Page-Check.sh \
    RR-KPP-Bytecode-Export.sh KPP-Bytecode-Export.txt Install-Rabbinic-Screensavers.sh Install-Rabbinic-Screensavers.log \
    KindleBatchPrepareFix.sh KindleBatchPrepareFix.log KindleBatchPrepare-main.lua.gz \
    KPP-Native-Bridge-Full-Export.sh KPP-Native-Bridge-Full-Export.txt

  # Generated test/status patterns only; no recursive sweep of Documents.
  remove_patterns \
    RoyalRoadTools-test-*.log .RoyalRoadTools-launch-status.* .RoyalRoadTools-install-status.* \
    .KindleBatchPrepareFix-status.* .RR-JS-Smoke-Test-upload-*.txt .RR-JS-Smoke-Test-response-*.txt \
    .RR-JS-Smoke-Test-headers-*.txt .RR-KPP-Bundle-Scan-upload-*.txt .RR-KPP-Bundle-Scan-response-*.txt \
    .RR-KPP-Bundle-Scan-headers-*.txt .RR-KPP-Interface-Inspector-* .KPM-Update-All-status.* \
    .RoyalRoadTools-installed-version.txt.tmp.* .Kindle-Version-Report.txt.tmp.* \
    RR-JS-Smoke-Test* RR-KPP-Bundle-Scan* RR-LIPC-* RR-Upload-Diagnostic* RR-Upload-Bundle-Scan* \
    RR-KPP-Interface-Inspector* KindleBatchPrepareDiagnostics* KPP-Comprehensive-Diagnostic* \
    KPP-Last-Open-Page-Check* RR-KPP-Bytecode-Export* .KPP-Comprehensive-Diagnostic-* \
    .KPP-Last-Open-Page-Check-* .RR-JS-Smoke-Test-* .RR-KPP-Bundle-Scan-* .RR-LIPC-* \
    .RR-Upload-Diagnostic-* .RR-Upload-Bundle-Scan-* .KindleBatchPrepareDiagnostics-*

  # Retire old hidden helpers, keeping the active version-info helper.
  remove_file "$INTERNAL/cleanup.sh"
  remove_file "$INTERNAL/inspector-upload.sh"
  remove_file "$INTERNAL/bytecode-export.sh"
  remove_file "$INTERNAL/last-open-page-private.txt"
  remove_file "$DOCS/.rr-kpp-research/KPPMainApp.js.hbc"
  rmdir "$DOCS/.rr-kpp-research" 2>/dev/null || true

  # Stale files from this package's cache only.
  for ITEM in scriptlets/RoyalRoadTools-Cleanup.sh scriptlets/RoyalRoadTools-Cleanup-Queue.txt \
    scriptlets/KindleBatchPrepareFix.sh files/kindle_batch_prepare_main.lua.gz \
    scriptlets/RR-LIPC-READONLY-PROBE.sh scriptlets/RR-LIPC-READONLY-UPLOAD.sh \
    scriptlets/RR-KPP-Bundle-Scan.sh scriptlets/RR-Upload-Bundle-Scan.sh \
    scriptlets/RR-KPP-Interface-Inspector.sh scriptlets/RR-KPP-Interface-Inspector-Upload.sh \
    scriptlets/KPP-Comprehensive-Diagnostic.sh scriptlets/KPP-Last-Open-Page-Check.sh \
    scriptlets/RR-KPP-Bytecode-Export.sh scriptlets/RR-JS-Smoke-Test.sh \
    scriptlets/RR-LIPC-Metadata-Check.sh scriptlets/RR-Upload-Diagnostic.sh \
    scriptlets/KindleBatchPrepareDiagnostics.sh scriptlets/RoyalRoadTools.sh \
    scriptlets/Kindle-Version-Report.sh bookmarklets/chapter-session-test.jsurl \
    tools/add-browser-bookmark.sh tools/remove-browser-bookmark.sh \
    files/koreader-screensavers-inverted/01_Rav_Zvi_Kushelevsky.png \
    files/koreader-screensavers-inverted/02_Rav_Osher_Arieli.png \
    files/koreader-screensavers-inverted/03_Chofetz_Chaim.jpg files/koreader-screensavers-inverted/SHA256SUMS; do
    case "$ITEM" in ""|/*|..|../*|*/..|*/../*|*[!A-Za-z0-9._/-]*) FAILED=$((FAILED + 1)); continue ;; esac
    remove_file "$PACKAGE_DIR/$ITEM"
  done
  rmdir "$PACKAGE_DIR/bookmarklets" "$PACKAGE_DIR/tools" "$PACKAGE_DIR/files/koreader-screensavers-inverted" 2>/dev/null || true

  # Only exact legacy images installed by this project.
  for NAME in 01_Rav_Zvi_Kushelevsky.png 02_Rav_Osher_Arieli.png 03_Chofetz_Chaim.jpg SHA256SUMS; do remove_file "/mnt/us/koreader-screensavers-inverted/$NAME"; done
  for NAME in 01_Rav_Zvi_Kushelevsky.png 02_Rav_Osher_Arieli.png; do remove_file "/mnt/us/screensavers/$NAME"; done
  rmdir /mnt/us/koreader-screensavers-inverted 2>/dev/null || true

  # Remove only the exact old JavaScript test bookmark; back up DB privately first.
  DB="/var/local/KPPBrowser.db"
  if [ -f "$DB" ] && command -v sqlite3 >/dev/null 2>&1; then
    TABLE_COUNT="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='bookmark';" 2>/dev/null)"
    if [ "$TABLE_COUNT" = "1" ]; then
      EXISTING="$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" 2>/dev/null)"
      case "$EXISTING" in
        0) ;;
        ''|*[!0-9]*) FAILED=$((FAILED + 1)) ;;
        *)
          BACKUP="$INTERNAL/.KPPBrowser-cleanup-$$.db"
          if sqlite3 -cmd '.timeout 5000' "$DB" ".backup '$BACKUP'" >/dev/null 2>&1 &&
            sqlite3 -cmd '.timeout 5000' "$DB" "DELETE FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" >/dev/null 2>&1 &&
            [ "$(sqlite3 -cmd '.timeout 5000' "$DB" "SELECT COUNT(*) FROM bookmark WHERE title='Royal Road Session Test' AND url LIKE 'javascript:%';" 2>/dev/null)" = "0" ]; then
            rm -f "$BACKUP"; CLEANED=$((CLEANED + 1))
          else FAILED=$((FAILED + 1)); fi
          ;;
      esac
    else FAILED=$((FAILED + 1)); fi
  fi
  say "Retired-artifact cleanup: $CLEANED old items removed; $FAILED could not be removed or verified."
  [ "$FAILED" -eq 0 ]
}

# Install-hook handoff: the regular updater calls this exact same cleanup code
# after package files have been installed, without restarting the KPM upgrade.
if [ "${1:-}" = "--cleanup-only" ]; then
  say "Running the post-install retired-artifact cleanup pass..."
  if cleanup_retired_files; then
    say "SUCCESS — retired artifacts are absent or removed."
    exit 0
  fi
  say "WARNING — some retired artifacts could not be removed or verified."
  exit 1
fi

say "============================================================"
say "KPM UPDATE ALL — starting"
say "Device time: $(date)"
say "Progress will appear here and be saved to $LOG."
if [ ! -x "$KPM" ]; then say "ERROR: KPM executable not found at $KPM"; exit 1; fi
say ""
say "STEP 1 OF 2 — Refreshing registered KPM repositories..."
if run_and_show "$KPM" update; then say "Repository refresh succeeded."
else RC=$?; say "ERROR — KPM repository refresh failed (exit code $RC). Package upgrades and cleanup skipped."; exit "$RC"; fi
say ""
say "STEP 2 OF 2 — Upgrading installed KPM packages..."
if run_and_show "$KPM" -y upgrade; then
  say "SUCCESS — KPM upgrade completed."
  say ""
  say "Checking and removing retired project artifacts..."
  if cleanup_retired_files; then say "SUCCESS — retired artifacts are absent or removed."; else say "WARNING — unresolved retired artifacts will be checked again next time."; fi
  say ""
  say "Regenerating the Kindle software version report..."
  if [ -x "$VERSION_REPORT" ]; then
    if run_and_show sh "$VERSION_REPORT"; then say "SUCCESS — Kindle-Version-Report.txt was regenerated and replaced."; else say "WARNING — version report refresh failed."; fi
  else say "WARNING — internal version-report helper is missing: $VERSION_REPORT"; fi
  say "Finished: $(date)"
  exit 0
else RC=$?; say "ERROR — KPM upgrade failed (exit code $RC). Cleanup was not run."; say "Finished: $(date)"; exit "$RC"; fi
