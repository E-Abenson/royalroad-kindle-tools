# Royal Road Kindle Tools

A focused KPM toolkit for read-only investigation of the Kindle's built-in KPP browser, plus KOReader maintenance.

## Kindle launchers

- **KPP-Native-Bridge-Export** — manual native-binary export.
- **KPP-JavaScript-Bundle-Export** — manual Hermes bundle copy for offline inspection.
- **Inspect-USB-Screen** — read-only stock USB-connection display inspection.
- **KPM-Update-All** — repository refresh, package upgrade, retired-artifact cleanup, and version report.

The working exporters remain. Their automated export-test harness has been removed.

## KPM cleanup

Cleanup is built into **KPM-Update-All** and runs only after a successful package upgrade. There is no separate cleanup launcher, hidden helper, queue, completed-items history, or cleanup log. Each run checks the fixed retirement list; absent items are skipped and retired items that reappear are removed. Only a brief count appears in the ordinary `KPM-Update-All.log`.

Cleanup targets old browser/KPP tests, diagnostics, upload helpers, obsolete feature/deletion URLs, the old test bookmark, stale package-cache scriptlets, old Batch Preparation repair files, and exact project-managed legacy screensaver images. It does not sweep books, EPUBs, browser data, or unrelated images. Directories are removed only when empty.

## Optional Batch Preparation

Batch Preparation is not part of the regular KPM package. Its optional repair script, patch helper, and compressed archive remain in `optional/batch-prepare/` in the repository only. They are not installed to Kindle Documents. An already-installed KOReader plugin is left untouched.
