#!/bin/sh
# One-off KPM repair and clean reinstall for Royal Road Kindle Tools.
# Writes all command output to Documents/KPM-Repair-Reinstall.log.
# Only the E-Abenson repository and royalroad-kindle-tools package are touched.

set -u

DOCS="/mnt/us/documents"
KPM="/var/local/kmc/bin/kpm"
REPO_ID="e-abenson"
REPO_URL="https://raw.githubusercontent.com/E-Abenson/royalroad-kindle-tools/main/kpm-repo/manifest.json"
PACKAGE_ID="royalroad-kindle-tools"
EXPECTED_INDEX_LINE="indexing artifact royalroad-kindle-tools (0.1.124)"
LOG="$DOCS/KPM-Repair-Reinstall.log"
BACKUP_DIR=""
PLUGIN_DIR="/mnt/us/koreader/plugins/screenlockpin.koplugin"

umask 077
mkdir -p "$DOCS" || exit 1
: > "$LOG"
exec >> "$LOG" 2>&1

say() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

show() {
  TITLE="$1"
  MESSAGE="$2"
  if command -v fbink >/dev/null 2>&1; then
    fbink -S 3 -m -M "$TITLE
$MESSAGE" >/dev/null 2>&1 || true
  elif command -v eips >/dev/null 2>&1; then
    eips 1 1 "$TITLE" >/dev/null 2>&1 || true
    eips 1 3 "$MESSAGE" >/dev/null 2>&1 || true
  fi
}

backup_file() {
  NAME="$1"
  if [ -f "$DOCS/$NAME" ]; then
    cp -p "$DOCS/$NAME" "$BACKUP_DIR/$NAME" || return 1
    say "Backed up existing Documents file: $NAME"
  fi
  return 0
}

restore_backups() {
  say "Restoring any pre-existing user files removed during a failed install..."
  for NAME in \
    KPPMainApp.js.hbc \
    Kindle-Version-Report.txt \
    .RoyalRoadTools-installed-version.txt \
    KPP-Native-Bridge-Export.sh \
    KPP-JavaScript-Bundle-Export.sh \
    KPM-Update-All.sh \
    Inspect-USB-Screen.sh \
    KindleBatchPrepareFix.sh \
    KindleBatchPrepare-main.lua.gz \
    KPP-JavaScript-Bundle-Export.txt \
    USB-Screen-Inspection.tar.gz \
    USB-Screen-Inspection.txt \
    USB-Screen-Inspection-Paste.txt \
    KPM-Update-All.log \
    KindleBatchPrepareFix.log; do
    if [ -f "$BACKUP_DIR/$NAME" ] && [ ! -e "$DOCS/$NAME" ]; then
      cp -p "$BACKUP_DIR/$NAME" "$DOCS/$NAME" && say "Restored: $NAME"
    fi
  done

  if [ -d "$BACKUP_DIR/screenlockpin.koplugin" ] && [ ! -d "$PLUGIN_DIR" ]; then
    mkdir -p "$(dirname "$PLUGIN_DIR")"
    cp -R "$BACKUP_DIR/screenlockpin.koplugin" "$PLUGIN_DIR" && \
      say "Restored the previous ScreenLockPin plugin code."
  fi
}

fail() {
  say "FAILURE: $*"
  restore_backups
  say "The full log is: $LOG"
  show "KPM REPAIR FAILED" "Open Documents/KPM-Repair-Reinstall.log"
  exit 1
}

say "============================================================"
say "KPM REPAIR — ROYAL ROAD KINDLE TOOLS"
say "Started: $(date)"
say "KPM executable: $KPM"
say "Target package: $PACKAGE_ID"
say "Expected published version: 0.1.124"
say "No other KPM package or registered repository will be changed."
say "============================================================"
show "KPM REPAIR STARTING" "Refreshing and reinstalling Royal Road Tools."

if [ ! -x "$KPM" ]; then
  fail "KPM was not found at $KPM."
fi

# Use a new backup directory on every run. A previous interrupted run or a
# stale mount point may occupy the old fixed name, so never reuse it.
BACKUP_DIR="$DOCS/.royalroad-kpm-repair-backup-$(date '+%Y%m%d-%H%M%S')-$"
# Keep user-created exports/reports safe if KPM has to roll back a failed
# first-time install. Successful upgrades leave these files in place.
if ! mkdir "$BACKUP_DIR"; then
  fail "Could not create a fresh safety-backup folder at $BACKUP_DIR."
