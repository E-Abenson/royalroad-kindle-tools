#!/bin/sh
DOCS="/mnt/us/documents"
if [ "$1" = "upgrade" ]; then exit 0; fi

# Remove only the ScreenLockPin code folder installed by this package.
# KOReader's central settings.reader.lua, including the PIN, is never deleted.
SCREENLOCKPIN_DIR="/mnt/us/koreader/plugins/screenlockpin.koplugin"
SCREENLOCKPIN_MARKER="$SCREENLOCKPIN_DIR/.royalroad-kpm-managed"
if [ -f "$SCREENLOCKPIN_MARKER" ] &&
   grep -Fqx "managed_by=royalroad-kindle-tools" "$SCREENLOCKPIN_MARKER"; then
  rm -rf "$SCREENLOCKPIN_DIR"
fi

for ITEM in RR-KPP-Interface-Inspector.sh RR-KPP-Interface-Inspector-Upload.sh RoyalRoadTools-Cleanup.sh \
  RoyalRoadTools-Version-Info.sh KPM-Update-All.sh KindleBatchPrepareFix.sh Inspect-USB-Screen.sh \
  KPP-Native-Bridge-Export.sh KPP-JavaScript-Bundle-Export.sh KPP-Page-Text-Capture.sh \
  RR-KPP-Bytecode-Export.sh Install-Rabbinic-Screensavers.sh \
  RR-LIPC-READONLY-PROBE.sh RR-LIPC-READONLY-UPLOAD.sh; do
  rm -f "$DOCS/$ITEM"
done
for ITEM in Kindle-Version-Report.txt .RoyalRoadTools-installed-version.txt \
  RoyalRoadTools-Cleanup.log RR-KPP-Interface-Inspector.log \
  RR-LIPC-READONLY-PROBE.log RR-LIPC-READONLY-UPLOAD-URL.txt \
  KPP-Bytecode-Export.txt KPP-JavaScript-Bundle-Export.txt KPPMainApp.js.hbc \
  .RR-KPP-Interface-Inspector-delete-url.txt \
  KPM-Update-All.log KindleBatchPrepareFix.log KindleBatchPrepare-main.lua.gz \
  USB-Screen-Inspection.tar.gz USB-Screen-Inspection.txt USB-Screen-Inspection-Paste.txt \
  .USB-Screen-Inspection-delete-url.txt; do
  rm -f "$DOCS/$ITEM"
done
rm -f "$DOCS/.royalroadtools/version-info.sh" \
  "$DOCS/.royalroadtools/bytecode-export.sh" \
  "$DOCS/.royalroadtools/inspector-upload.sh" \
  "$DOCS/.royalroadtools/kpp-page-capture" \
  "$DOCS/.rr-kpp-research/KPPMainApp.js.hbc"
rm -rf "$DOCS/USB-Screen-Inspection"
rmdir "$DOCS/.royalroadtools" "$DOCS/.rr-kpp-research" 2>/dev/null || true

# Remove only the exact legacy project-managed sleep images. The third-party
# Custom Screensaver extension and every other user's image/settings remain.
rm -f /mnt/us/koreader-screensavers-inverted/01_Rav_Zvi_Kushelevsky.png \
  /mnt/us/koreader-screensavers-inverted/02_Rav_Osher_Arieli.png \
  /mnt/us/koreader-screensavers-inverted/03_Chofetz_Chaim.jpg \
  /mnt/us/koreader-screensavers-inverted/SHA256SUMS \
  /mnt/us/screensavers/01_Rav_Zvi_Kushelevsky.png \
  /mnt/us/screensavers/02_Rav_Osher_Arieli.png
rmdir /mnt/us/koreader-screensavers-inverted 2>/dev/null || true
