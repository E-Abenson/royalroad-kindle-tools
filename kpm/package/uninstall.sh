#!/bin/sh
DOCS="/mnt/us/documents"
if [ "$1" = "upgrade" ]; then exit 0; fi
for ITEM in RR-KPP-Bundle-Scan.sh RR-Upload-Bundle-Scan.sh RoyalRoadTools-Cleanup.sh \
  RoyalRoadTools-Version-Info.sh KPM-Update-All.sh KindleBatchPrepareFix.sh; do
  rm -f "$DOCS/$ITEM"
done
for ITEM in Kindle-Version-Report.txt .RoyalRoadTools-installed-version.txt .RoyalRoadTools-Cleanup.done \
  RR-KPP-Bundle-Scan.log RR-KPP-Bundle-Scan-upload-url.txt RR-KPP-Bundle-Scan-delete-url.txt \
  RR-Upload-Bundle-Scan.log KPM-Update-All.log KindleBatchPrepareFix.log KindleBatchPrepare-main.lua.gz; do
  rm -f "$DOCS/$ITEM"
done
