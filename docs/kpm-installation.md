# Kindle installation and maintenance

## Manual tools and Update All

Open **KPM-Update-All** from the Kindle library when you choose to refresh repositories and upgrade installed KPM packages.

After a successful package upgrade, **KPM-Update-All** automatically runs the cleanup queue. This is the only maintenance script that runs automatically as part of the update flow. The cleanup runner is stored privately at:

`/mnt/us/documents/.royalroadtools/cleanup.sh`

There is no separate **RoyalRoadTools-Cleanup** launcher in the Kindle library. The package installer only installs the private cleanup runner and merges new cleanup entries; it does not run cleanup itself.

All other utilities are manual launchers:

- **RR-KPP-Interface-Inspector** — run the read-only static inspection when you choose.
- **RR-KPP-Interface-Inspector-Upload** — optional; run only after the inspector, when you explicitly want to upload its sanitised text report to pasters.io.
- **RR-KPP-Bytecode-Export** — one-time manual export of a read-only Hermes bundle copy to the USB-visible Kindle Documents folder.
- **Kindle-Version-Report.txt** — generated automatically after Update All and successful plugin repair; there is no manual report launcher.
- **KindleBatchPrepareFix** — manually repair/reinstall the KOReader Kindle Batch Preparation plugin.

The inspector, uploader, bytecode exporter, and plugin repair remain manual launchers. The version report is generated automatically after Update All and successful plugin repair.

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

## Automatic version report

`/mnt/us/documents/Kindle-Version-Report.txt` is regenerated after a successful **KPM-Update-All** run and after a successful Kindle Batch Preparation repair. The generator is stored privately at `/mnt/us/documents/.royalroadtools/version-info.sh`; there is no separate manual launcher. It replaces the previous report and includes device, KPM, package, KOReader, plugin, KPP executable, and exported bundle version/checksum information.

## Kindle Batch Preparation repair

Keep **KindleBatchPrepareFix** installed. It is an on-demand repair/reinstall utility, not a background service. Use it only if the separate KOReader plugin disappears, fails to load, or needs the validated menu fix reapplied. It uses the locally bundled source so no manual file copying or network download is needed. Restart KOReader after a successful repair. The successful repair automatically refreshes the version report.

## One-time KPP browser investigation — USB workflow

The inspector writes `/mnt/us/documents/RR-KPP-Interface-Inspector.log`. It does not run LIPC commands, read browser URLs/settings/cookies/history/database rows, send LIPC writes/events, navigate, refresh, or execute JavaScript. It prints only file paths and fixed marker names, not raw strings.

The bytecode exporter copies `/app/KPPMainApp/js/KPPMainApp.js.hbc` to `/mnt/us/documents/KPPMainApp.js.hbc`, verifies the SHA256, and writes the Hermes version, size, and checksum to `KPP-Bytecode-Export.txt`. The original application is never changed and the binary is never uploaded. After the visible copy is verified, the exporter removes the obsolete hidden duplicate from `.rr-kpp-research`.

For Windows disassembly, download `KPP-One-Time-Disassembler-Windows.zip` from the project release, copy the HBC file into the extracted folder, and double-click `Run-KPP-Disassembly.bat`. This uses Python 3.8+ already installed, downloads a pinned pure-Python hbctool source snapshot on first run, and needs no pip packages, compiler, administrator rights, or system-wide installation. The bundle and disassembly remain on your PC. See `pc-tools/kpp-disassembler/README-FIRST.txt`.

The optional uploader sends only the sanitised inspector text report to `pasters.io`, requests one-day expiry, and places the returned share link at the top of the inspector log. Anyone who obtains that link can read the report; it is not password protected. The compiled application bundle is copied only to your own computer by USB for local analysis; it is never uploaded. The exporter itself does not disassemble it.

The older full LIPC dump and old smoke-test artifacts remain queued for cleanup. Do not share a full-system `lipc-probe -a -v` dump; unrelated services can expose private account and authentication values.

## Active logs and reports

- `/mnt/us/documents/RR-KPP-Interface-Inspector.log`
- `/mnt/us/documents/KPP-Bytecode-Export.txt`
- `/mnt/us/documents/RoyalRoadTools-Cleanup.log`
- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/KindleBatchPrepareFix.log`
- `/mnt/us/documents/Kindle-Version-Report.txt`

Each manual utility replaces its own previous log/report when run. Cleanup and Update All logs show the latest automatic cleanup/update.
