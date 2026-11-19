# Royal Road Kindle Tools

A small KPM toolkit for read-only investigation of the Kindle's built-in KPP browser, plus KOReader maintenance tools. It is not a story downloader.

## Current Kindle launchers

- **KPP-Native-Bridge-Export** — manually copies the running KPP executable and readable file-backed ELF libraries to a USB-transfer archive. It does not collect process memory, page content, cookies, history, URLs, or runtime property values.
- **KPP-JavaScript-Bundle-Export** — manually copies the installed Hermes JavaScript bundle to Documents, verifies the Hermes header and SHA-256, and records its version and checksum. It does not execute or modify the application.
- **Inspect-USB-Screen** — a separate read-only inspection of the stock display shown while the Kindle is connected over USB. It can share a text-only report through Pasters.io; the display assets themselves are not uploaded. This is not a sleep-screen or KOReader screensaver tool.
- **KPM-Update-All** — manually refreshes registered KPM repositories and upgrades installed KPM packages. After a successful upgrade it runs the hidden project cleanup helper and refreshes the version report.
- **KindleBatchPrepareFix** — manually repairs/reinstalls the KOReader Kindle Batch Preparation plugin.

All investigation launchers are manual. The cleanup runner is private and is called only after a successful KPM upgrade.

## Current browser investigation

The next step is to correlate the native bridge findings with the current Hermes JavaScript bundle.

1. Open the Kindle's built-in browser and leave it running.
2. Run **KPP-Native-Bridge-Export** to create KPP-Native-Bridge-Binaries.tar.gz in Documents.
3. Run **KPP-JavaScript-Bundle-Export** to create KPPMainApp.js.hbc and KPP-JavaScript-Bundle-Export.txt in Documents.
4. Copy both files from Kindle Documents over USB and attach them directly in the ChatGPT conversation. No Windows helper or local disassembler is needed.

The analysis is static and read-only. The files are inspected here after you upload them. Nothing is executed, no LIPC writes or guessed invokeAction payloads are sent, and no browser page text, cookies, account data, or history is collected by either exporter.

The older Hermes bundle was previously exported and disassembled. A fresh copy is useful to confirm that the JavaScript layer still matches the native binaries collected on 2026-11-18. The new bundle exporter replaces that completed one-off launcher with a focused, verifiable export for this correlation step.

## Cleanup and screensavers

The former project-managed Rabbinic/KOReader sleep-screen image set, image builder, and manual copy launcher have been retired. During the next successful Update All, cleanup removes only the exact image files that this project installed in /mnt/us/koreader-screensavers-inverted and /mnt/us/screensavers, and removes the KOReader image folder only if it is empty.

This does **not** remove the separate third-party Custom Screensaver KPM extension, its settings, other sleep-screen images, KOReader books, EPUBs, or other user files. KPM-Update-All no longer adds a screensaver repository or installs that extension on your behalf; the normal KPM upgrade command still handles packages already installed in KPM.

The USB display inspector remains because the USB connection screen is separate from the sleep screensaver.

## Version and cleanup reports

Kindle-Version-Report.txt is refreshed after successful package installation, Update All, and successful plugin repair. The cleanup queue is stored at RoyalRoadTools-Cleanup-Queue.txt; successful actions are removed from the pending queue and recorded in RoyalRoadTools-Cleanup-Completed.txt. Failed or unverifiable actions remain queued for a later Update All.

Cleanup targets are deliberately narrow. It never recursively deletes user folders or sweeps general Documents, books, EPUBs, browser data, or unrelated screensaver images.

## Confirmed limits

The supplied native binaries expose history/settings/navigation functions, but the analysis did not identify a ready-made, supported read-only LIPC method that returns the currently displayed page's text or HTML. The React Native bridge and JavaScript bundle need to be considered together before deciding whether a documented read-only route exists.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA/proof-of-work or other access-control circumvention. Full chapter collection and EPUB creation have not been implemented.
