# Royal Road Kindle Tools — KPM package

This package contains a **read-only static KPP browser interface inspector** and the maintenance tools still in use. It is not a Royal Road story downloader or EPUB builder.

## Kindle library items

- **RR-KPP-Interface-Inspector** — inspects a small set of installed KPP/browser application files for fixed interface markers such as `invokeAction`, JavaScript evaluation method names, navigation methods, WebView/WebKit/Chromium markers, and debugging symbols. It reports only file paths and the names of markers found. Raw strings are never printed to the report.
- **RoyalRoadTools-Cleanup** — a persistent cleanup runner. It processes a queue of retired test scripts, logs, temporary files, package-cache files, saved paste links, and the exact old Royal Road Session Test bookmark. Each item is removed from the pending queue only after deletion is verified. Failed items stay queued for retry.
- **RoyalRoadTools-Cleanup-Queue.txt** — the repository queue template. Add future cleanup targets here as one TYPE|VALUE line. The installer merges new lines into the Kindle's queue without overwriting pending work or re-adding completed work.
- **RoyalRoadTools-Version-Info** — regenerates Kindle-Version-Report.txt with device firmware, KPM versions and installed package versions, KOReader revision, and the installed Kindle Batch Preparation plugin code fingerprint.
- **KPM-Update-All** — refreshes package repositories and upgrades installed packages. Its log is cleared at the start of each run.
- **KindleBatchPrepareFix** — an on-demand repair/reinstall utility for the separate Kindle Batch Preparation KOReader plugin. It is not a background service. Keep it; use it only if that plugin needs repair or reinstalling. Its log is cleared at the start of each run.

## How cleanup works

1. KPM installs the current cleanup runner and merges the repository queue template into `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt`.
2. The package installer runs the cleaner automatically during installation or upgrade. You can also open **RoyalRoadTools-Cleanup** manually to retry failed items.
3. Successful items disappear from the pending queue and are written to `RoyalRoadTools-Cleanup-Completed.txt`. The installer checks that ledger before adding a template item, so completed tasks are not resurrected by later updates.
4. Failed or unverifiable items remain in the queue. This includes remote-paste deletion when the service cannot confirm deletion, or bookmark cleanup when the browser database cannot be safely checked.
5. The cleanup runner itself and its queue/ledger remain installed so future releases can add more work.

To add a future cleanup target, add one line to the repository template:

- `DOC|filename` — exact file in `/mnt/us/documents`
- `DOCGLOB|pattern` — matching files directly inside `/mnt/us/documents`
- `PKG|relative/path` — exact file under the installed KPM package cache
- `PKGDIR|relative/path` — remove a directory only if empty
- `REMOTE_DELETE|filename` — use a saved pasters.io deletion URL in `/mnt/us/documents`
- `BOOKMARK|Royal Road Session Test` — remove only the exact project test JavaScript bookmark

Use exact paths and narrow patterns. Never add broad wildcards for user documents, story files, EPUBs, KOReader books, the active inspector, KPM updater, or plugin repair tool.

## Current Kindle logs

- `/mnt/us/documents/RR-KPP-Interface-Inspector.log` — latest static interface inspection report.
- `/mnt/us/documents/RoyalRoadTools-Cleanup.log` — latest cleanup run and per-item results.
- `/mnt/us/documents/KPM-Update-All.log` — latest package update result.
- `/mnt/us/documents/KindleBatchPrepareFix.log` — latest KOReader plugin repair result.

The maintenance logs are cleared at the start of their respective runs. Retired test logs are removed by the cleanup queue.

## Safety and limits

The inspector is intentionally narrower than the previous LIPC dump. It does **not** run `lipc-probe` or `lipc-get-prop`, read LIPC property values, read the browser URL/settings, inspect cookies/history/bookmarks/database rows, send LIPC writes/events, navigate, refresh, or execute JavaScript. It scans only filenames matching KPP/browser/WebKit/Chromium/Juno patterns under selected application directories, limits the scan to 80 files and skips files over approximately 50 MB. It extracts strings locally but writes only fixed marker names and file paths to its report; raw strings are held in a private temporary file and removed on exit. It makes no network request and has no uploader.

A marker only establishes that text is embedded in a file. It does not prove that a method is callable or reveal a supported `invokeAction` payload. Do not guess or send one. Do not share a full `lipc-probe -a -v` dump: broad LIPC output can include private account and authentication values.

The cleanup uses narrow, validated filenames and package-relative paths; it never recursively deletes folders. Remote paste deletion is attempted only through a saved, specifically named delete-link file and only for the supported pasters.io delete URL format. It removes only the exact old bookmark with the project-installed title and JavaScript URL scheme, after backing up and verifying the browser database. It does not reset browser history, cookies, unrelated bookmarks, KOReader books, EPUBs, or the KOReader plugin folder.
