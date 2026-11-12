# Royal Road Kindle Tools — KPM package

This package contains a **read-only static KPP browser interface inspector**, the one-time USB export helper, and the maintenance tools still in use. It is not a Royal Road story downloader or EPUB builder.

## Kindle library items

- **RR-KPP-Interface-Inspector** — scans a small set of installed KPP/browser application files for fixed interface markers and reports only file paths and marker names.
- **Automatic KPP research export** — the package installer runs the inspector, uploads only the sanitised text report to pasters.io with one-day expiry, and places its share link at the top of the inspector log. Separately, it copies an unmodified KPP Hermes bundle into the visible Documents folder for the one-time USB investigation. The binary is never uploaded.
- **RoyalRoadTools-Cleanup** — persistent cleanup for retired scripts, logs, temporary files, package-cache files, saved paste links, and the exact old bookmark. Completed items are removed from the queue; failed items stay queued.
- **Automatic version report** — replaces Kindle-Version-Report.txt after every package install/upgrade and after a successful plugin repair. There is no manual report launcher.
- **KPM-Update-All** — refreshes package repositories and upgrades installed packages.
- **KindleBatchPrepareFix** — on-demand repair/reinstall utility for the separate Kindle Batch Preparation KOReader plugin. Keep it; use only when that plugin needs repair.

## One-time Windows investigation

The GitHub release also includes `KPP-One-Time-Disassembler-Windows.zip`. After a KPM update exports `KPPMainApp.js.hbc` into Kindle Documents, copy that file over USB into the extracted Windows helper folder and double-click `Run-KPP-Disassembly.bat`.

The helper requires Python 3.8+ already installed and an internet connection for its first run. It downloads a pinned pure-Python hbctool source snapshot into its own folder. No pip packages, compiler, administrator rights, or system-wide installation are needed. The helper checks the file's HBC version is 84, disassembles locally and creates `KPP-Interface-Findings.txt` plus the full HASM output. Nothing from the Kindle is uploaded. Full steps are in `pc-tools/kpp-disassembler/README-FIRST.txt`.

## How cleanup works

The installer merges repository cleanup entries into `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt` and runs the cleanup automatically. Successful items disappear from the pending queue and are recorded in `RoyalRoadTools-Cleanup-Completed.txt`. Failed or unverifiable items remain queued. The cleanup runner and queue remain installed to support future releases.

## Current Kindle logs

- `/mnt/us/documents/RR-KPP-Interface-Inspector.log` — sanitised static interface inspection.
- `/mnt/us/documents/KPP-Bytecode-Export.txt` — status, HBC version, size and SHA256 of the USB copy.
- `/mnt/us/documents/RoyalRoadTools-Cleanup.log` — latest cleanup run.
- `/mnt/us/documents/KPM-Update-All.log` — latest KPM update.
- `/mnt/us/documents/Kindle-Version-Report.txt` — automatic version inventory.

## Safety and limits

The inspector does not run LIPC commands, read LIPC property values, browser URLs/settings/cookies/history/bookmarks/database rows, set properties, send events, navigate, refresh, execute JS or use the network. It writes fixed marker names and file paths only. The pasters.io upload is the sanitised text report only; anyone obtaining its one-day link can read it.

The binary bundle copy is read-only and local; it is not uploaded to a paste service or public repository. The Windows helper also keeps the disassembly local. A marker or disassembly call site does not prove that an external LIPC invocation is supported. Do not guess or send an `invokeAction` payload. Do not share broad full-system LIPC dumps, which may expose unrelated account or authentication data.
