#!/bin/sh
# Name: Install-Rabbinic-Screensavers
# Build: 1.0
# Downloads two prepared grayscale portraits directly onto the Kindle.
# Run manually from the Kindle library. Does not run during KPM installation.
# Only the two named PNG files are created/replaced; all other images are left alone.

SCREENSAVERS_DIR="$SCREENSAVERS_DIR"
BASE_URL="https://raw.githubusercontent.com/E-Abenson/royalroad-kindle-tools/61e39709381cedb675d88b220abfb5d27164f865/kindle-screensaver-generator/output"

RAV_ZVI_FILE="01_Rav_Zvi_Kushelevsky.png"
RAV_ZVI_SHA="b8b6fc05c12f1d272a624725b25a330116a3a5614d2c0052cf1d93b578c1920"

RAV_OSHER_FILE="02_Rav_Osher_Arieli.png"
RAV_OSHER_SHA="736f9554e2f5b743f50fb4fd675bce7b4f68fcfb2b15ec2aafdd324f8024b67d"

umask 022
say() { printf '%s\n' "$*"; }

if [ -z "$SCREENSAVERS_DIR" ]; then
  SCREENSAVERS_DIR="/mnt/us/screensavers"
fi

if ! mkdir -p "$SCREENSAVERS_DIR"; then
  say "FAILURE: Could not create $SCREENSAVERS_DIR"
  exit 1
fi

if ! command -v sha256sum >/dev/null 2>&1; then
  say "FAILURE: sha256sum is unavailable; no image was installed."
  exit 1
fi

download_one() {
  FILENAME="$1"
  EXPECTED_SHA="$2"
  URL="$BASE_URL/$FILENAME"
  DEST="$SCREENSAVERS_DIR/$FILENAME"
  TEMP="$SCREENSAVERS_DIR/.$FILENAME.download.$$"

  if [ -f "$DEST" ]; then
    CURRENT_SHA="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"
    if [ "$CURRENT_SHA" = "$EXPECTED_SHA" ]; then
      say "Already installed and verified: $FILENAME"
      return 0
    fi
  fi

  rm -f "$TEMP"
  say "Downloading $FILENAME ..."

  if command -v curl >/dev/null 2>&1; then
    if ! curl -fL --connect-timeout 25 --max-time 180 --retry 2 -o "$TEMP" "$URL"; then
      rm -f "$TEMP"
      say "FAILURE: Download failed for $FILENAME"
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -O "$TEMP" "$URL"; then
      rm -f "$TEMP"
      say "FAILURE: Download failed for $FILENAME"
      return 1
    fi
  else
    say "FAILURE: Neither curl nor wget is available on this Kindle."
    return 1
  fi

  if [ ! -s "$TEMP" ]; then
    rm -f "$TEMP"
    say "FAILURE: The downloaded file is empty: $FILENAME"
    return 1
  fi

  ACTUAL_SHA="$(sha256sum "$TEMP" 2>/dev/null | awk '{print $1}')"
  if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
    rm -f "$TEMP"
    say "FAILURE: SHA256 verification failed for $FILENAME; the old file was preserved."
    return 1
  fi

  chmod 644 "$TEMP" 2>/dev/null || true
  if ! mv -f "$TEMP" "$DEST"; then
    rm -f "$TEMP"
    say "FAILURE: Could not move verified image into $DEST"
    return 1
  fi

  say "SUCCESS: Installed and verified $DEST"
  return 0
}

say "Rabbinic Kindle Screensavers — manual installation"
say "Destination: $SCREENSAVERS_DIR"
say "Other files in that folder will not be changed."
say ""

FAILURES=0
download_one "$RAV_ZVI_FILE" "$RAV_ZVI_SHA" || FAILURES=$((FAILURES + 1))
download_one "$RAV_OSHER_FILE" "$RAV_OSHER_SHA" || FAILURES=$((FAILURES + 1))

sync 2>/dev/null || true
say ""
if [ "$FAILURES" -eq 0 ]; then
  say "COMPLETE — both screensavers are installed and SHA256-verified."
  say "Open the Custom Screensaver Scriptlet to use or rotate them."
  exit 0
fi

say "INCOMPLETE — $FAILURES image(s) could not be installed."
say "Run this launcher again when the Kindle has a working Wi-Fi connection."
exit 1
