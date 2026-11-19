# Royal Road Kindle Tools — KPM package

This package installs manual Kindle launchers and one private cleanup helper. It is not a Royal Road story downloader or EPUB builder.

## Manual Kindle launchers

- **KPP-Native-Bridge-Export** — exports the running KPP executable and mapped ELF libraries as a USB-transfer archive. The archive contains static native files only, not process memory or browser-session data.
- **KPP-JavaScript-Bundle-Export** — copies the KPP Hermes JavaScript bundle to Documents, verifies its header and SHA-256, and records the bytecode version. The original application file is unchanged.
- **Inspect-USB-Screen** — read-only inspection of the stock USB-connection display. This is separate from the device sleep screen.
- **KPM-Update-All** — refreshes registered repositories and upgrades installed KPM packages. After a successful upgrade it runs cleanup and regenerates the version report.
- **KindleBatchPrepareFix** — manually repairs/reinstalls the separate Kindle Batch Preparation KOReader plugin.

Installation does not run an investigation, export, upload, cleanup, or plugin repair.

## JavaScript bundle export

Run **KPP-JavaScript-Bundle-Export** from the Kindle library. It copies /app/KPPMainApp/js/KPPMainApp.js.hbc to /mnt/us/documents/KPPMainApp.js.hbc, verifies the Hermes magic and SHA-256, and writes KPP-JavaScript-Bundle-Export.txt. The export is limited to 50 MB. It does not execute, patch, upload, or modify the original bundle.

Connect the Kindle to a computer over USB and attach KPPMainApp.js.hbc directly in the ChatGPT conversation. No Windows helper or local Python package is needed.

## Automatic cleanup

There is no separate **RoyalRoadTools-Cleanup** launcher. The cleanup runner lives privately at /mnt/us/documents/.royalroadtools/cleanup.sh and is called by **KPM-Update-All** only after a successful package upgrade.

The installer merges explicit cleanup entries into /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt. Successful actions are removed from the pending queue and recorded in RoyalRoadTools-Cleanup-Completed.txt; failed or unverifiable actions remain queued.

The queue removes the old bytecode-export launcher/report and the exact legacy Rabbinic screensaver assets. It does not remove the new Hermes bundle copy, unrelated screen images, the third-party Custom Screensaver extension, its settings, books, EPUBs, or browser data. It uses rmdir, never recursive deletion, for the old KOReader image directory.

## Version report

Kindle-Version-Report.txt is generated after package installation, successful Update All, and successful Kindle Batch Preparation repair. It records device, KPM, package, KOReader, plugin, and KPP application/bundle fingerprints.
