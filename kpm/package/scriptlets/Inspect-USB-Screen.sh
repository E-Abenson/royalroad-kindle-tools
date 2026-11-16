#!/bin/sh
# Name: Inspect-USB-Screen
# Build: 1.0
# Read-only inventory of the stock USB-mode display assets.
# It does not remount the root filesystem or change any Kindle system files.

DOCS="/mnt/us/documents"
USB_DIR="/usr/share/blanket/usb"
WORK="$DOCS/.usb-screen-inspection.$$"
ARCHIVE="$DOCS/USB-Screen-Inspection.tar.gz"
TEMP="$ARCHIVE.new.$$"
REPORT="$WORK/USB-Screen-Inspection.txt"

cleanup() {
  rm -f "$TEMP"
  rm -rf "$WORK"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM

mkdir -p "$DOCS" "$WORK" || {
  printf '%s\n' "FAILURE: Could not create the inspection workspace in Documents."
  exit 1
}
: > "$REPORT"

say() {
  printf '%s\n' "$*" | tee -a "$REPORT"
}

first_line() {
  FILE="$1"
  if [ -r "$FILE" ]; then
    sed -n '1p' "$FILE" | tr -d '\r'
  else
    printf '%s' "Not found"
  fi
}

png_dimensions() {
  FILE="$1"
  if command -v od >/dev/null 2>&1; then
    set -- $(od -An -tu1 -j16 -N8 "$FILE" 2>/dev/null)
    if [ "$#" -eq 8 ]; then
      WIDTH=$(( $1 * 16777216 + $2 * 65536 + $3 * 256 + $4 ))
      HEIGHT=$(( $5 * 16777216 + $6 * 65536 + $7 * 256 + $8 ))
      printf '%s x %s' "$WIDTH" "$HEIGHT"
      return 0
    fi
  fi
  printf '%s' "unavailable"
}

say "KINDLE USB DISPLAY — READ-ONLY INSPECTION"
say "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
say ""
say "DEVICE"
say "Model: $(first_line /var/local/deviceType.txt)"
say "Firmware: $(first_line /etc/prettyversion.txt)"
say "Firmware identifier: $(first_line /etc/version.txt)"
say "Architecture: $(uname -m 2>/dev/null || echo unavailable)"
say ""
say "DISPLAY INFORMATION"
if [ -x /usr/sbin/eips ]; then
  say "eips -i:"
  /usr/sbin/eips -i 2>&1 | tee -a "$REPORT"
else
  say "eips: not found at /usr/sbin/eips"
fi
if [ -x /usr/bin/fbink ]; then
  say "fbink -i:"
  /usr/bin/fbink -i 2>&1 | tee -a "$REPORT"
elif command -v fbink >/dev/null 2>&1; then
  say "fbink -i:"
  fbink -i 2>&1 | tee -a "$REPORT"
else
  say "fbink: not found"
fi
say ""
say "USB DISPLAY ASSET DIRECTORY"
say "Expected path: $USB_DIR"
if [ -d "$USB_DIR" ]; then
  say "Directory: present"
  ls -ldn "$USB_DIR" 2>&1 | tee -a "$REPORT"
  say "Directory listing:"
  ls -lan "$USB_DIR" 2>&1 | tee -a "$REPORT"
  say ""
  say "Individual files (permissions, size, SHA256/checksum, PNG dimensions):"
  if command -v find >/dev/null 2>&1; then
    find "$USB_DIR" -type f -print | sort | while IFS= read -r ITEM; do
      [ -r "$ITEM" ] || {
        printf 'UNREADABLE: %s\n' "$ITEM" >> "$REPORT"
        continue
      }
      printf 'FILE: %s\n' "$ITEM" >> "$REPORT"
      ls -ln "$ITEM" 2>&1 >> "$REPORT"
      case "$ITEM" in
        *.png|*.PNG)
          printf 'PNG dimensions: %s\n' "$(png_dimensions "$ITEM")" >> "$REPORT"
          ;;
      esac
      if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$ITEM" 2>&1 >> "$REPORT"
      elif command -v cksum >/dev/null 2>&1; then
        cksum "$ITEM" 2>&1 >> "$REPORT"
      else
        printf 'Checksum utility: unavailable\n' >> "$REPORT"
      fi
      if command -v file >/dev/null 2>&1; then
        file "$ITEM" 2>&1 >> "$REPORT"
      fi
      printf '\n' >> "$REPORT"
    done
  else
    say "find is unavailable; recursive file inventory could not be produced."
  fi
  if cp -pR "$USB_DIR" "$WORK/" 2>/dev/null; then
    say "A copy of the complete USB asset folder is included in this report archive."
  else
    say "WARNING: The USB folder could not be copied in full. The report still contains the accessible listing."
  fi
else
  say "Directory: NOT FOUND"
  say "No system files were changed."
fi

say ""
say "SAFETY"
say "This inspection only reads system metadata and files under $USB_DIR."
say "It does not remount / read-write, replace images, change permissions, restart services, or alter the USB connection."
say "The archive contains the USB display asset folder and this report only."
say ""
say "NEXT STEP"
say "Copy USB-Screen-Inspection.tar.gz from Kindle Documents to the PC and attach it in the ChatGPT conversation."

if command -v tar >/dev/null 2>&1 && tar -czf "$TEMP" -C "$WORK" . 2>/dev/null &&
   tar -tzf "$TEMP" >/dev/null 2>&1 && mv -f "$TEMP" "$ARCHIVE"; then
  sync 2>/dev/null || true
  printf '%s\n' "" "SUCCESS: Created $ARCHIVE"
  if command -v sha256sum >/dev/null 2>&1; then
    printf 'Archive SHA256: %s\n' "$(sha256sum "$ARCHIVE" | awk '{print $1}')"
  fi
  exit 0
fi

FALLBACK="$DOCS/USB-Screen-Inspection"
rm -rf "$FALLBACK"
if cp -pR "$WORK" "$FALLBACK" 2>/dev/null; then
  printf '%s\n' "WARNING: Could not create a tar.gz archive. The inspection files were left in $FALLBACK instead."
  exit 0
fi
printf '%s\n' "FAILURE: Could not create the archive or copy the inspection folder."
exit 1
