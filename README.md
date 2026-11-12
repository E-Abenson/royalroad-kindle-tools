# Royal Road Kindle Tools

An experimental KPM toolkit for investigating the jailbroken Kindle's built-in KPP browser and, if ordinary access proves reliable, eventually building an offline EPUB. It is not yet a story downloader.

## Device facts and confirmed browser findings

- Kindle: 10th generation; exact Basic/Paperwhite variant not yet identified.
- Firmware last reported: 5.18.1.1.1 (the version report refreshes automatically after Update All).
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A direct Kindle curl request received HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser exposes getLastOpenPage and a write-only string property named invokeAction.
- The active LIPC service owner was reported as KPPMainApp at /app/bin/KPPMainAppV2.
- The accepted invokeAction string format remains unknown; no payload has been sent.

## Current Kindle tools

All tools below are **manual launchers**, except the cleanup runner, which is private and is invoked automatically by KPM-Update-All.

- **RR-KPP-Interface-Inspector** — manually performs read-only static inspection of selected KPP/browser application files for interface markers. It reports only file paths and fixed marker names; it does not query LIPC values, touch the browser session, or use the network.
- **RR-KPP-Interface-Inspector-Upload** — optional manual upload of the sanitised inspector report to pasters.io with a one-day expiry. Run it only after the inspector and only when you choose to share the report.
- **RR-KPP-Bytecode-Export** — one-time manual export of a verified bytecode copy to Kindle Documents for USB transfer. The binary bundle is never sent to pasters.io.
- **Kindle-Version-Report.txt** — regenerated automatically after a successful KPM-Update-All run and after a successful Kindle Batch Preparation repair. There is no separate version-report launcher.
- **KPM-Update-All** — manually updates installed KPM packages, then automatically runs the cleanup queue after a successful upgrade.
- **KindleBatchPrepareFix** — manual repair/reinstall tool for the separate KOReader Kindle Batch Preparation plugin.

The inspector, uploader, exporter, and plugin repair tool remain manual launchers. The version report is generated automatically after Update All and after a successful plugin repair.

## Update and cleanup

Open **KPM-Update-All** from the Kindle library. After a successful package upgrade, it runs the hidden cleanup helper at `/mnt/us/documents/.royalroadtools/cleanup.sh`. There is no separate **RoyalRoadTools-Cleanup** launcher. The package installer merges new cleanup entries into `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt` but does not run the cleaner.

The cleaner retains a pending queue and completed-item ledger at `/mnt/us/documents/RoyalRoadTools-Cleanup-Completed.txt`. Successful actions are removed from the queue; failed or unverifiable actions remain for the next Update All run. The latest cleanup results are saved in `/mnt/us/documents/RoyalRoadTools-Cleanup.log`.

To add future cleanup targets, add one line to `kpm/package/scriptlets/RoyalRoadTools-Cleanup-Queue.txt`. The next package update adds new entries without resurrecting completed work. Use exact paths and narrow patterns; never add broad wildcards for user documents, story files, EPUBs, KOReader books, the active inspector, updater, version report, or plugin repair tool.

## One-time KPP browser investigation — USB workflow

Run **RR-KPP-Bytecode-Export** once. It copies the unmodified `/app/KPPMainApp/js/KPPMainApp.js.hbc` to `/mnt/us/documents/KPPMainApp.js.hbc`, verifies its SHA256, and records the Hermes version in `KPP-Bytecode-Export.txt`. The previous hidden duplicate is removed only after the visible Documents copy is verified.

Connect the Kindle to Windows over USB and copy `KPPMainApp.js.hbc` from Documents. Download and extract `KPP-One-Time-Disassembler-Windows.zip` from the same GitHub release, put the bundle beside `Run-KPP-Disassembly.bat`, and double-click it.

The helper uses your existing Python 3.8+ installation. It downloads a pinned pure-Python Hermes disassembler from GitHub on first run; no pip packages, compiler, administrator rights, or system-wide installation are needed. It creates a focused `KPP-Interface-Findings.txt` plus the full local disassembly. The bundle and disassembly are never uploaded. This is a one-time investigation, not a recurring task.

## Remaining browser investigation

The previous LIPC inventory established that `com.lab126.kppbrowser` has a write-only string property called `invokeAction`, but its accepted format is unknown. The old full-system LIPC dump has been retired because broad service inventories can contain private account and authentication values.

The new inspector searches selected installed application files for static method and interface markers. A marker is only a clue; it does not establish a supported action or prove that JavaScript injection is accessible. Do not send a guessed `invokeAction` payload.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA or other access-control bypasses. Full chapter collection and EPUB creation have not been implemented.

See [architecture and staged test plan](docs/architecture-and-test-plan.md) and [KPM installation](docs/kpm-installation.md).
