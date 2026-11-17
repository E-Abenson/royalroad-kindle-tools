#!/bin/sh
DOCS="/mnt/us/documents"
if [ "$1" = "upgrade" ]; then exit 0; fi

for ITEM in RR-KPP-Interface-Inspector.sh RR-KPP-Interface-Inspector-Upload.sh RoyalRoadTools-Cleanup.sh \
  RoyalRoadTools-Version-Info.sh KPM-Update-All.sh KindleBatchPrepareFix.sh Inspect-USB-Screen.sh \
  RR-LIPC-READONLY-PROBE.sh RR-LIPC-READONLY-UPLOAD.sh; do
  rm -f "$DOCS/$ITEM"
done
for ITEM in Kindle-Version-Report.txt .RoyalRoadTools-installed-version.txt \
  RoyalRoadTools-Cleanup.log RR-KPP-Interface-Inspector.log \
  RR-LIPC-READONLY-PROBE.log RR-LIPC-READONLY-UPLOAD-URL.txt \
  KPP-Bytecode-Export.txt \
  .RR-KPP-Interface-Inspector-delete-url.txt \
  KPM-Update-All.log KindleBatchPrepareFix.log KindleBatchPrepare-main.lua.gz \
  USB-Screen-Inspection.tar.gz USB-Screen-Inspection.txt USB-Screen-Inspection-Paste.txt \
  .USB-Screen-Inspection-delete-url.txt; do
  rm -f "$DOCS/$ITEM"
done
rm -f "$DOCS/.royalroadtools/version-info.sh" \
  "$DOCS/.royalroadtools/bytecode-export.sh" \
  "$DOCS/.royalroadtools/inspector-upload.sh" \
  "$DOCS/.rr-kpp-research/KPPMainApp.js.hbc"
rm -rf "$DOCS/USB-Screen-Inspection"
rmdir "$DOCS/.royalroadtools" "$DOCS/.rr-kpp-research" 2>/dev/null || true
