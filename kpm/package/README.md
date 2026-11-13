# Royal Road Kindle Tools — KPM package

This package contains a small number of Kindle tools and a private cleanup helper. It is not a Royal Road story downloader or EPUB builder.

## Kindle launchers

- **KPP-Comprehensive-Diagnostic** — one-run manual read-only snapshot of KPP/browser processes, LIPC service names, individually probed property names/type/access metadata, owner process names, and KPP binary fingerprints. It then uploads only the sanitized technical report to pasters.io with one-week expiry requested. The paste URL and any delete URL are saved privately in Documents.
- **RR-KPP-Bytecode-Export** — one-time manual export of a verified Hermes bundle copy to the USB-visible Kindle Documents folder. Keep it until the Windows disassembly test is complete.
- **KPM-Update-All** — manually refreshes package repositories and upgrades installed packages. After a successful upgrade, it automatically runs the private cleanup helper and refreshes the version report.
- **KindleBatchPrepareFix** — manually repairs/reinstalls the separate Kindle Batch Preparation KOReader plugin.

## One-run comprehensive diagnostic

Open an ordinary page in the Kindle's built-in browser, then open **KPP-Comprehensive-Diagnostic** once. It writes `/mnt/us/documents/KPP-Comprehensive-Diagnostic.txt` and uploads that sanitized report to pasters.io.

The previous all-services `lipc-probe -a` command exited with status 1 on the device. This version uses `lipc-probe -l` for service-name discovery, then calls `lipc-probe SERVICE` individually for relevant KPP/browser services. It always includes `com.lab126.kppbrowser`, `com.lab126.browser` and `com.lab126.appmgrd`, even if listing fails.

The parser accepts the normal `access type property` format and the earlier project's pipe-delimited format. It emits only property names, type and access metadata. Raw output, values and command errors are suppressed. It performs read-only D-Bus service-owner lookups and records the owner process name, without PID or command-line data. It records relevant process names without PIDs or command-line arguments and fingerprints the KPP executable/Hermes bundle.

The paste excludes page URLs/hostnames, account identifiers, cookies, history, page text, process IDs, executable paths and command-line arguments. It includes device/software details, service/property metadata and bundle fingerprints. Anyone with the link can view the paste. The upload requests one-week expiry; this is a request to Pasters.io, not a guarantee. The paste URL and remote-delete URL are saved privately in Documents with restricted permissions. Only the sanitized report is sent; raw command output and temporary files are never uploaded. If curl or network access fails, the local report remains available for USB transfer.

Historical implementation references:
- [Earlier project per-service browser check](https://github.com/E-Abenson/royalroad-kindle-tools/commit/e1bd63af7589cd620f0b45862d3e27095225b22b)
- [Earlier project read-only LIPC service probe](https://github.com/E-Abenson/royalroad-kindle-tools/commit/336c4c1b36c27998f2f30983533572516c0bbc2)
- [K3Libre examples of lipc-probe -l and individual service queries](https://github.com/dpavlin/k3libre)
- [KindleModding LIPC reference](https://kindlemodding.org/kindle-apps-and-services/index.html)

The script does not use `lipc-probe -v` or repeat the failed `lipc-probe -a` command. It does not write LIPC properties, emit events, inject JavaScript, monitor D-Bus traffic, alter configuration, inspect cookies or make other network requests.

## One-time Windows disassembly

Run **RR-KPP-Bytecode-Export** once to create `/mnt/us/documents/KPPMainApp.js.hbc`. Copy that file over USB to Windows. Download and extract `KPP-One-Time-Disassembler-Windows.zip` from the project release, put the file beside `Run-KPP-Disassembly.bat`, then double-click it. The helper uses Python 3.8+ already installed, downloads a pinned pure-Python hbctool source snapshot on first run, and needs no pip packages, compiler, or administrator rights. It creates a focused findings report and a full local disassembly; nothing is uploaded.

## Automatic cleanup

There is no separate **RoyalRoadTools-Cleanup** Kindle launcher. The cleanup runner is stored privately at `/mnt/us/documents/.royalroadtools/cleanup.sh` and is run automatically by **KPM-Update-All** after a successful package upgrade.

The package installer merges the queue template into `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt`; it does not run cleanup itself. Before each cleanup run, still-existing retired targets from the template are re-queued even if an older completion ledger says they were removed. Successful actions are removed from the pending queue and recorded in `RoyalRoadTools-Cleanup-Completed.txt`. Failed or unverifiable actions remain queued for the next Update All run.

The active KPP-Comprehensive-Diagnostic launcher and report are intentionally not cleanup targets until this test has been run and reviewed. Older diagnostic launchers and logs remain queued. The Pasters.io URL and deletion URL are also retained until remote deletion is verified.

## Current Kindle logs and reports

- `/mnt/us/documents/KPP-Comprehensive-Diagnostic.txt` — one-run read-only diagnostic report.
- `/mnt/us/documents/KPP-Comprehensive-Diagnostic-upload-url.txt` — private paste link.
- `/mnt/us/documents/KPP-Comprehensive-Diagnostic-delete-url.txt` — private remote-delete link, when returned.
- `/mnt/us/documents/KPP-Bytecode-Export.txt` — one-time bytecode export metadata.
- `/mnt/us/documents/RoyalRoadTools-Cleanup.log` — latest automatic cleanup run.
- `/mnt/us/documents/KPM-Update-All.log` — latest package update and cleanup result.
- `/mnt/us/documents/Kindle-Version-Report.txt` — regenerated automatically after Update All and successful plugin repair.

## Safety and limits

The comprehensive diagnostic uses service-name discovery and targeted individual service probes. It records names and type/access metadata only, and never uses verbose output. It does not write LIPC properties, emit events, execute browser actions, inject JavaScript, alter D-Bus policy, read page content or inspect browser data. The only network request is the upload of the explicitly sanitized report to Pasters.io.

The one-time exporter reads only the Hermes bundle and does not modify or upload the original. The cleanup uses narrow, validated filenames and package-relative paths; it does not remove KOReader books, EPUBs, story files, browser history, cookies, unrelated bookmarks or the KOReader plugin folder.
