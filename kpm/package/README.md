# Royal Road Kindle Tools — KPM package

This package now contains maintenance tools and one remaining, read-only KPP bundle scan. It is **not** a Royal Road story downloader or EPUB builder.

## Kindle library items

- **RR-KPP-Bundle-Scan** — reads the installed KPP JavaScript bundle and native executable as data, filters a narrow set of browser/action strings, and omits URL-like text. It does not execute app code or interact with the browser.
- **RR-Upload-Bundle-Scan** — manually uploads only the filtered scan log to a temporary pasters.io link. The link is readable by anyone who has it and expires after one week.
- **RoyalRoadTools-Version-Info** — refreshes Kindle-Version-Report.txt with device firmware, KPM CLI/library versions, installed KPM package versions, KOReader revision, and the Kindle Batch Preparation plugin metadata/fix marker.
- **KPM-Update-All** — refreshes package repositories and upgrades installed packages. Its log is cleared at the start of each run.
- **KindleBatchPrepareFix** — installs the validated Kindle Batch Preparation KOReader menu fix. The KOReader plugin itself is kept separate and is not removed by the test cleanup.
- **RoyalRoadTools-Cleanup** — a one-time cleanup launcher. It removes only the exact old Royal Road Session Test bookmark after making and verifying a safety backup, then removes completed test launchers/logs/links/backups. It preserves the current bundle scan and uploader until that test is complete.

## Recommended use

1. Run KPM-Update-All to install the latest package.
2. Open RoyalRoadTools-Cleanup once to remove completed test artifacts and the old bookmarklet.
3. Open RoyalRoadTools-Version-Info to generate/update Kindle-Version-Report.txt.
4. Run RR-KPP-Bundle-Scan, then RR-Upload-Bundle-Scan to share the scan results.

After future KPM or KOReader updates, open RoyalRoadTools-Version-Info again. The report is a snapshot generated at the time you open it.

## Files kept on the Kindle

- /mnt/us/documents/RR-KPP-Bundle-Scan.sh
- /mnt/us/documents/RR-Upload-Bundle-Scan.sh
- /mnt/us/documents/RoyalRoadTools-Version-Info.sh
- /mnt/us/documents/Kindle-Version-Report.txt
- /mnt/us/documents/KPM-Update-All.sh
- /mnt/us/documents/KindleBatchPrepareFix.sh

The cleanup launcher removes itself and writes a small .done marker after successful completion. If it cannot verify removal of the old browser bookmark, it stays available for another attempt.

## Version inventory

The version report reads:
- Kindle model/firmware from the Kindle's local system version files;
- KPM CLI/library version from kpm version;
- installed KPM package IDs/versions from KPM's SQLite database;
- KOReader's installed git-rev file;
- Kindle Batch Preparation _meta.lua version and its known crash-fix marker;
- the presence of the KPP browser application executable.

The report labels unavailable information rather than guessing.

## Safety and limits

The bundle scan reads files as data; it does not execute the Hermes bundle or native executable. It filters its output to a small set of likely browser/action strings and redacts URL-like content. No invokeAction request is sent. The uploader sends only the filtered scan log, not browser history, cookies, chapter text, or GitHub credentials. Full chapter collection and EPUB creation have not been implemented.
