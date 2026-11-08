#!/bin/sh
# Name: KindleBatchPrepareFix
# Author: E-Abenson / ChatGPT
# Finds the installed Kindle Batch Preparation plugin by its metadata,
# patches its Lua source, and re-enables it only after validation.

DOCS="/mnt/us/documents"
KO_ROOT="/mnt/us/koreader"
PLUGIN_ROOT="$KO_ROOT/plugins"
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
say "Searching plugin folders under: $PLUGIN_ROOT"
say "Log: $LOG"

if [ ! -d "$PLUGIN_ROOT" ]; then
  fail 1 "KOReader plugin directory does not exist: $PLUGIN_ROOT"
fi

# Locate by the plugin's own metadata, not by a hard-coded directory name.
FOUND_DIR=""
FOUND_COUNT=0
say "Plugin folders currently present:"
for candidate in "$PLUGIN_ROOT"/*; do
  [ -d "$candidate" ] || continue
  say "  $(basename "$candidate")"
  if [ -f "$candidate/main.lua" ] && [ -f "$candidate/_meta.lua" ] &&
     grep -Fq "Kindle Batch Preparation" "$candidate/_meta.lua"; then
    FOUND_DIR="$candidate"
    FOUND_COUNT=$((FOUND_COUNT + 1))
    say "Identified matching plugin metadata in: $candidate"
  fi
done

if [ "$FOUND_COUNT" -eq 0 ]; then
  fail 1 "No plugin folder with matching Kindle Batch Preparation _meta.lua, main.lua, and metadata was found."
fi
if [ "$FOUND_COUNT" -gt 1 ]; then
  fail 1 "Found $FOUND_COUNT matching plugin folders. Refusing to guess which one to replace."
fi

PLUGIN_DIR="$FOUND_DIR"
TARGET="$PLUGIN_DIR/main.lua"
RESTORE_DIR=""
BASE_NAME="$(basename "$PLUGIN_DIR")"

case "$BASE_NAME" in
  *.disabled)
    RESTORE_NAME="${BASE_NAME%.disabled}"
    case "$RESTORE_NAME" in
      *.koplugin) ;;
      *) RESTORE_NAME="$RESTORE_NAME.koplugin" ;;
    esac
    RESTORE_DIR="$PLUGIN_ROOT/$RESTORE_NAME"
    say "Plugin is disabled; it will be patched before being re-enabled."
    ;;
  *.koplugin)
    say "Plugin folder is already active."
    ;;
  *)
    fail 1 "Found the plugin, but its folder suffix is unexpected: $BASE_NAME"
    ;;
esac

if [ -n "$RESTORE_DIR" ] && [ -e "$RESTORE_DIR" ]; then
  fail 1 "Cannot safely re-enable plugin because the destination already exists: $RESTORE_DIR"
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

# Set the requested KOReader menu section, then validate the full payload.
say "Setting the plugin menu location to More Tools..."
if ! sed 's/sorting_hint = "tools"/sorting_hint = "more_tools"/' "$TMP" > "$STAGED"; then
  fail 3 "Could not set the More Tools menu location."
fi
if [ ! -s "$STAGED" ]; then
  fail 3 "Patched main.lua is empty."
fi
mv -f "$STAGED" "$TMP"

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

if [ -n "$RESTORE_DIR" ]; then
  say "Restoring plugin folder to: $RESTORE_DIR"
  if ! mv "$PLUGIN_DIR" "$RESTORE_DIR"; then
    fail 5 "The fixed main.lua is installed, but the disabled folder could not be renamed. It remains at $PLUGIN_DIR"
  fi
  PLUGIN_DIR="$RESTORE_DIR"
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
