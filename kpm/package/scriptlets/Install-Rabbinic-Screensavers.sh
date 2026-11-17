#!/bin/sh
# Name: Install-Rabbinic-Screensavers
# Build: 2.0
# Copies normal-grayscale portraits from KPM's local KOReader asset folder.
# Run manually from the Kindle library; no network download is performed.
# Only the two named PNG files are created/replaced; all other files are untouched.

SOURCE_DIR="/mnt/us/koreader-screensavers-inverted"
CHECKSUMS="$SOURCE_DIR/SHA256SUMS"
SCREENSAVERS_DIR="/mnt/us/screensavers"
DOCS="/mnt/us/documents"
LOG="$DOCS/Install-Rabbinic-Screensavers.log"

umask 022
if ! mkdir -p "$DOCS" "$SCREENSAVERS_DIR" 2>/dev/null; then
  printf '%s\n' "FAILURE: Could not prepare Documents or the screensavers folder."
  exit 1
fi
: > "$LOG" 2>/dev/null || true

say() {
  printf '%s\n' "$*"
  printf '%s\n' "$*" >> "$LOG" 2>/dev/null || true
}

if ! command -v sha256sum >/dev/null 2>&1; then
  say "FAILURE: sha256sum is unavailable; no image was copied."
  say "Log: $LOG"
  exit 1
fi

if [ ! -s "$CHECKSUMS" ]; then
  say "FAILURE: The KPM-installed KOReader image folder or SHA256SUMS is missing."
  say "Run KPM-Update-All first, then open this installer again."
  say "Expected source folder: $SOURCE_DIR"
  exit 1
fi

copy_one() {
  FILENAME="$1"
  SOURCE="$SOURCE_DIR/$FILENAME"
  DEST="$SCREENSAVERS_DIR/$FILENAME"
  TEMP="$SCREENSAVERS_DIR/.$FILENAME.copy.$$"

  if [ ! -s "$SOURCE" ]; then
    say "FAILURE: Local source image is missing or empty: $SOURCE"
    return 1
  fi

  EXPECTED_SHA="$(awk -v wanted="$FILENAME" '$2 == wanted { print $1; exit }' "$CHECKSUMS")"
  if [ -z "$EXPECTED_SHA" ]; then
    say "FAILURE: No SHA256 entry for $FILENAME in $CHECKSUMS"
    return 1
  fi

  SOURCE_SHA="$(sha256sum "$SOURCE" 2>/dev/null | awk '{print $1}')"
  if [ "$SOURCE_SHA" != "$EXPECTED_SHA" ]; then
    say "FAILURE: The KOReader source image did not match its package checksum: $FILENAME"
    say "Expected: $EXPECTED_SHA"
    say "Received: $SOURCE_SHA"
    return 1
  fi

  if [ -f "$DEST" ]; then
    DEST_SHA="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"
    if [ "$DEST_SHA" = "$EXPECTED_SHA" ]; then
      say "Already installed and verified: $DEST"
      return 0
    fi
  fi

  rm -f "$TEMP"
  if ! cp "$SOURCE" "$TEMP"; then
    rm -f "$TEMP"
    say "FAILURE: Could not copy $SOURCE to the staging file."
    return 1
  fi

  COPIED_SHA="$(sha256sum "$TEMP" 2>/dev/null | awk '{print $1}')"
  if [ "$COPIED_SHA" != "$EXPECTED_SHA" ]; then
    rm -f "$TEMP"
    say "FAILURE: The staged copy failed SHA256 verification: $FILENAME"
    say "Expected: $EXPECTED_SHA"
    say "Received: $COPIED_SHA"
    return 1
  fi

  chmod 644 "$TEMP" 2>/dev/null || true
  if ! mv -f "$TEMP" "$DEST"; then
    rm -f "$TEMP"
    say "FAILURE: Could not move the verified local copy into $DEST"
    return 1
  fi

  INSTALLED_SHA="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"
  if [ "$INSTALLED_SHA" != "$EXPECTED_SHA" ]; then
    say "FAILURE: Destination verification failed after copying: $DEST"
    say "Expected: $EXPECTED_SHA"
    say "Received: $INSTALLED_SHA"
    return 1
  fi

  say "SUCCESS: Copied and verified $DEST"
  return 0
}

say "Rabbinic Kindle Screensavers — installer build 2.0"
say "Source: $SOURCE_DIR"
say "Destination: $SCREENSAVERS_DIR"
say "Using the normal-grayscale images already installed by KPM."
say "No Wi-Fi or GitHub download is needed for this step."
say "Only the two named portraits will be changed; other images are untouched."
say ""

FAILURES=0
copy_one "01_Rav_Zvi_Kushelevsky.png" || FAILURES=$((FAILURES + 1))
copy_one "02_Rav_Osher_Arieli.png" || FAILURES=$((FAILURES + 1))

sync 2>/dev/null || true
say ""
if [ "$FAILURES" -eq 0 ]; then
  say "COMPLETE — both normal-grayscale screensavers are installed and SHA256-verified."
  say "Open the Custom Screensaver Scriptlet to use or rotate them."
  exit 0
fi

say "INCOMPLETE — $FAILURES image(s) could not be copied."
say "Detailed log: $LOG"
exit 1
