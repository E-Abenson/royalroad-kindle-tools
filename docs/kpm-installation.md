# Kindle installation and maintenance

## Update All and automatic cleanup

Open **KPM-Update-All** from the Kindle library when you choose to refresh repositories and upgrade installed KPM packages.

After a successful package upgrade, **KPM-Update-All** automatically runs the cleanup queue and regenerates the Kindle version report. This is the intended maintenance flow.

The cleanup runner is stored privately at:

`/mnt/us/documents/.royalroadtools/cleanup.sh`

There is no separate **RoyalRoadTools-Cleanup** launcher. The package installer installs the private runner and merges the queue; it does not run cleanup itself. The updater invokes cleanup after the package upgrade succeeds.

The Kindle-side interface-inspector stage is retired. The package no longer installs its two launchers, and the cleanup queue removes any older copies of:

- `RR-KPP-Interface-Inspector.sh`
- `RR-KPP-Interface-Inspector-Upload.sh`
- `RR-KPP-Interface-Inspector.log`
- `.RR-KPP-Interface-Inspector-delete-url.txt`

The one-time **RR-KPP-Bytecode-Export** launcher and `KPPMainApp.js.hbc` are deliberately preserved because they are needed for the Windows disassembly test.

## Cleanup queue

The pending queue is `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt`. Successful actions are removed from that queue and recorded in `/mnt/us/documents/RoyalRoadTools-Cleanup-Completed.txt`. Failed or unverifiable actions remain queued for the next KPM-Update-All run.

The installer also checks whether each retired target still exists. If it does, it re-queues it even if an earlier completion-ledger entry exists. This prevents previously removed files from being silently left behind after an old installer recreates them.

The latest cleanup output is saved in `/mnt/us/documents/RoyalRoadTools-Cleanup.log`, and the combined update/cleanup output is saved in `/mnt/us/documents/KPM-Update-All.log`. The logs list each file as removed, already absent, or pending.

## Current tools

- **RR-KPP-Bytecode-Export** — one-time manual export of the unchanged Hermes bundle to `/mnt/us/documents/KPPMainApp.js.hbc`. Run it once, then copy that file to Windows over USB.
- **KPM-Update-All** — repository refresh, package upgrade, automatic cleanup and version-report refresh.
- **KindleBatchPrepareFix** — manual repair/reinstall tool for the KOReader Kindle Batch Preparation plugin.

The retired interface inspector and optional upload launcher are not installed by current package versions.

## One-time Windows disassembly

After running **RR-KPP-Bytecode-Export**, connect the Kindle to Windows over USB and copy `KPPMainApp.js.hbc` from Documents. Download `KPP-One-Time-Disassembler-Windows.zip` from the project release, extract it, put the HBC file beside `Run-KPP-Disassembly.bat`, and double-click the BAT file.

The helper uses Python 3.8+ already installed, downloads a pinned pure-Python Hermes disassembler on first run, and needs no pip packages, compiler, administrator rights, or system-wide installation. It creates a focused `KPP-Interface-Findings.txt` and a full local disassembly. Nothing is uploaded.

## Version report

`/mnt/us/documents/Kindle-Version-Report.txt` is regenerated after a successful KPM-Update-All run and after a successful Kindle Batch Preparation repair. The generator is stored privately; there is no separate version-report launcher. The report includes device, KPM, package, KOReader, plugin and KPP bundle version/checksum information.

## Active logs and reports

- `/mnt/us/documents/KPP-Bytecode-Export.txt`
- `/mnt/us/documents/RoyalRoadTools-Cleanup.log`
- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/KindleBatchPrepareFix.log`
- `/mnt/us/documents/Kindle-Version-Report.txt`

Old diagnostic scripts, logs and report files are removed by the cleanup queue. It does not delete KOReader books, EPUBs, story files, browser data, or the live KOReader plugin.
