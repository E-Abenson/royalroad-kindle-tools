#!/bin/sh
# Name: KindleBatchPrepareFix
# Reinstalls or repairs Kindle Batch Preparation in KOReader.
# Can rebuild the entire plugin folder if it has disappeared.

DOCS="/mnt/us/documents"
KO_ROOT="/mnt/us/koreader"
PLUGIN_ROOT="$KO_ROOT/plugins"
DEFAULT_PLUGIN_DIR="$PLUGIN_ROOT/kindle-batch-prepare-addon-fixed.koplugin"
LOCAL_SOURCE="$DOCS/KindleBatchPrepare-main.lua.gz"
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
  say "No unverified plugin was activated."
  say "Full log: $LOG"
  exit "$CODE"
}

say "============================================================"
say "KINDLE BATCH PREPARATION — REPAIR / REINSTALL"
say "Starting at $(date)"
say "KOReader root: $KO_ROOT"
say "Plugin directory: $PLUGIN_ROOT"
say "Log: $LOG"

if [ ! -d "$KO_ROOT" ]; then
  fail 1 "KOReader root not found: $KO_ROOT"
fi
if [ ! -d "$PLUGIN_ROOT" ]; then
  fail 1 "KOReader plugins directory not found: $PLUGIN_ROOT"
fi

# Find an existing copy by metadata first, and also recognise the known
# plugin folder name if its _meta.lua has been lost.
PLUGIN_DIR=""
FOUND_COUNT=0
RESTORE_DIR=""

