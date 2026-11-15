# Architecture and staged test plan

## Goal

Investigate the Kindle's own built-in browser session and, only where ordinary access works, eventually build one offline EPUB. Avoid manual chapter-by-chapter copying. This project is not yet a story downloader.

## Confirmed device facts

- Kindle: 10th generation; exact model variant not yet identified.
- Firmware last reported: 5.18.1.1.1.
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A separate Kindle curl request to Royal Road returned HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser.getLastOpenPage is readable and returned the current browser URL.
- com.lab126.kppbrowser.invokeAction exists as a write-only string property.
- The LIPC owner was identified as KPPMainApp, executable /app/bin/KPPMainAppV2.
- The accepted invokeAction string format remains unknown. No action payload has been sent.

## Completed investigation

The comprehensive LIPC/property diagnostic established that the running KPPMainApp process owns com.lab126.kppbrowser. Its service metadata included the read-only getLastOpenPage and getAllSettings properties, plus write-only invokeAction. The live getLastOpenPage check returned a URL.

The existing Hermes bundle was exported and disassembled once. Its focused analysis found internal functions/references including navigateToKPPBrowser, redirectToWebView, webViewURL and webViewURLRedirectActionId. These are internal code references, not proof of a public LIPC method, safe callable action, or page-text API. The bundle export and disassembly are complete and must not be repeated.

## Current tools

- **KPP-Native-Bridge-Export** — one manual, read-only export of the running KPP native executable and selected shared libraries mapped by KPPMainApp. It creates a private tar.gz archive in Kindle Documents for USB transfer. It collects no page URL, page text, cookies, account identifiers, process IDs or command lines. It does not upload binaries.
- **KPM-Update-All** — manually refreshes and upgrades KPM packages, then automatically runs the private cleanup helper and regenerates the version report.
- **KindleBatchPrepareFix** — manual repair/reinstall utility for the KOReader Kindle Batch Preparation plugin.

The prior comprehensive diagnostic, last-open-page test and Hermes bytecode exporter are retired. The current package removes their launcher source files and queues their installed launchers, reports, upload-link files, saved remote-delete metadata and cached package copies for cleanup.

## Native browser bridge inspection — current stage

1. Open the Kindle's built-in browser and leave it running.
2. Run **KPP-Native-Bridge-Export** once.
3. The launcher locates the running KPPMainApp process, copies /app/bin/KPPMainAppV2, and copies selected shared libraries mapped by that process. Selection is limited to app-bundled shared objects and system libraries with KPP/browser/WebView/WebKit/Chromium/Hermes/React/JSI/LIPC-related names. The archive has file-count and size caps.
4. The archive and manifest are stored in Documents. The manifest includes only each copied file's basename, role, size and SHA256; original paths, process IDs, memory maps and runtime values are excluded.
5. Copy KPP-Native-Bridge-Binaries.tar.gz to Windows over USB.
6. Run the bundled KPP-Native-Bridge-Inspector-Windows helper by dragging the archive onto Run-KPP-Native-Inspection.bat.
7. The helper parses ELF headers, static/dynamic symbol tables, and selected embedded ASCII/UTF-16LE strings. It filters to browser, WebView, JavaScript, LIPC and bridge markers. It does not execute the binaries or disassemble machine instructions.
8. The helper writes KPP-Native-Bridge-Findings.txt and attempts to upload only that filtered text report to https://pasters.io/?expires=1w. The raw archive, binaries, full strings and complete symbol tables remain local. A one-line success/failure does not create a paste. If report upload fails, the local report remains available.

The report omits page URLs, absolute paths, emails and cookie/session/credential/account markers. It includes ELF class/architecture, file hashes and matching marker names/excerpts. Anyone with the paste link can view the report; one-week expiry is requested, not guaranteed.

A native string or symbol is only a lead. It does not establish that an external interface is callable, that its argument format is known, or that calling it would be read-only. No guessed invokeAction payload may be sent.

## Safety and access limits

- Do not write LIPC properties or send events during static inspection.
- Do not send guessed values to com.lab126.kppbrowser.invokeAction.
- Do not inspect browser memory, cookies, authenticated storage, history, or page text using this native inspection workflow.
- Stop on access-denial, Cloudflare challenge, unexpected redirect, or incomplete page.
- Do not attempt CAPTCHA/proof-of-work bypasses or other access-control circumvention.

## Future stages after native findings

1. Review only the filtered native findings and determine whether a concrete browser bridge implementation path is identifiable.
2. Correlate any native bridge lead with reliable implementation evidence and documented read-only semantics.
3. Only if such an API is established, design a minimal live test for metadata that is explicitly safe to query. Do not infer or guess an invokeAction schema from a string name alone.
4. If there is no supported read-only page-content interface, stop the native LIPC path and evaluate ordinary browser-supported export options instead.
5. Only after reliable ordinary retrieval is established, design a local collector and validate EPUB completeness.

Keep the existing Apps Script receiver and EPUB builder separate and unchanged.

## Cleanup and versions

There is no separate cleanup launcher. The runner is private at /mnt/us/documents/.royalroadtools/cleanup.sh and is called automatically by KPM-Update-All after a successful package upgrade.

The installer merges the queue template into /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt, and the updater runs it after the KPM upgrade. Existing targets are re-queued even when a stale completion ledger entry exists. Successful actions leave the queue and are recorded in RoyalRoadTools-Cleanup-Completed.txt. Failed/unverifiable actions remain pending.

Remote paste deletion is attempted only when a private deletion URL was saved. A token remains locally while remote deletion is pending; local files are removed separately. If there is no saved token, the remote paste cannot be deleted through the cleanup helper and remains subject to the paste service's expiry policy.

Kindle-Version-Report.txt is regenerated automatically after successful Update All and successful plugin repair.
