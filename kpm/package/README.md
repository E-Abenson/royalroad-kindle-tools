# Royal Road Kindle Tools — KPM package

This package contains a small number of Kindle tools and a private cleanup helper. It is not a Royal Road story downloader or EPUB builder.

## Kindle launchers

- **KPP-Comprehensive-Diagnostic** — one-run manual, read-only snapshot of KPP/browser processes, filtered LIPC service/property names, service-owner PIDs, the readable current-page hostname (without path or query), and the installed KPP bundle fingerprint. It creates one report in Documents and never writes to LIPC or executes a browser action.
- **RR-KPP-Bytecode-Export** — one-time manual export of a verified Hermes bundle copy to the USB-visible Kindle Documents folder. Keep it until the Windows disassembly test is complete.
- **KPM-Update-All** — manually refreshes package repositories and upgrades installed packages. After a successful upgrade, it automatically runs the private cleanup helper and refreshes the version report.
- **KindleBatchPrepareFix** — manually repairs/reinstalls the separate Kindle Batch Preparation KOReader plugin.

The Kindle-side **RR-KPP-Interface-Inspector** and **RR-KPP-Interface-Inspector-Upload** are retired. The package no longer installs them, and the cleanup queue removes their old launchers and local report. They are not part of the next test.

## One-time Windows disassembly

Run **RR-KPP-Bytecode-Export** once to create `/mnt/us/documents/KPPMainApp.js.hbc`. Copy that file over USB to Windows. Download and extract `KPP-One-Time-Disassembler-Windows.zip` from the project release, put the file beside `Run-KPP-Disassembly.bat`, then double-click it. The helper uses Python 3.8+ already installed, downloads a pinned pure-Python hbctool source snapshot on first run, and needs no pip packages, compiler, or administrator rights. It creates a focused findings report and a full local disassembly; nothing is uploaded.

## Automatic cleanup

There is no separate **RoyalRoadTools-Cleanup** Kindle launcher. The cleanup runner is stored privately at `/mnt/us/documents/.royalroadtools/cleanup.sh` and is run automatically by **KPM-Update-All** after a successful package upgrade.

The package installer installs the hidden runner and merges new entries from the repository queue template into `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt`; it does not run cleanup itself. Before each cleanup run, still-existing targets from the template are re-queued even if an older completion ledger says they were already removed. Successful actions are removed from the pending queue and recorded in `RoyalRoadTools-Cleanup-Completed.txt`. Failed or unverifiable actions remain queued for the next Update All run.

The cleanup queue explicitly removes retired test scripts, logs, reports, temporary files, package-cache files, saved paste links, and the exact old Royal Road Session Test bookmark. It does not recursively delete folders or use broad wildcards against user files.

## Current Kindle logs and reports

- `/mnt/us/documents/KPP-Comprehensive-Diagnostic.txt` — created by the one-run manual read-only KPP/browser diagnostic.
- `/mnt/us/documents/KPP-Bytecode-Export.txt` — created by the one-time manual bytecode exporter.
- `/mnt/us/documents/RoyalRoadTools-Cleanup.log` — latest automatic cleanup run.
- `/mnt/us/documents/KPM-Update-All.log` — latest package update and cleanup result.
- `/mnt/us/documents/KindleBatchPrepareFix.log` — latest manual plugin repair result.
- `/mnt/us/documents/Kindle-Version-Report.txt` — regenerated automatically after Update All and successful plugin repair.

## Safety and limits

The comprehensive diagnostic runs `lipc-probe -a` without `-v`, so it collects property names/types but does not dump readable property values. It reads `getLastOpenPage` only when advertised as readable and reports the hostname only. It does not alter D-Bus policy, monitor messages, write LIPC properties, emit events, read cookies, or make network requests.

The one-time exporter reads only `/app/KPPMainApp/js/KPPMainApp.js.hbc`. It does not modify the original application, execute or disassemble the bundle, or upload the binary. The bundle is copied to your own computer by USB for local analysis.

The cleanup uses narrow, validated filenames and package-relative paths; it never recursively deletes folders. It does not remove KOReader books, EPUBs, story files, browser history, cookies, unrelated bookmarks, or the KOReader plugin folder.