fi
for NAME in \
  KPPMainApp.js.hbc \
  Kindle-Version-Report.txt \
  .RoyalRoadTools-installed-version.txt \
  KPP-Native-Bridge-Export.sh \
  KPP-JavaScript-Bundle-Export.sh \
  KPM-Update-All.sh \
  Inspect-USB-Screen.sh \
  KindleBatchPrepareFix.sh \
  KindleBatchPrepare-main.lua.gz \
  KPP-JavaScript-Bundle-Export.txt \
  USB-Screen-Inspection.tar.gz \
  USB-Screen-Inspection.txt \
  USB-Screen-Inspection-Paste.txt \
  KPM-Update-All.log \
  KindleBatchPrepareFix.log; do
  backup_file "$NAME" || fail "Could not back up $NAME."
done
if [ -d "$PLUGIN_DIR" ]; then
  cp -R "$PLUGIN_DIR" "$BACKUP_DIR/screenlockpin.koplugin" || \
    fail "Could not back up the existing ScreenLockPin plugin."
  say "Backed up the existing ScreenLockPin plugin code; KOReader settings are not touched."
fi

say ""
say "STEP 1 — Checking KPM version and registered repositories."
"$KPM" version || fail "Could not read the KPM version."
"$KPM" list-repo || fail "Could not list the registered KPM repositories."

if ! grep -Fq "$REPO_ID" "$LOG"; then
  say "The E-Abenson repository is not registered; adding it."
  "$KPM" add-repo "$REPO_URL" || fail "Could not add the E-Abenson repository."
else
  say "The E-Abenson repository is already registered."
fi

say ""
say "STEP 2 — Refreshing the KPM package index."
"$KPM" -d update || fail "KPM could not refresh the repository index."

if ! grep -Fq "$EXPECTED_INDEX_LINE" "$LOG"; then
  say "The expected Royal Road Tools artifact was not present in the refreshed index."
  say "Resetting only the E-Abenson repository registration, then refreshing once more."
  "$KPM" remove-repo "$REPO_ID" || fail "Could not reset the E-Abenson repository registration."
  "$KPM" add-repo "$REPO_URL" || fail "Could not re-add the E-Abenson repository."
  "$KPM" -d update || fail "KPM could not refresh the index after the repository reset."
fi

if ! grep -Fq "$EXPECTED_INDEX_LINE" "$LOG"; then
  fail "KPM still does not index artifact version 0.1.124. No package installation was attempted."
fi
say "Confirmed: the KPM index contains Royal Road Kindle Tools 0.1.124."

say ""
say "STEP 3 — Reinstalling Royal Road Kindle Tools through KPM."
say "KPM install is its built-in reinstall/upgrade operation. It replaces this package's old cached directory."
say "No KPM uninstall is being run; that avoids deleting user files and the existing KOReader settings."
show "INSTALLING KPM PACKAGE" "Royal Road Kindle Tools v0.1.124"

if ! "$KPM" -d -y install "$PACKAGE_ID"; then
  fail "KPM could not complete the package reinstall. See the detailed output above."
fi

say ""
say "STEP 4 — Verifying the installation."
MISSING=0
for NAME in \
  KPP-Native-Bridge-Export.sh \
  KPP-JavaScript-Bundle-Export.sh \
  KPM-Update-All.sh \
  Inspect-USB-Screen.sh \
  KindleBatchPrepareFix.sh; do
  if [ -x "$DOCS/$NAME" ]; then
    say "PRESENT: $NAME"
  else
    say "MISSING: $NAME"
    MISSING=1
  fi
done

if [ -f "$DOCS/.RoyalRoadTools-installed-version.txt" ]; then
  say "Installed package record:"
  cat "$DOCS/.RoyalRoadTools-installed-version.txt"
else
  say "MISSING: .RoyalRoadTools-installed-version.txt"
  MISSING=1
fi

if [ -f "$PLUGIN_DIR/.royalroad-kpm-managed" ]; then
  say "PRESENT: KPM-managed ScreenLockPin plugin marker."
else
  say "MISSING: KPM-managed ScreenLockPin plugin marker."
  MISSING=1
fi

if [ "$MISSING" -ne 0 ]; then
  fail "KPM returned success, but one or more expected installed files were missing."
fi

# The package installer should not remove these files. Restore only a missing
# original copy, never overwrite a new file created by the successful install.
restore_backups
rm -rf "$BACKUP_DIR"
say ""
say "SUCCESS — Royal Road Kindle Tools 0.1.124 is installed and verified."
say "The registered KPM repositories and all other KPM packages were left alone."
say "The full log is: $LOG"
say "Finished: $(date)"
sync 2>/dev/null || true
show "KPM REPAIR COMPLETE" "Installed v0.1.124. Log in Documents."
exit 0
