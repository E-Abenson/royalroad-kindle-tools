# Kindle installation and maintenance

## KPM Update All and cleanup

Open **KPM-Update-All** to refresh repositories and upgrade installed KPM packages.

Only after the upgrade succeeds does Update All run its built-in retired-artifact cleanup and regenerate the version report. No separate cleanup launcher/helper, queue, completed-items history, or cleanup log is kept. Each run checks the same fixed retirement rules; absent items are skipped and retired files that reappear are removed. The ordinary `KPM-Update-All.log` contains only a brief cleanup count.

Cleanup is limited to old test/diagnostic launchers and logs, obsolete feature/deletion URLs, the named old bookmark, stale cached scriptlets, old Batch Preparation repair files, and exact project-managed legacy screensaver images. It does not delete books, EPUBs, browser data, or unrelated files and images.

## Current launchers

- **KPP-Native-Bridge-Export** — manual native-binary export.
- **KPP-JavaScript-Bundle-Export** — manual Hermes bundle copy.
- **Inspect-USB-Screen** — read-only stock USB-connection display inspection.
- **KPM-Update-All** — repository refresh, package upgrade, cleanup, and version-report refresh.

The working native and JavaScript exporters remain; their automated export tests are removed.

## Batch Preparation is optional

The regular KPM package no longer installs a repair launcher or source archive to Kindle Documents. Optional repair materials remain under `optional/batch-prepare/` in the repository. An already-installed KOReader Batch Preparation plugin is left untouched.
