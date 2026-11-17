# Royal Road Kindle Tools

An experimental KPM toolkit for investigating the jailbroken Kindle's built-in KPP browser. The eventual goal is an offline EPUB from pages the user can open normally; this project is not yet a story downloader.

## Confirmed device findings

- Kindle: 10th generation; exact Basic/Paperwhite variant not yet identified.
- Firmware last reported: 5.18.1.1.1.
- The built-in browser can open Royal Road chapters.
- A separate direct Kindle curl request to Royal Road returned HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser.getLastOpenPage is readable and returned the current browser URL.
- com.lab126.kppbrowser.invokeAction is write-only. Its accepted message format is unknown; no payload has been sent.
- The existing Hermes bytecode was already exported and disassembled. That analysis identified internal navigation/WebView references, but did not prove a supported page-text API or reveal a safe invokeAction message.

## Current Kindle launchers

- **KPP-Native-Bridge-Export** — the current single manual investigation launcher. It copies the running KPP executable and selected shared libraries mapped by KPPMainApp into a private USB-transfer archive. It collects no page URL, page text, cookie, account data, PID or command line, and does not upload any binary.
- **KPM-Update-All** — manual KPM repository refresh and package upgrade. After a successful upgrade, it automatically runs the hidden cleanup helper and refreshes the version report.
- **Inspect-USB-Screen** — one-run, read-only inventory of the stock USB display assets and screen dimensions; uploads its text report to Pasters.io for one week and keeps an archive of the image files locally without changing system files.
- **KindleBatchPrepareFix** — manual repair/reinstall tool for the KOReader Kindle Batch Preparation plugin.

The prior comprehensive diagnostic, getLastOpenPage check, and Hermes bytecode exporter are completed and retired. Their launchers, reports, temporary files, saved paste-link files and package-cache copies are queued for removal by the automatic cleanup.

## USB display inspection

The screen shown while the Kindle is connected to a computer is a separate system USB display, not the normal sleep screensaver. The Inspect-USB-Screen launcher records the stock assets' dimensions, permissions and checksums, then uploads the text report to Pasters.io with a one-week expiry. Paste the link printed by the Kindle into the ChatGPT conversation. The report is also saved as `USB-Screen-Inspection.txt`; the link is saved as `USB-Screen-Inspection-Paste.txt` in Documents. A separate `USB-Screen-Inspection.tar.gz` archive contains the actual image files and stays local because the Pasters upload is text-only. The diagnostic does not modify the system or the existing custom sleep screensavers.

## Native browser bridge investigation

This is the next stage after the already-completed URL check and Hermes disassembly.

1. Open the Kindle's built-in browser and leave it open.
2. Run **KPP-Native-Bridge-Export** once.
3. It creates KPP-Native-Bridge-Binaries.tar.gz in Kindle Documents. The archive contains unchanged copies of /app/bin/KPPMainAppV2 and selected shared libraries mapped by the running KPPMainApp process. KPP-Native-Bridge-Export.txt records file counts and the archive checksum.
4. Copy the archive to Windows over USB.
5. Extract KPP-Native-Bridge-Inspector-Windows.zip from the matching GitHub release into the same folder.
6. Drag KPP-Native-Bridge-Binaries.tar.gz onto Run-KPP-Native-Inspection.bat.

The Windows helper uses Python 3.8+ already installed. It needs no pip packages, compiler, administrator rights or system-wide installation. It performs offline ELF header, symbol-table and selected embedded-string inspection, then creates KPP-Native-Bridge-Findings.txt in the same folder as the archive.

**No Pasters.io or other upload is involved.** The helper makes no network connection and keeps the archive, binaries and findings report on your PC. Attach KPP-Native-Bridge-Findings.txt directly in the ChatGPT conversation.

The report excludes page URLs, absolute device paths, email addresses, cookies, session/authentication markers, account identifiers and runtime browser data. It includes ELF architecture/hash information and selected native browser/bridge markers. A string or symbol is a lead, not proof that an external interface is callable or that its arguments are known.

## Cleanup and versions

There is no separate cleanup launcher. The cleanup runner is private at /mnt/us/documents/.royalroadtools/cleanup.sh and runs automatically when **KPM-Update-All** completes a successful package upgrade.

The installer merges the package queue into /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt; it does not run the cleaner itself. Before each cleanup run, targets that still exist are re-queued even when an old completion ledger says they were removed. Successful actions are removed from the pending queue and recorded in RoyalRoadTools-Cleanup-Completed.txt; failed or unverifiable actions remain queued for the next run.

Remote Pasters deletion for old retired diagnostic pastes is attempted only when a saved private deletion URL is available. This is separate from the new native-inspection helper, which does not use Pasters.io.

Kindle-Version-Report.txt is regenerated automatically after a successful Update All and successful plugin repair.

## Safety and limits

The native export reads only the running KPP executable and selected mapped shared libraries. It does not read browser memory, cookies, history, current page text, page source or JavaScript state. It does not send LIPC writes, events or invokeAction messages, and it does not modify the KPP application. The archive and findings stay on the user's PC.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA/proof-of-work bypasses or other access-control circumvention. Full chapter collection and EPUB creation have not been implemented.
