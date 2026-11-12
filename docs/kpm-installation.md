# Kindle installation and maintenance

## Manual tools and Update All

Open **KPM-Update-All** from the Kindle library when you choose to refresh repositories and upgrade installed KPM packages.

After a successful package upgrade, **KPM-Update-All** automatically runs the cleanup queue. This is the only maintenance script that runs automatically as part of the update flow. The cleanup runner is stored privately at:

`/mnt/us/documents/.royalroadtools/cleanup.sh`

There is no separate **RoyalRoadTools-Cleanup** launcher in the Kindle library. The package installer only installs the private cleanup runner and merges new cleanup entries; it does not run cleanup itself.

All other utilities are manual launchers:

- **RR-KPP-Interface-Inspector** — run the read-only static inspection when you choose.
- **RR-KPP-Interface-Inspector-Upload** — optional; run only after the inspector, when you explicitly want to upload its sanitised text report to pasters.io.
- **RR-KPP-Bytecode-Export** — manually refresh the private local copy of the Hermes bundle.
- **Kindle-Version-Report** — manually refresh `Kindle-Version-Report.txt`.
- **KindleBatchPrepareFix** — manually repair/reinstall the KOReader Kindle Batch Preparation plugin.

None of those tools runs automatically during package installation or KPM-Update-All.

## Cleanup queue

The pending queue is `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt`. Successful actions are removed from that queue and recorded in `/mnt/us/documents/RoyalRoadTools-Cleanup-Completed.txt`. Failed or unverifiable actions remain queued for the next KPM-Update-All run. The latest cleanup output is saved in `/mnt/us/documents/RoyalRoadTools-Cleanup.log`, and the combined update/cleanup output is saved in `/mnt/us/documents/KPM-Update-All.log`.

To add future cleanup targets, edit `kpm/package/scriptlets/RoyalRoadTools-Cleanup-Queue.txt` in the GitHub repository and add one line for each retired item:

- `DOC|filename` — exact file in `/mnt/us/documents`
- `DOCGLOB|pattern` — matching files directly in `/mnt/us/documents`, without subdirectory traversal
- `PKG|relative/path` — exact file in the installed KPM package cache
- `PKGDIR|relative/path` — remove a directory only if empty
- `REMOTE_DELETE|filename` — use a saved pasters.io deletion URL in `/mnt/us/documents`
- `BOOKMARK|Royal Road Session Test` — remove only the exact project test JavaScript bookmark

Use exact paths and narrow patterns. Never add broad wildcards for user documents, story files, EPUBs, KOReader books, the active inspector, KPM updater, version report, or plugin repair tool. The installer merges new items on the next package update and does not re-add items listed in the completed ledger.

## Manual version report

Run **Kindle-Version-Report** from the Kindle library whenever you want to refresh `/mnt/us/documents/Kindle-Version-Report.txt`. It includes Kindle model/firmware, KPM CLI/library and installed package versions, KOReader revision when available, the Kindle Batch Preparation plugin metadata version and main.lua checksum, the bundled repair-source checksum, the KPP executable fingerprint, and the private Hermes-bundle export status/checksum. It replaces the previous report. It is not run automatically during updates or plugin repairs.

## Kindle Batch Preparation repair

Keep **KindleBatchPrepareFix** installed. It is an on-demand repair/reinstall utility, not a background service. Use it only if the separate KOReader plugin disappears, fails to load, or needs the validated menu fix reapplied. It uses the locally bundled source so no manual file copying or network download is needed. Restart KOReader after a successful repair. Run the manual version-report launcher separately when you want to refresh the inventory.

## Manual KPP research tools

The inspector writes `/mnt/us/documents/RR-KPP-Interface-Inspector.log`. It does not run LIPC commands, read browser URLs/settings/cookies/history/database rows, send LIPC writes/events, navigate, refresh, or execute JavaScript. It prints only file paths and fixed marker names, not raw strings.

The bytecode exporter copies `/app/KPPMainApp/js/KPPMainApp.js.hbc` to the private directory `/mnt/us/documents/.rr-kpp-research/`. The original application file is never changed. The copied bytecode file is not uploaded to pasters.io or any public repository.

The optional uploader sends only the sanitised inspector text report to `pasters.io`, requests one-day expiry, and places the returned share link at the top of the inspector log. Anyone who obtains that link can read the report; it is not password protected. The actual compiled application bundle remains private on the Kindle. The exporter does not disassemble it.

The older full LIPC dump and old smoke-test artifacts remain queued for cleanup. Do not share a full-system `lipc-probe -a -v` dump; unrelated services can expose private account and authentication values.

## Active logs and reports

- `/mnt/us/documents/RR-KPP-Interface-Inspector.log`
- `/mnt/us/documents/KPP-Bytecode-Export.txt`
- `/mnt/us/documents/RoyalRoadTools-Cleanup.log`
- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/KindleBatchPrepareFix.log`
- `/mnt/us/documents/Kindle-Version-Report.txt`

Each manual utility replaces its own previous log/report when run. Cleanup and Update All logs show the latest automatic cleanup/update.
