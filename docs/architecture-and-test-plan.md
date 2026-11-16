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

The next collection is intended to be one comprehensive read-only export, followed by one offline Windows analysis.

1. Open the Kindle's built-in browser and leave KPPMainApp running.
2. Run **KPP-Native-Bridge-Export** once.
3. The exporter copies the KPP main executable and every readable ELF object found in a file-backed executable mapping of that running process. It does not filter by library filename, so generic-named system or app libraries are not excluded.
4. Multiple mappings of the same underlying file are deduplicated by SHA256. The exporter tries the exact `/proc/<pid>/map_files/<range>` backing object before falling back to its pathname, which also helps when a mapped file has been renamed or unlinked.
5. The archive contains unchanged ELF files, a basename/size/SHA256 manifest, and a small README. It excludes original paths, process IDs, raw memory-map rows, process memory, URLs, page text, cookies, history, command lines and runtime property values.
6. The explicit caps are 128 ELF files, 120 MB per file and 400 MB total uncompressed. The export summary reports candidate, exported, duplicate and skipped counts.
7. Copy `KPP-Native-Bridge-Binaries.tar.gz` to Windows over USB.
8. Run the complete offline Windows helper by dragging the archive onto `Run-KPP-Native-Inspection.bat`.
9. The helper checks ELF headers, sections, dynamic/static symbols, imports, exports, relocations and filtered browser-related strings. It prioritizes the known KPP browser/navigation/LIPC markers, disassembles defined browser/bridge functions where symbols resolve to executable code, scans ARM32 sections in both ARM and Thumb modes, and correlates exact imports with definitions in other supplied ELF files.
10. The helper records the actual Capstone 5.x version used, safely skips Capstone data pseudo-instructions before querying operands, and writes `KPP-Native-Bridge-Findings.txt` locally. It does not connect to the internet, upload results or use a paste service.

The analysis is static only. It does not execute the binaries or contact the Kindle. It cannot inspect a library that the exporter could not read or that exceeded the explicit safety caps. If no dependency files appear, the export summary identifies whether mappings were absent, unreadable, non-ELF or over the caps.

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
