#!/bin/sh
DOCS="/mnt/us/documents"
if [ "$1" = "upgrade" ]; then exit 0; fi

for ITEM in RR-KPP-Interface-Inspector.sh RR-KPP-Interface-Inspector-Upload.sh RoyalRoadTools-Cleanup.sh \
  RoyalRoadTools-Version-Info.sh KPM-Update-All.sh KindleBatchPrepareFix.sh \
  RR-LIPC-READONLY-PROBE.sh RR-LIPC-READONLY-UPLOAD.sh; do
  rm -f "$DOCS/$ITEM"
done
for ITEM in Kindle-Version-Report.txt .RoyalRoadTools-installed-version.txt \
  RoyalRoadTools-Cleanup.log RR-KPP-Interface-Inspector.log \
  RR-LIPC-READONLY-PROBE.log RR-LIPC-READONLY-UPLOAD-URL.txt \
  .RR-KPP-Interface-Inspector-delete-url.txt \
  KPM-Update-All.log KindleBatchPrepareFix.log KindleBatchPrepare-main.lua.gz; do
  rm -f "$DOCS/$ITEM"
done
