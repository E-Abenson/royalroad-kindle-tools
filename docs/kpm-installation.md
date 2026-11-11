# Kindle installation and maintenance

## Update and automatic cleanup

Open **KPM-Update-All** from the Kindle library. It refreshes the configured package repositories and upgrades installed KPM packages.

As part of package installation or upgrade, the package installer:
1. Installs the read-only KPP interface inspector, an internal upload helper, a private bytecode-export helper, and the maintenance tools.
2. Merges new entries from the repository cleanup queue template into the existing Kindle queue.
3. Runs **RoyalRoadTools-Cleanup** automatically.
4. Runs the KPP inspector, saves a private local copy of the Hermes bundle, uploads only the sanitised text report to pasters.io with one-day expiry, and regenerates the software version report.

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

`/mnt/us/documents/Kindle-Version-Report.txt` is regenerated automatically after every KPM package installation/upgrade and after a successful Kindle Batch Preparation repair. It includes Kindle model/firmware, KPM CLI/library and installed package versions, KOReader revision when available, the Kindle Batch Preparation plugin metadata version and main.lua checksum, the bundled repair-source checksum, the KPP executable fingerprint, and the private Hermes-bundle export status and checksum. There is no separate manual version-report launcher.

## Kindle Batch Preparation repair

Keep **KindleBatchPrepareFix** installed. It is an on-demand repair/reinstall utility, not a background service. Use it only if the separate KOReader plugin disappears, fails to load, or needs the validated menu fix reapplied. It uses the locally bundled source so no manual file copying or network download is needed. Restart KOReader after a successful repair.

## Automatic KPP research

During every KPM package installation/upgrade, the installer automatically runs **RR-KPP-Interface-Inspector** and writes `/mnt/us/documents/RR-KPP-Interface-Inspector.log`. The inspector does not run LIPC commands, read browser URLs/settings/cookies/history/database rows, send LIPC writes/events, navigate, refresh, or execute JavaScript. It prints only file paths and fixed marker names, not raw strings.

The same installation automatically copies `/app/KPPMainApp/js/KPPMainApp.js.hbc` to the private directory `/mnt/us/documents/.rr-kpp-research/`. The original application file is never changed. The copied bytecode file is **not** uploaded to pasters.io or any public repository.

The installer automatically uploads only the sanitised inspector text report to `pasters.io`, requests one-day expiry, and places the returned share link at the very top of the inspector log. Anyone who obtains that link can read the report; it is not password protected. The actual compiled application bundle is kept private on the Kindle.

The existing manual LIPC dump and old smoke-test artifacts remain queued for cleanup. Do not share a full-system `lipc-probe -a -v` dump; unrelated services can expose private account and authentication values.

## Active logs

- /mnt/us/documents/RR-KPP-Interface-Inspector.log
- /mnt/us/documents/RoyalRoadTools-Cleanup.log
- /mnt/us/documents/KPM-Update-All.log
- /mnt/us/documents/KindleBatchPrepareFix.log

Each active script clears its own log at the start of a run. Retired test logs are removed by the cleanup queue.
