#!/bin/sh
# Name: KindleBatchPrepareFix
# Author: E-Abenson / ChatGPT
# Installs the corrected Kindle Batch Preparation plugin source.
# All output is displayed by sh_integration and saved in Documents.

DOCS="/mnt/us/documents"
KO_ROOT="/mnt/us/koreader"
ACTIVE_PLUGIN_DIR="$KO_ROOT/plugins/kindle-batch-prepare-addon-fixed.koplugin"
DISABLED_PLUGIN_DIR="$KO_ROOT/plugins/kindle-batch-prepare-addon-fixed.disabled"
PLUGIN_DIR="$ACTIVE_PLUGIN_DIR"
RESTORE_DISABLED=0
SOURCE_URL="https://raw.githubusercontent.com/E-Abenson/royalroad-kindle-tools/main/kpm/package/files/kindle_batch_prepare_main.lua.gz"
LOG="$DOCS/KindleBatchPrepareFix.log"

mkdir -p "$DOCS"
: > "$LOG"

say() {
  LINE="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  printf '%s\n' "$LINE" | tee -a "$LOG"
}

run_and_show() {
  STATUS_FILE="$DOCS/.KindleBatchPrepareFix-status.$$"
  rm -f "$STATUS_FILE"
  (
    "$@"
    COMMAND_STATUS=$?
    printf '%s\n' "$COMMAND_STATUS" > "$STATUS_FILE"
    exit "$COMMAND_STATUS"
  ) 2>&1 | tee -a "$LOG"

  if [ -f "$STATUS_FILE" ]; then
    COMMAND_STATUS="$(cat "$STATUS_FILE" 2>/dev/null)"
  else
    COMMAND_STATUS=1
    say "ERROR: The command ended without returning a status."
  fi
  rm -f "$STATUS_FILE"
  return "$COMMAND_STATUS"
}

fail() {
  CODE="$1"
  shift
  say "FAILED: $*"
  say "No active plugin replacement was completed."
  say "Full log: $LOG"
  exit "$CODE"
}

say "============================================================"
say "KINDLE BATCH PREPARATION — CRASH FIX"
say "Starting at $(date)"
say "Log: $LOG"

# If the plugin was renamed to .disabled to stop the crash, patch it
# while it remains disabled, then restore the normal folder name.
if [ ! -d "$ACTIVE_PLUGIN_DIR" ] && [ -d "$DISABLED_PLUGIN_DIR" ]; then
  PLUGIN_DIR="$DISABLED_PLUGIN_DIR"
  RESTORE_DISABLED=1
  say "Found the safely disabled plugin folder. It will remain disabled until the fixed file is installed."
fi
TARGET="$PLUGIN_DIR/main.lua"

if [ ! -d "$PLUGIN_DIR" ]; then
  fail 1 "Plugin folder not found. Expected either $ACTIVE_PLUGIN_DIR or $DISABLED_PLUGIN_DIR"
fi
if [ ! -f "$TARGET" ]; then
  fail 1 "Existing main.lua not found: $TARGET"
fi

ARCHIVE="$PLUGIN_DIR/main.lua.download.gz.$$"
TMP="$PLUGIN_DIR/main.lua.download.$$"
STAGED="$PLUGIN_DIR/main.lua.new.$$"
trap 'rm -f "$ARCHIVE" "$TMP" "$STAGED"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

say "Downloading corrected main.lua from the GitHub repository..."
if command -v curl >/dev/null 2>&1; then
  if ! run_and_show curl -fL --retry 2 --connect-timeout 15 --max-time 180 --silent --show-error -o "$ARCHIVE" "$SOURCE_URL"; then
    fail 2 "GitHub download failed (curl)."
  fi
elif command -v wget >/dev/null 2>&1; then
  if ! run_and_show wget -O "$ARCHIVE" "$SOURCE_URL"; then
    fail 2 "GitHub download failed (wget)."
  fi
else
  fail 2 "Neither curl nor wget is available on this Kindle."
fi

if [ ! -s "$ARCHIVE" ]; then
  fail 3 "Downloaded archive is empty."
fi
if ! command -v gzip >/dev/null 2>&1; then
  fail 3 "gzip is not available to unpack the verified source file."
fi
if ! gzip -t "$ARCHIVE"; then
  fail 3 "Downloaded source is not a valid gzip file."
fi
if ! gzip -dc "$ARCHIVE" > "$TMP"; then
  fail 3 "Could not decompress the downloaded main.lua."
fi
if [ ! -s "$TMP" ]; then
  fail 3 "Decompressed main.lua is empty."
fi

# Place the plugin entry in More Tools before installation.
say "Setting the plugin menu location to More Tools..."
if ! sed 's/sorting_hint = "tools"/sorting_hint = "more_tools"/' "$TMP" > "$STAGED"; then
  fail 3 "Could not set the More Tools menu location."
fi
if [ ! -s "$STAGED" ]; then
  fail 3 "Patched main.lua is empty."
fi
mv -f "$STAGED" "$TMP"

# Verify that this is the intended plugin and that the crash fix is present.
for marker in \
  "KOREADER_BATCH_PREPARE_MENU_FIX_V2" \
  "Kindle batch preparation: registering menu widget" \
  "function PLUGIN:addToMainMenu(menu_items)" \
  "function PLUGIN:prepareAllBooks()" \
  "for choice_index, mb in ipairs(choices) do" \
  'sorting_hint = "more_tools"'; do
  if ! grep -Fq "$marker" "$TMP"; then
    fail 3 "Downloaded main.lua failed validation: missing marker: $marker"
  fi
done

say "Download and crash-fix validation passed."
STAMP="$(date '+%Y%m%d-%H%M%S')"
BACKUP="$PLUGIN_DIR/main.lua.before-menu-fix-$STAMP.bak"
say "Creating backup: $BACKUP"
if ! cp -p "$TARGET" "$BACKUP"; then
  fail 4 "Could not back up the existing main.lua."
fi

say "Staging replacement..."
if ! cp "$TMP" "$STAGED"; then
  fail 4 "Could not stage the replacement. Original main.lua is unchanged."
fi
chmod 644 "$STAGED" 2>/dev/null || true
if ! mv -f "$STAGED" "$TARGET"; then
  fail 4 "Could not atomically replace main.lua. The backup is at $BACKUP"
fi

rm -f "$ARCHIVE" "$TMP"

if [ "$RESTORE_DISABLED" -eq 1 ]; then
  say "Restoring the plugin folder's normal .koplugin name..."
  if [ -e "$ACTIVE_PLUGIN_DIR" ]; then
    fail 5 "Cannot restore plugin folder because $ACTIVE_PLUGIN_DIR already exists. Fixed files remain in $DISABLED_PLUGIN_DIR"
  fi
  if ! mv "$DISABLED_PLUGIN_DIR" "$ACTIVE_PLUGIN_DIR"; then
    fail 5 "Could not restore the plugin folder name. Fixed files remain in $DISABLED_PLUGIN_DIR"
  fi
  PLUGIN_DIR="$ACTIVE_PLUGIN_DIR"
  TARGET="$PLUGIN_DIR/main.lua"
  BACKUP="$PLUGIN_DIR/$(basename "$BACKUP")"
  say "Plugin folder restored successfully."
fi

say "SUCCESS: Updated $TARGET"
say "Backup kept at: $BACKUP"
say "Crash fix installed: the reserve-menu loop no longer shadows KOReader's translation function."
say "The menu entry is configured for More Tools."
say "Please restart KOReader to load the corrected plugin."
say "Full log saved to: $LOG"
exit 0
