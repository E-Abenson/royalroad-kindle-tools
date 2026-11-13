# Royal Road Kindle Tools

An experimental KPM toolkit for investigating the jailbroken Kindle's built-in KPP browser and, if ordinary access proves reliable, eventually building an offline EPUB. It is not yet a story downloader.

## Device facts

- Kindle: 10th generation; exact Basic/Paperwhite variant not yet identified.
- Firmware last reported: 5.18.1.1.1 (version report refreshes after Update All).
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A direct Kindle curl request received HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser exposes getLastOpenPage and a write-only string property named invokeAction.
- The accepted invokeAction string format remains unknown; no payload has been sent.

## Current Kindle tools

The Kindle-side KPP interface-inspector stage is retired. Its launcher, uploader and report are being removed by the cleanup queue; they are no longer installed by package updates.

- **RR-KPP-Bytecode-Export** — one-time manual export of a verified copy of the Hermes bundle to Kindle Documents for USB transfer. Keep this until the one-time Windows disassembly step is complete.
- **KPM-Update-All** — manual repository refresh and package upgrade. After a successful upgrade, it automatically runs the private cleanup helper and refreshes the version report.
- **KindleBatchPrepareFix** — manual repair/reinstall tool for the KOReader Kindle Batch Preparation plugin.

The cleanup runner is private at `/mnt/us/documents/.royalroadtools/cleanup.sh`. There is no separate cleanup launcher. Other tools are not automatically started by Update All; the version report is generated internally as part of the update.

## One-time KPP browser investigation — USB workflow

Run **RR-KPP-Bytecode-Export** once. It copies the unmodified `/app/KPPMainApp/js/KPPMainApp.js.hbc` to `/mnt/us/documents/KPPMainApp.js.hbc`, verifies its SHA256 and records the Hermes version in `KPP-Bytecode-Export.txt`. The previous hidden duplicate is removed only after the visible copy is verified.

Connect the Kindle to Windows over USB and copy `KPPMainApp.js.hbc` from Documents. Download and extract `KPP-One-Time-Disassembler-Windows.zip` from the same GitHub release, put the bundle beside `Run-KPP-Disassembly.bat`, and double-click it.

The helper uses your existing Python 3.8+ installation. It downloads a pinned pure-Python Hermes disassembler from GitHub on first run; no pip packages, compiler, administrator rights, or system-wide installation are needed. It creates a focused `KPP-Interface-Findings.txt` plus the full local disassembly. The bundle and disassembly are never uploaded. This is a one-time investigation, not a recurring task.

## Update and cleanup

Open **KPM-Update-All** from the Kindle library. After a successful package upgrade, it runs the hidden cleanup helper and then refreshes `Kindle-Version-Report.txt`.

The cleanup queue is `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt`; its completed-item ledger is `RoyalRoadTools-Cleanup-Completed.txt`. Successful actions are removed from the queue; failed or unverifiable actions remain for the next Update All run. If a retired target still exists after being marked complete, the installer re-queues it.

The queue contains exact retired script, log, report and temporary-file names. It does not use broad wildcard deletion of user documents, story files, EPUBs, or KOReader books. The current cleanup specifically removes the Kindle-side KPP interface inspector, upload launcher and report while preserving the USB bytecode export needed for the next test.

## Remaining browser investigation

The accepted format for `com.lab126.kppbrowser.invokeAction` remains unknown. The one-time Windows disassembly is intended to identify the real implementation path and argument handling before designing a safe, narrow live test. Do not send a guessed `invokeAction` payload.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA or other access-control bypasses. Full chapter collection and EPUB creation have not been implemented.

See [architecture and staged test plan](docs/architecture-and-test-plan.md) and [KPM installation](docs/kpm-installation.md).
