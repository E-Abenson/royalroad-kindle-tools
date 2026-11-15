# Royal Road Kindle Tools — KPM package

This package contains a small set of manual Kindle utilities and a private cleanup runner. It is not a Royal Road downloader or EPUB builder.

## Current Kindle launchers

- **KPP-Native-Bridge-Export** — one manual export of the running KPP executable and selected shared libraries mapped by KPPMainApp. It creates KPP-Native-Bridge-Binaries.tar.gz in Documents for USB transfer. It does not inspect page contents, read cookies, modify the app or upload binaries.
- **KPM-Update-All** — manually refreshes package repositories and upgrades installed packages. After a successful upgrade, it automatically runs the private cleanup helper and regenerates the version report.
- **KindleBatchPrepareFix** — manually repairs/reinstalls the separate Kindle Batch Preparation KOReader plugin.

The previous comprehensive diagnostic, last-open-page test and Hermes bytecode export are completed and retired. Their launchers, output files and package-cache copies are queued for removal by the automatic cleanup.

## Native browser bridge inspection

This is the next step after the already-completed Hermes disassembly and the successful getLastOpenPage URL test.

1. Open the Kindle's built-in browser and leave it open.
2. Launch **KPP-Native-Bridge-Export** once.
3. It creates KPP-Native-Bridge-Binaries.tar.gz in Kindle Documents. The archive contains unchanged copies of /app/bin/KPPMainAppV2 and selected shared libraries mapped by the running KPPMainApp process. It also writes KPP-Native-Bridge-Export.txt with counts and the archive checksum.
4. Copy the archive to Windows over USB.
5. Extract KPP-Native-Bridge-Inspector-Windows.zip from the matching GitHub release into the same folder.
6. Drag KPP-Native-Bridge-Binaries.tar.gz onto Run-KPP-Native-Inspection.bat.

The Windows helper uses Python 3.8+ already installed. It needs no pip packages, compiler, administrator rights or system-wide installation. It reads ELF headers, symbol tables and selected embedded strings, and writes KPP-Native-Bridge-Findings.txt next to the archive.

**This is fully offline.** The helper does not contact Pasters.io or any other service and does not upload the archive, binaries, findings or any other file. When it finishes, attach KPP-Native-Bridge-Findings.txt directly in the ChatGPT conversation.

The report excludes page URLs, absolute device paths, email addresses, cookies, session/authentication markers, account identifiers and runtime browser data. It reports ELF metadata and selected native browser/bridge markers. A marker string or symbol is a lead, not proof that an external interface is callable or that its arguments are known.

## Automatic cleanup

There is no separate cleanup launcher. The cleaner is stored privately at /mnt/us/documents/.royalroadtools/cleanup.sh and runs automatically when **KPM-Update-All** completes a successful package upgrade.

The installer merges the queue template into /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt; it does not execute cleanup itself. Before cleanup, existing retired targets are re-queued only if they actually exist, even when an older completion ledger says they were removed. Successful actions are removed from the pending queue and recorded in RoyalRoadTools-Cleanup-Completed.txt. Failed or unverifiable actions remain queued for the next Update All run.

Remote Pasters deletion is attempted only for old retired diagnostic pastes when a private delete URL was saved. The new native-inspection helper does not create pastes or delete URLs.

## Safety and limits

The export reads only the running KPP executable and selected mapped shared libraries. It does not read browser memory, cookies, history, current page text, page source or JavaScript state. It does not send LIPC writes, events or invokeAction messages. It does not alter the KPP application. The archive and findings report stay on the user's PC.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA/proof-of-work bypasses or other access-control circumvention. Full chapter collection and EPUB creation have not been implemented.