for candidate in "$PLUGIN_ROOT"/*; do
  [ -d "$candidate" ] || continue
  MATCH=0
  if [ -f "$candidate/_meta.lua" ] && grep -Fq "Kindle Batch Preparation" "$candidate/_meta.lua"; then
    MATCH=1
  fi
  case "$(basename "$candidate")" in
    kindle-batch-prepare-addon-fixed.koplugin|kindle-batch-prepare-addon-fixed.disabled)
      MATCH=1
      ;;
  esac
  if [ "$MATCH" -eq 1 ]; then
    PLUGIN_DIR="$candidate"
    FOUND_COUNT=$((FOUND_COUNT + 1))
    say "Found existing plugin candidate: $PLUGIN_DIR"
  fi
done

if [ "$FOUND_COUNT" -gt 1 ]; then
  fail 1 "Found multiple plugin candidates. Refusing to choose between them."
fi

CREATED_DIR=0
if [ "$FOUND_COUNT" -eq 0 ]; then
  if [ -e "$DEFAULT_PLUGIN_DIR" ]; then
    fail 1 "The expected plugin path exists but is not a directory: $DEFAULT_PLUGIN_DIR"
  fi
  say "No existing plugin folder was found."
  say "Recreating the missing plugin folder: $DEFAULT_PLUGIN_DIR"
  if ! mkdir -p "$DEFAULT_PLUGIN_DIR"; then
    fail 1 "Could not create plugin directory: $DEFAULT_PLUGIN_DIR"
  fi
  PLUGIN_DIR="$DEFAULT_PLUGIN_DIR"
  CREATED_DIR=1
fi

BASE_NAME="$(basename "$PLUGIN_DIR")"
case "$BASE_NAME" in
  *.disabled)
    RESTORE_NAME="${BASE_NAME%.disabled}"
    case "$RESTORE_NAME" in
      *.koplugin) ;;
      *) RESTORE_NAME="$RESTORE_NAME.koplugin" ;;
    esac
    RESTORE_DIR="$PLUGIN_ROOT/$RESTORE_NAME"
    if [ -e "$RESTORE_DIR" ]; then
      fail 1 "Cannot re-enable plugin because destination already exists: $RESTORE_DIR"
    fi
    say "Plugin is disabled; it will be re-enabled only after the corrected files are installed."
    ;;
  *.koplugin)
    say "Plugin folder is already active or newly recreated."
    ;;
  *)
    fail 1 "Unexpected plugin folder suffix: $BASE_NAME"
    ;;
esac

TARGET="$PLUGIN_DIR/main.lua"
ARCHIVE="$PLUGIN_DIR/main.lua.download.gz.$$"
TMP="$PLUGIN_DIR/main.lua.download.$$"
STAGED="$PLUGIN_DIR/main.lua.new.$$"
META_STAGED="$PLUGIN_DIR/_meta.lua.new.$$"
trap 'rm -f "$ARCHIVE" "$TMP" "$STAGED" "$META_STAGED"' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

say "Using the locally bundled plugin source installed by KPM..."
if [ ! -s "$LOCAL_SOURCE" ]; then
  fail 2 "Local plugin source is missing: $LOCAL_SOURCE. Run KPM-Update-All to install the bundled source, then rerun this fixer."
fi
if ! cp "$LOCAL_SOURCE" "$ARCHIVE"; then
  fail 2 "Could not copy the local bundled plugin source."
fi
say "Local source copied; no network connection is required."

if [ ! -s "$ARCHIVE" ]; then
  fail 3 "Downloaded archive is empty."
fi
if ! command -v gzip >/dev/null 2>&1; then
  fail 3 "gzip is not available."
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

# KOReader's filemanager menu order has a 'more_tools' submenu under Tools.
say "Configuring the plugin entry for Tools → More tools..."
if ! sed 's/sorting_hint = "tools"/sorting_hint = "more_tools"/' "$TMP" > "$STAGED"; then
  fail 3 "Could not set the More tools menu location."
fi
if [ ! -s "$STAGED" ]; then
  fail 3 "Patched main.lua is empty."
fi
mv -f "$STAGED" "$TMP"

# Confirm the translation-function shadowing crash is fixed in the actual payload.
for marker in \
  "KOREADER_BATCH_PREPARE_MENU_FIX_V4" \
  "# KOREADER_BATCH_PREPARE_V2" \
  'local LEGACY_PATCH_MARKER = "# KOREADER_BATCH_PREPARE_V1"' \
  "legacy pause checkpoint" \
  "function PLUGIN:addToMainMenu(menu_items)" \
  "function PLUGIN:prepareAllBooks()" \
  "for choice_index, mb in ipairs(choices) do" \
  'self.pause_file = getattr(args, "pause_file", "") or ""' \
  'p_convert.add_argument("--pause-file", default="")' \
  '--pause-file", pause_path,' \
  "Tap anywhere to open controls" \
  "Pause this book at the next safe checkpoint?" \
  '_("Resume")' \
  '_("Abort batch")' \
  'sorting_hint = "more_tools"'; do
  if ! grep -Fq "$marker" "$TMP"; then
    fail 3 "Downloaded main.lua failed validation: missing marker: $marker"
  fi
done
if grep -Fq 'for _, mb in ipairs(choices) do' "$TMP"; then
  fail 3 "The faulty loop that caused the KOReader crash is still present."
fi
say "Corrected Lua source passed validation."

# Restore the plugin metadata file if it disappeared.
if [ ! -f "$PLUGIN_DIR/_meta.lua" ]; then
  say "Creating missing _meta.lua..."
  cat > "$META_STAGED" <<'META'
local _ = require("gettext")

return {
    fullname = _("Kindle Batch Preparation"),
    description = _("Prepare the Kindle's local KFX library for KOReader in a pausable and cancellable batch, with progress and a low-storage reserve."),
    version = "1.0",
}
META
  if [ ! -s "$META_STAGED" ] || ! grep -Fq 'fullname = _("Kindle Batch Preparation")' "$META_STAGED"; then
    fail 4 "Could not create valid plugin metadata."
  fi
  if ! mv -f "$META_STAGED" "$PLUGIN_DIR/_meta.lua"; then
    fail 4 "Could not install plugin metadata."
  fi
else
  say "Existing _meta.lua found; preserving it."
fi

STAMP="$(date '+%Y%m%d-%H%M%S')"
if [ -f "$TARGET" ]; then
  BACKUP="$PLUGIN_DIR/main.lua.before-repair-$STAMP.bak"
  say "Backing up existing main.lua to: $BACKUP"
  if ! cp -p "$TARGET" "$BACKUP"; then
    fail 4 "Could not back up the existing main.lua."
  fi
else
  say "No previous main.lua exists; installing a fresh copy."
  BACKUP="(none; plugin folder was missing its main.lua)"
fi

say "Installing corrected main.lua..."
if ! cp "$TMP" "$STAGED"; then
  fail 4 "Could not stage corrected main.lua."
fi
chmod 644 "$STAGED" 2>/dev/null || true
if ! mv -f "$STAGED" "$TARGET"; then
  fail 4 "Could not install corrected main.lua."
fi
rm -f "$ARCHIVE" "$TMP"

# Check both required plugin files exist before making a disabled folder active.
if [ ! -s "$PLUGIN_DIR/main.lua" ] || [ ! -s "$PLUGIN_DIR/_meta.lua" ]; then
  fail 4 "Post-install check failed: main.lua or _meta.lua is missing."
fi
say "Both main.lua and _meta.lua are present."

if [ -n "$RESTORE_DIR" ]; then
  say "Restoring plugin folder to: $RESTORE_DIR"
  if ! mv "$PLUGIN_DIR" "$RESTORE_DIR"; then
    fail 5 "Corrected files are installed, but the disabled folder could not be renamed."
  fi
  PLUGIN_DIR="$RESTORE_DIR"
  say "Plugin folder restored."
fi

say "SUCCESS: Kindle Batch Preparation has been installed at:"
say "$PLUGIN_DIR"
say "Crash fix verified: reserve-menu loop uses choice_index, not the gettext function name."
say "Menu location: Tools → More tools."
say "Controls: responsive Pause / Resume / Abort; existing progress helpers are upgraded in place."
say "Restart KOReader to load the plugin."
say "Full log saved to: $LOG"
exit 0
