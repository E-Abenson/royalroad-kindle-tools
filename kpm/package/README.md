# Royal Road Kindle Tools — KPM package

This package contains one pending, read-only KPP bundle investigation and the maintenance tools still in use. It is **not** a Royal Road story downloader or EPUB builder.

## Kindle library items

- **RR-KPP-Bundle-Scan** — reads the installed KPP JavaScript bundle and native executable as data, filters a narrow set of browser/action strings, and omits URL-like content. It does not execute app code or interact with the browser.
- **RR-Upload-Bundle-Scan** — manually uploads only the filtered scan log to a temporary pasters.io link. Anyone with the link can read it; it expires after one week.
- **RoyalRoadTools-Version-Info** — regenerates `Kindle-Version-Report.txt` with device firmware, KPM versions and installed package versions, KOReader revision, and the installed Kindle Batch Preparation plugin code fingerprint.
- **KPM-Update-All** — refreshes package repositories and upgrades installed packages. Its log is cleared at the start of each run.
- **KindleBatchPrepareFix** — an on-demand repair/reinstall utility for the separate Kindle Batch Preparation KOReader plugin. It is not a background service. Keep it; use it only if that plugin needs repair or reinstalling. Its log is cleared at the start of each run.
- **RoyalRoadTools-Cleanup** — a one-time cleanup launcher that removes completed tests and the exact old Royal Road Session Test bookmark while preserving the current scan and maintenance tools.

## Recommended first run after this release

1. Run **KPM-Update-All**.
2. Open **RoyalRoadTools-Cleanup** once. It removes old smoke/LIPC test launchers, the old bookmarklet and helper scripts, their logs and links, and the exact old browser bookmark. It also tries to delete the old temporary paste if the saved deletion URL is present.
3. Open **RoyalRoadTools-Version-Info**. It creates or refreshes `/mnt/us/documents/Kindle-Version-Report.txt`.
4. Open that text file from the Kindle library or KOReader to read the version inventory.
5. The unfinished **RR-KPP-Bundle-Scan** remains available for the next browser investigation.

After a future KPM or KOReader update, open **RoyalRoadTools-Version-Info** again. The report is a snapshot, not an automatic background monitor.

## Logs kept

- `/mnt/us/documents/KPM-Update-All.log` — latest package update result.
- `/mnt/us/documents/KindleBatchPrepareFix.log` — latest KOReader plugin repair result.
- `/mnt/us/documents/RR-KPP-Bundle-Scan.log` — the pending KPP bundle investigation.
- `/mnt/us/documents/RR-Upload-Bundle-Scan.log` — latest scan-upload attempt.

These logs are cleared at the start of their respective runs. Logs for retired test launchers and bookmark helpers are removed by the cleanup launcher.

## Safety and limits

The cleanup removes only the old bookmark with the exact project-installed title and JavaScript URL scheme, after backing up and verifying the browser database. It does not reset browser history, cookies, or unrelated bookmarks. The KOReader plugin folder itself is preserved. The KPP bundle scan reads files as data; it does not execute the Hermes bundle or send `invokeAction`. The uploader transmits only the filtered scan log, not browser history, cookies, chapter text, or GitHub credentials.
