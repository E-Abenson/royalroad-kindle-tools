# Royal Road Kindle Tools — KPM package

This package installs the active KPP investigation launchers, KPM-Update-All, a private version-report helper, and the KPM-managed ScreenLockPin plugin. Cleanup is built into KPM-Update-All; no cleanup scriptlet or state file is installed.

## Installed launchers

- **KPP-Native-Bridge-Export** — manual native-binary export.
- **KPP-JavaScript-Bundle-Export** — manual Hermes bundle copy for offline inspection.
- **Inspect-USB-Screen** — read-only USB-connection display inspection.
- **KPM-Update-All** — repository refresh, package upgrade, cleanup, and version report.

The automated exporter test harness is excluded. No Batch Preparation repair launcher or source archive is installed by this package.

## Automatic cleanup

Cleanup logic is part of `KPM-Update-All.sh`; there is no cleanup helper, queue, completed-items ledger, or cleanup log. Each run checks fixed retired files and narrow generated-file patterns, without sweeping books, EPUBs, browser data, or unrelated files. Retired image directories are removed only when empty.

Only a brief cleanup count is added to the ordinary `KPM-Update-All.log`.

## Optional Batch Preparation

The repair launcher and source archive are retained in `optional/batch-prepare/` in the repository only. A previously installed KOReader plugin is not removed or changed.
