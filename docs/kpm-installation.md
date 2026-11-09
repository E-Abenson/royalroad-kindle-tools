# Kindle installation and maintenance

## Update and automatic cleanup

Open **KPM-Update-All** from the Kindle library. It refreshes the configured package repositories and upgrades installed KPM packages.

As part of package installation or upgrade, the package installer:
1. Installs the current read-only LIPC probe and maintenance launchers.
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

Use exact paths and narrow patterns. Never add broad wildcards for user documents, story files, EPUBs, KOReader books, the active LIPC probe, KPM updater, or plugin repair tool. The installer will merge new items on the next package update. It will not re-add any item listed in the completed ledger.

## Version report

Open **RoyalRoadTools-Version-Info**. It writes and displays /mnt/us/documents/Kindle-Version-Report.txt. The report includes Kindle model/firmware, KPM CLI/library and installed package versions, KOReader revision when available, the Kindle Batch Preparation plugin metadata version and main.lua checksum, the bundled repair-source checksum, and the KPP application executable fingerprint.

Open the report again after each KPM or KOReader update. It is refreshed on demand, not automatically.

## Kindle Batch Preparation repair

Keep **KindleBatchPrepareFix** installed. It is an on-demand repair/reinstall utility, not a background service. Use it only if the separate KOReader plugin disappears, fails to load, or needs the validated menu fix reapplied. It uses the locally bundled source so no manual file copying or network download is needed. Restart KOReader after a successful repair.

## Remaining LIPC investigation

Open **RR-LIPC-READONLY-PROBE** after updating. It runs lipc-probe -a -v to list registered services and saves a read-only KPP process snapshot to /mnt/us/documents/RR-LIPC-READONLY-PROBE.log. It does not write LIPC properties, send events, or interact with the browser.

## Active logs

- /mnt/us/documents/RR-LIPC-READONLY-PROBE.log
- /mnt/us/documents/RoyalRoadTools-Cleanup.log
- /mnt/us/documents/KPM-Update-All.log
- /mnt/us/documents/KindleBatchPrepareFix.log

Each active script clears its own log at the start of a run. Retired test logs are removed by the cleanup queue.
