#!/bin/sh
# Name: Install-Rabbinic-Screensavers
# Build: 1.1
# Downloads two prepared grayscale portraits directly onto the Kindle.
# Run manually from the Kindle library. Does not run during KPM installation.
# Only the two named PNG files are created/replaced; all other files are untouched.

SCREENSAVERS_DIR="/mnt/us/screensavers"
DOCS="/mnt/us/documents"
LOG="$DOCS/Install-Rabbinic-Screensavers.log"
PINNED_REF="61e39709381cedb675d88b220abfb5d27164f865"
BRANCH_REF="rabbinic-screensavers-run"
RELATIVE_DIR="kindle-screensaver-generator/output"

RAV_ZVI_FILE="01_Rav_Zvi_Kushelevsky.png"
RAV_ZVI_SHA="b8b6fc05c12f1d272a624725b25a330116a3a5614d2c0052cf1d93b578c1920"

RAV_OSHER_FILE="02_Rav_Osher_Arieli.png"
RAV_OSHER_SHA="736f9554e2f5b743f50fb4fd675bce7b4f68fcfb2b15ec2aafdd324f8024b67d"

umask 022
mkdir -p "$DOCS" "$SCREENSAVERS_DIR" 2>/dev/null || {
  printf '%s\n' "FAILURE: Could not prepare Documents or the screensavers folder."
  exit 1
}
: > "$LOG" 2>/dev/null || true

say() {
  printf '%s\n' "$*"
  printf '%s\n' "$*" >> "$LOG" 2>/dev/null || true
}

if ! command -v sha256sum >/dev/null 2>&1; then
  say "FAILURE: sha256sum is unavailable; no image was installed."
  say "Log: $LOG"
  exit 1
fi

download_one() {
  FILENAME="$1"
  EXPECTED_SHA="$2"
  DEST="$SCREENSAVERS_DIR/$FILENAME"
  TEMP="$SCREENSAVERS_DIR/.$FILENAME.download.$$"

  if [ -f "$DEST" ]; then
    CURRENT_SHA="$(sha256sum "$DEST" 2>/dev/null | awk '{print $1}')"
    if [ "$CURRENT_SHA" = "$EXPECTED_SHA" ]; then
      say "Already installed and verified: $FILENAME"
      return 0
    fi
  fi

  for ROUTE in pinned branch github_raw_api; do
    case "$ROUTE" in
      pinned)
        URL="https://raw.githubusercontent.com/E-Abenson/royalroad-kindle-tools/$PINNED_REF/$RELATIVE_DIR/$FILENAME"
        ;;
      branch)
        URL="https://raw.githubusercontent.com/E-Abenson/royalroad-kindle-tools/$BRANCH_REF/$RELATIVE_DIR/$FILENAME"
        ;;
      github_raw_api)
        URL="https://api.github.com/repos/E-Abenson/royalroad-kindle-tools/contents/$RELATIVE_DIR/$FILENAME?ref=$PINNED_REF"
        ;;
    esac

    rm -f "$TEMP"
    say "Trying $ROUTE for $FILENAME ..."

    DOWNLOADED=0
    if command -v curl >/dev/null 2>&1; then
      if [ "$ROUTE" = "github_raw_api" ]; then
        if curl -fLsS -L --connect-timeout 25 --max-time 180 --retry 2 \
          -H "Accept: application/vnd.github.raw" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          -o "$TEMP" "$URL" 2>> "$LOG"; then
          DOWNLOADED=1
        else
          say "curl request failed for route $ROUTE."
        fi
      else
        if curl -fLsS -L --connect-timeout 25 --max-time 180 --retry 2 \
          -o "$TEMP" "$URL" 2>> "$LOG"; then
          DOWNLOADED=1
        else
          say "curl request failed for route $ROUTE."
        fi
      fi
    fi

    # Try wget too if curl's request failed, even if curl is installed.
    if [ "$DOWNLOADED" -eq 0 ] && command -v wget >/dev/null 2>&1; then
      rm -f "$TEMP"
      if [ "$ROUTE" = "github_raw_api" ]; then
        if wget -q -O "$TEMP" --timeout=45 --tries=2 \
          --header="Accept: application/vnd.github.raw" "$URL" 2>> "$LOG"; then
          DOWNLOADED=1
        else
          say "wget request failed for route $ROUTE."
        fi
      else
        if wget -q -O "$TEMP" --timeout=45 --tries=2 "$URL" 2>> "$LOG"; then
          DOWNLOADED=1
        else
          say "wget request failed for route $ROUTE."
        fi
      fi
    fi

    if [ "$DOWNLOADED" -eq 1 ] && [ -s "$TEMP" ]; then
      ACTUAL_SHA="$(sha256sum "$TEMP" 2>/dev/null | awk '{print $1}')"
      if [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ]; then
        chmod 644 "$TEMP" 2>/dev/null || true
        if mv -f "$TEMP" "$DEST"; then
          say "SUCCESS: Installed and verified $DEST"
          return 0
        fi
        say "Could not move verified file into $DEST."
      else
        say "Downloaded data failed SHA256 verification for $FILENAME."
        say "Expected: $EXPECTED_SHA"
        say "Received: $ACTUAL_SHA"
      fi
    elif [ "$DOWNLOADED" -eq 1 ]; then
      say "Download returned an empty file for $FILENAME."
    fi
    rm -f "$TEMP"
  done

  say "FAILURE: All download routes failed for $FILENAME."
  return 1
}

say "Rabbinic Kindle Screensavers — installer build 1.1"
say "Destination: $SCREENSAVERS_DIR"
say "Detailed log: $LOG"
say "Other files in the folder will not be changed."
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
say "The detailed error log is saved as Documents/Install-Rabbinic-Screensavers.log."
say "Run this launcher again when the Kindle has a working Wi-Fi connection."
exit 1
