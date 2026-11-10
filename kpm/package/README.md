# Royal Road Kindle Tools — KPM package

This package contains a read-only LIPC service inventory and the maintenance tools still in use. It is **not** a Royal Road story downloader or EPUB builder.

## Kindle library items

- **RR-LIPC-READONLY-PROBE** — lists the Kindle's registered LIPC services with lipc-probe -a -v and records a read-only snapshot of KPP-related processes. It does not set LIPC properties, send events, navigate, refresh, or run browser JavaScript.
- **RR-LIPC-READONLY-UPLOAD** — optionally uploads a sanitized copy of the probe log to pasters.io. Credential-bearing service sections and identity fields are omitted or redacted, and the current browser URL is hidden. The original log is not changed. It asks for typed confirmation when interactive input is available; otherwise opening this dedicated launcher starts the transfer. The paste is requested to expire after one week, and the paste and remote-delete links are saved locally with owner-only permissions.
- **RoyalRoadTools-Cleanup** — a persistent cleanup runner. It processes a queue of retired test scripts, logs, temporary files, package-cache files and the exact old Royal Road Session Test bookmark. Each item is removed from the pending queue only after deletion is verified. Failed items stay queued for the next run.
- **RoyalRoadTools-Cleanup-Queue.txt** — the queue template in the repository. Add future cleanup targets here as one TYPE|VALUE line. The installer merges new lines into the Kindle's queue without overwriting pending work or re-adding completed work.
- **RoyalRoadTools-Version-Info** — regenerates Kindle-Version-Report.txt with device firmware, KPM versions and installed package versions, KOReader revision, and the installed Kindle Batch Preparation plugin code fingerprint.
- **KPM-Update-All** — refreshes package repositories and upgrades installed packages. Its log is cleared at the start of each run.
- **KindleBatchPrepareFix** — an on-demand repair/reinstall utility for the separate Kindle Batch Preparation KOReader plugin. It is not a background service. Keep it; use it only if that plugin needs repair or reinstalling. Its log is cleared at the start of each run.

## How cleanup works

1. KPM installs the current cleanup runner and merges the repository queue template into /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt.
2. The package installer runs the cleaner automatically during installation or upgrade. You can also open RoyalRoadTools-Cleanup manually to retry failed items.
3. Successful items disappear from the pending queue and are written to RoyalRoadTools-Cleanup-Completed.txt. The installer checks that ledger before adding a template item, so completed tasks are not resurrected by later updates.
4. Failed or unverifiable items remain in the queue. This includes temporary remote-paste deletion when the remote service cannot confirm deletion, or bookmark cleanup when the database cannot be safely checked.
5. The cleanup runner itself and its queue/ledger remain installed so future releases can add more work.

To add a future cleanup target, add one line to the repository template:

- DOC|filename — exact file in /mnt/us/documents
- DOCGLOB|pattern — matching files directly inside /mnt/us/documents
- PKG|relative/path — exact file under the installed KPM package cache
- PKGDIR|relative/path — remove a directory only if empty
- REMOTE_DELETE|filename — use a saved pasters.io deletion URL in /mnt/us/documents
- BOOKMARK|Royal Road Session Test — remove only the exact project test JavaScript bookmark

Use exact paths and narrow patterns. Never add broad wildcards for user documents, story files, EPUBs, KOReader books, the active LIPC probe, KPM updater, or plugin repair tool.

## Current Kindle logs

- /mnt/us/documents/RR-LIPC-READONLY-PROBE.log — latest read-only LIPC inventory.
- /mnt/us/documents/RR-LIPC-READONLY-UPLOAD-URL.txt — latest uploaded diagnostic link, when one has been created.
- /mnt/us/documents/RR-LIPC-READONLY-UPLOAD-DELETE-URL.txt — private remote-delete link returned by pasters.io, when supplied.
- /mnt/us/documents/RoyalRoadTools-Cleanup.log — latest cleanup run and per-item results.
- /mnt/us/documents/KPM-Update-All.log — latest package update result.
- /mnt/us/documents/KindleBatchPrepareFix.log — latest KOReader plugin repair result.

The diagnostic and maintenance logs are cleared at the start of their respective runs. Retired test logs are removed by the cleanup queue.

## Safety and limits

The LIPC probe uses only lipc-probe -a -v, ps, and command-availability checks. The uploader is separate and manual: when interactive input is available it asks the user to type UPLOAD; when the Kindle launcher does not provide keyboard input, opening this dedicated uploader starts the transfer. It uploads only the sanitized diagnostic copy to pasters.io and requests one-week expiry. Credential-bearing services, identity values and the current browser URL are omitted or redacted; the raw local log is unchanged. The paste link is public to anyone who has it; review the sanitized output before opening the uploader. It does not write to LIPC, change the browser database, interact with the browser, or run app code. The cleanup uses narrow, validated filenames and package-relative paths; it never recursively deletes folders. It removes only the exact old bookmark with the project-installed title and JavaScript URL scheme, after backing up and verifying the browser database. It does not reset browser history, cookies, unrelated bookmarks, KOReader books, EPUBs, or the KOReader plugin folder.
