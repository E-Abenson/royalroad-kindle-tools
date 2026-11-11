# Kindle installation and maintenance

## Update and automatic cleanup

Open **KPM-Update-All** from the Kindle library. It refreshes the configured package repositories and upgrades installed KPM packages.

As part of package installation or upgrade, the package installer:
1. Installs the read-only KPP interface inspector, its separate optional pasters.io upload launcher, and the maintenance launchers.
2. Merges new entries from the repository cleanup queue template into the existing Kindle queue.
3. Runs **RoyalRoadTools-Cleanup** automatically.

The pending queue is /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt. Successful actions are removed from that queue and recorded in /mnt/us/documents/RoyalRoadTools-Cleanup-Completed.txt. Failed or unverifiable actions remain queued. The cleanup runner remains installed and can be opened manually from the Kindle library to retry them.

## Add future cleanup targets

Edit kpm/package/scriptlets/RoyalRoadTools-Cleanup-Queue.txt in the GitHub repository and add one line for each retired item:

- DOC|filename — exact file in /mnt/us/documents
- DOCGLOB|pattern — matching files directly in /mnt/us/documents, without subdirectory traversal
- PKG|relative/path — exact file in the installed KPM package cache
- PKGDIR|relative/path — remove a directory only if empty
- REMOTE_DELETE|filename — use a saved pasters.io deletion URL in /mnt/us/documents
- BOOKMARK|Royal Road Session Test — remove only the exact project test JavaScript bookmark

Use exact paths and narrow patterns. Never add broad wildcards for user documents, story files, EPUBs, KOReader books, the active interface inspector, KPM updater, or plugin repair tool. The installer will merge new items on the next package update. It will not re-add any item listed in the completed ledger.

## Version report

Open **RoyalRoadTools-Version-Info**. It writes and displays /mnt/us/documents/Kindle-Version-Report.txt. The report includes Kindle model/firmware, KPM CLI/library and installed package versions, KOReader revision when available, the Kindle Batch Preparation plugin metadata version and main.lua checksum, the bundled repair-source checksum, and the KPP application executable fingerprint.

Open the report again after each KPM or KOReader update. It is refreshed on demand, not automatically.

## Kindle Batch Preparation repair

Keep **KindleBatchPrepareFix** installed. It is an on-demand repair/reinstall utility, not a background service. Use it only if the separate KOReader plugin disappears, fails to load, or needs the validated menu fix reapplied. It uses the locally bundled source so no manual file copying or network download is needed. Restart KOReader after a successful repair.

## KPP interface inspector

Open **RR-KPP-Interface-Inspector**. It scans selected installed application files for fixed interface marker names and writes `/mnt/us/documents/RR-KPP-Interface-Inspector.log`.

The inspector does not run LIPC commands, read browser URLs/settings/cookies/history/database rows, send LIPC writes/events, navigate, refresh, execute JavaScript, or use the network. It prints only file paths and fixed marker names, not raw strings. Do not share a full-system `lipc-probe -a -v` dump; unrelated LIPC services can expose private account and authentication values.

To share the report, separately open **RR-KPP-Interface-Inspector-Upload**. This deliberately uploads only the inspector report to `pasters.io`, requests that the paste expire after one week, and writes the returned link at the top of the local inspector log. Anyone who obtains that link can read the report; it is not password protected. The private remote-delete URL is stored separately with restrictive local permissions, not in the report.

The previous broad LIPC probe, its old uploader, logs and saved paste links are queued for removal by the next package update. The new inspector upload action is separate and optional.

## Active logs

- /mnt/us/documents/RR-KPP-Interface-Inspector.log
- /mnt/us/documents/RoyalRoadTools-Cleanup.log
- /mnt/us/documents/KPM-Update-All.log
- /mnt/us/documents/KindleBatchPrepareFix.log

Each active script clears its own log at the start of a run. Retired test logs are removed by the cleanup queue.
