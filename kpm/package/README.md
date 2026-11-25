# Royal Road Kindle Tools — KPM package

This package installs manual Kindle launchers and one private cleanup helper. It is not a Royal Road story downloader or EPUB builder.

## Manual Kindle launchers

- **KPP-Native-Bridge-Export** — Build 4.0 comprehensive native export. It copies the KPP executable, ELF objects from all readable file-backed process mappings (including read-only mappings), shared-library candidates from Kindle/app library roots, and mapping/linker metadata. It creates a folder for USB transfer and records skipped files. It does not export process memory, browser databases, page contents, cookies, or history.
- **KPP-JavaScript-Bundle-Export** — copies the KPP Hermes JavaScript bundle to Documents in one copy operation. It displays large, centered progress stages using FBInk when available. It does not hash, parse, disassemble, execute, or modify the original application bundle.
- **Inspect-USB-Screen** — read-only inspection of the stock USB-connection display. This is separate from the device sleep screen.
- **KPM-Update-All** — refreshes registered repositories and upgrades installed KPM packages. After a successful package upgrade it runs cleanup and regenerates the version report.
- **KindleBatchPrepareFix** — manually repairs/reinstalls the separate Kindle Batch Preparation KOReader plugin.

Installation does not run an investigation, export, upload, cleanup, or plugin repair.

## Comprehensive native browser export

Run **KPP-Native-Bridge-Export** from the Kindle library before opening the built-in browser. The launcher starts a background watcher and returns to the library. Open the browser and leave it running; the watcher then copies the running KPP executable, every readable ELF object from file-backed process mappings regardless of mapping permissions, and shared-library candidates discovered under the standard Kindle/app library roots.

The export is a **KPP-Native-Bridge-FULL-...** folder in Documents. It contains the original file hierarchy under files/, manifest.tsv, skipped.tsv, metadata/process-maps.txt, linker configuration where available, and a README. It records unreadable files and safety-limit omissions rather than silently presenting a partial export as complete.

The Kindle performs file discovery, a four-byte ELF signature check, size accounting, and copies only. It does not perform ELF parsing, dependency analysis, symbol extraction, disassembly, checksums, archive compression, or sync. All substantive inspection happens on the computer after transfer. Connect USB, right-click the entire export folder in Windows, choose **Compress to ZIP**, and upload that ZIP for offline analysis. No second native export is needed unless the report explicitly identifies missing files.
## JavaScript bundle export

Run **KPP-JavaScript-Bundle-Export** from the Kindle library. It copies /app/KPPMainApp/js/KPPMainApp.js.hbc to /mnt/us/documents/KPPMainApp.js.hbc with one cp operation, using a temporary destination so an interrupted copy does not replace a previous complete copy. It writes KPP-JavaScript-Bundle-Export.txt.

The exporter displays its stages in large centered text through FBInk (font scale 3) when the FBInk command-line utility is available. It does not clear the full screen, calculate checksums, parse the Hermes header, re-read the copied file, or run sync. The original application bundle is only read, never modified or executed.

Connect the Kindle to a computer over USB and attach KPPMainApp.js.hbc directly in the ChatGPT conversation. Detailed verification and analysis happen after the file is uploaded; no Windows helper or local Python package is needed.

## Automatic cleanup

There is no separate RoyalRoadTools-Cleanup launcher. The cleanup runner lives privately at /mnt/us/documents/.royalroadtools/cleanup.sh and is called by KPM-Update-All only after a successful KPM package upgrade.

The installer merges explicit cleanup entries into /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt. Successful actions are removed from the pending queue and recorded in RoyalRoadTools-Cleanup-Completed.txt; failed or unverifiable actions remain queued.

The queue removes the old bytecode-export launcher/report and the exact legacy Rabbinic screensaver assets. It does not remove the new Hermes bundle copy, unrelated screen images, the third-party Custom Screensaver extension, its settings, books, EPUBs, or browser data. It uses rmdir, never recursive deletion, for the old KOReader image directory.

## Version report

Kindle-Version-Report.txt is generated after package installation, successful Update All, and successful Kindle Batch Preparation repair. It records device, KPM, package, KOReader, plugin, and KPP application/bundle fingerprints.


## Experimental Royal Road page-text capture

The package also installs **KPP-Page-Text-Capture** in Documents. It reads KPP's getter-only `getLastOpenPage` history metadata, accepts only an HTTPS `www.royalroad.com` address, strips query parameters, and opens that address in a separate `GtkOffscreenWindow` using the Kindle firmware's WebKitGTK library. A read-only JavaScript query tries Royal Road's chapter-content selectors and writes the resulting text to `RoyalRoad-Page-Capture-YYYYMMDD-HHMMSS.txt`.

This is deliberately **not** a bookmarklet and does not inject into, attach to, or navigate the existing KPP browser process. The separate offscreen WebKit instance does not automatically share KPP's cookies, login session, or in-memory page state. Royal Road may therefore show a login or anti-bot challenge instead of the chapter. The helper waits for page text, labels whether it captured the chapter element or the full document, and fails rather than silently saving an empty result.

This is an experimental first proof of concept. It was cross-compiled for the Kindle's ARM EABI5 hard-float ABI and linked against libraries in the supplied firmware export, but it has **not yet been runtime-tested on the actual Kindle**. It requires the Kindle GTK display and the matching WebKitGTK runtime. A failed attempt leaves the original browser window untouched. It does not read or export cookies, passwords, browser database rows, process memory, or other browser history entries.

The reproducible native source and build recipe are in `scripts/native/`. The package stores the executable compressed as `files/kpp-page-capture.gz`; the installer validates and expands it into the private `Documents/.royalroadtools/` directory. Uninstall removes that helper and launcher but leaves any previously captured text files in Documents.
