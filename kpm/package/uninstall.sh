#!/bin/sh
DOCS="/mnt/us/documents"
if [ "$1" = "upgrade" ]; then exit 0; fi

for ITEM in RR-LIPC-READONLY-PROBE.sh RoyalRoadTools-Cleanup.sh \
  RoyalRoadTools-Version-Info.sh KPM-Update-All.sh KindleBatchPrepareFix.sh; do
  rm -f "$DOCS/$ITEM"
done
for ITEM in Kindle-Version-Report.txt .RoyalRoadTools-installed-version.txt \
  RoyalRoadTools-Cleanup-Queue.txt RoyalRoadTools-Cleanup-Completed.txt \
  RoyalRoadTools-Cleanup.log RR-LIPC-READONLY-PROBE.log \
  KPM-Update-All.log KindleBatchPrepareFix.log KindleBatchPrepare-main.lua.gz; do
  rm -f "$DOCS/$ITEM"
done
