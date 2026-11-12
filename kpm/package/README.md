# Royal Road Kindle Tools — KPM package

This package provides a small set of **manual Kindle launchers** plus one private cleanup helper. It is not a Royal Road story downloader or EPUB builder.

## Manual Kindle launchers

- **RR-KPP-Interface-Inspector** — manually scans selected KPP/browser/WebKit/Chromium/Juno files for fixed interface markers. It reports only file paths and marker names; raw strings are never printed. The inspector remains offline.
- **RR-KPP-Interface-Inspector-Upload** — optional manual upload of the sanitised inspector report to `pasters.io` with a one-day expiry. Run the inspector first. Anyone with the share link can read the report.
- **RR-KPP-Bytecode-Export** — manually saves a private, read-only copy of the Hermes bundle. It never uploads the binary bundle and does not execute or disassemble it.
- **Kindle-Version-Report** — manually refreshes `Kindle-Version-Report.txt` with device firmware, KPM and installed package versions, KOReader revision, plugin fingerprints, and local KPP export status/checksum.
- **KPM-Update-All** — manually refreshes package repositories and upgrades installed packages. After a successful upgrade, it automatically runs the private cleanup helper.
- **KindleBatchPrepareFix** — manually repairs/reinstalls the separate Kindle Batch Preparation KOReader plugin. It is not a background service.

The inspector, uploader, bytecode export, version report, and plugin repair do **not** run automatically during installation or update. Open each launcher only when you choose to use it.

## Automatic cleanup

There is no separate **RoyalRoadTools-Cleanup** Kindle launcher. The cleanup runner is stored privately at `/mnt/us/documents/.royalroadtools/cleanup.sh` and is run automatically by **KPM-Update-All** after a successful package upgrade.

The package installer only installs the hidden runner and merges new entries from the repository queue template into `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt`; it does not execute the cleanup. Successful actions are removed from the pending queue and recorded in `RoyalRoadTools-Cleanup-Completed.txt`. Failed or unverifiable actions remain queued for the next Update All run.

The cleaner processes only explicit queue entries for retired test scripts, logs, temporary files, package-cache files, saved paste links, and the exact old Royal Road Session Test bookmark. It does not recursively delete folders.

To add a future cleanup target, add one line to `kpm/package/scriptlets/RoyalRoadTools-Cleanup-Queue.txt`:

- `DOC|filename` — exact file in `/mnt/us/documents`
- `DOCGLOB|pattern` — matching files directly inside `/mnt/us/documents`
- `PKG|relative/path` — exact file under the installed KPM package cache
- `PKGDIR|relative/path` — remove a directory only if empty
- `REMOTE_DELETE|filename` — use a saved pasters.io deletion URL in `/mnt/us/documents`
- `BOOKMARK|Royal Road Session Test` — remove only the exact project test JavaScript bookmark

Use exact paths and narrow patterns. Never add broad wildcards for user documents, story files, EPUBs, KOReader books, the active inspector, KPM updater, version report, or plugin repair tool.

## Current Kindle logs and reports

- `/mnt/us/documents/RR-KPP-Interface-Inspector.log` — created when the manual inspector is run; an optional upload adds a one-day share link at the top.
- `/mnt/us/documents/KPP-Bytecode-Export.txt` — refreshed when the manual bytecode exporter is run.
- `/mnt/us/documents/RoyalRoadTools-Cleanup.log` — latest automatic cleanup run.
- `/mnt/us/documents/KPM-Update-All.log` — latest package update and cleanup result.
- `/mnt/us/documents/KindleBatchPrepareFix.log` — latest manual plugin repair result.
- `/mnt/us/documents/Kindle-Version-Report.txt` — refreshed by running the manual version-report launcher.

Each active script clears its own log or report at the start of a run, replacing the prior result.

## Safety and limits

The inspector is intentionally narrower than the previous LIPC dump. It does not run `lipc-probe` or `lipc-get-prop`, read LIPC property values, read the browser URL/settings, inspect cookies/history/bookmarks/database rows, send LIPC writes/events, navigate, refresh, or execute JavaScript. It scans only filenames matching KPP/browser/WebKit/Chromium/Juno patterns under selected application directories, limits the scan to 80 files and skips files over approximately 50 MB. It extracts strings locally but writes only fixed marker names and file paths to its report; raw strings are held in a private temporary file and removed on exit.

A marker only establishes that text is embedded in a file. It does not prove that a method is callable or reveal a supported `invokeAction` payload. Do not guess or send one. Do not share a full `lipc-probe -a -v` dump: broad LIPC output can include private account and authentication values.

The cleanup uses narrow, validated filenames and package-relative paths; it never recursively deletes folders. Remote paste deletion is attempted only through a saved, specifically named delete-link file and only for the supported pasters.io delete URL format. It removes only the exact old bookmark with the project-installed title and JavaScript URL scheme, after backing up and verifying the browser database. It does not reset browser history, cookies, unrelated bookmarks, KOReader books, EPUBs, or the KOReader plugin folder.
