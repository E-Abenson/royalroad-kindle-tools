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


## Experimental Royal Road page-text capture

The package also installs **KPP-Page-Text-Capture** in Documents. It reads KPP's getter-only `getLastOpenPage` history metadata, accepts only an HTTPS `www.royalroad.com` address, strips query parameters, and opens that address in a separate `GtkOffscreenWindow` using the Kindle firmware's WebKitGTK library. A read-only JavaScript query tries Royal Road's chapter-content selectors and writes the resulting text to `RoyalRoad-Page-Capture-YYYYMMDD-HHMMSS.txt`.

This is deliberately **not** a bookmarklet and does not inject into, attach to, or navigate the existing KPP browser process. The separate offscreen WebKit instance does not automatically share KPP's cookies, login session, or in-memory page state. Royal Road may therefore show a login or anti-bot challenge instead of the chapter. The helper waits for page text, labels whether it captured the chapter element or the full document, and fails rather than silently saving an empty result.

This is an experimental first proof of concept. It was cross-compiled for the Kindle's ARM EABI5 hard-float ABI and linked against libraries in the supplied firmware export, but it has **not yet been runtime-tested on the actual Kindle**. It requires the Kindle GTK display and the matching WebKitGTK runtime. A failed attempt leaves the original browser window untouched. It does not read or export cookies, passwords, browser database rows, process memory, or other browser history entries.

The reproducible native source and build recipe are in `scripts/native/`. The package stores the executable compressed as `files/kpp-page-capture.gz`; the installer validates and expands it into the private `Documents/.royalroadtools/` directory. Uninstall removes that helper and launcher but leaves any previously captured text files in Documents.
