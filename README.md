# Royal Road Kindle Tools

An experimental KPM toolkit for investigating the jailbroken Kindle's built-in KPP browser and, if ordinary access proves reliable, eventually building an offline EPUB. It is not yet a story downloader.

## Device facts and confirmed browser findings

- Kindle firmware last reported: 5.18.1.1.1.
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A direct Kindle curl request received HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser exposes getLastOpenPage and a write-only string property named invokeAction.
- The accepted invokeAction string format remains unknown; no payload has been sent.

## Current Kindle tools

- **RR-KPP-Interface-Inspector** — read-only static inspection of selected KPP/browser application files; reports fixed marker names and file paths only.
- **Automatic KPP research export** — on KPM installation/upgrade, the inspector report is uploaded to pasters.io with one-day expiry, and its link is placed at the top of the inspector log. Separately, an unmodified copy of `/app/KPPMainApp/js/KPPMainApp.js.hbc` is checksum-verified and placed at `/mnt/us/documents/KPPMainApp.js.hbc` for this one-time USB investigation. The binary is never uploaded.
- **RoyalRoadTools-Cleanup** — persistent cleanup for retired tests, logs, temporary files, package-cache files, saved paste links, and the exact old bookmark. Completed actions are recorded; failed actions remain queued.
- **Kindle-Version-Report.txt** — regenerated automatically during KPM package installation/upgrade and after successful Kindle Batch Preparation repair. There is no separate manual report launcher.
- **KPM-Update-All** — updates installed KPM packages.
- **KindleBatchPrepareFix** — on-demand repair/reinstall tool for the separate KOReader plugin; keep it installed.

## One-time KPP bytecode investigation (Option C)

1. Open **KPM-Update-All** on the Kindle. The package installer places `KPPMainApp.js.hbc` directly in Kindle Documents and writes its size, SHA256 and Hermes version to `KPP-Bytecode-Export.txt`.
2. Connect the Kindle to the Windows computer with USB and copy `KPPMainApp.js.hbc` from the Kindle's Documents folder.
3. Download `KPP-One-Time-Disassembler-Windows.zip` from the same GitHub release as the KPM package and extract it.
4. Put the copied `KPPMainApp.js.hbc` beside `Run-KPP-Disassembly.bat` and double-click the BAT file.
5. The helper uses the Python 3 installation already on the computer (Python 3.8+). It downloads a pinned pure-Python Hermes disassembler source archive from GitHub the first time it runs; no pip installation, compiler, admin rights or separate program installation is needed.
6. It creates a full local disassembly plus `KPP-Interface-Findings.txt`, highlighting string-table entries and the functions that reference them.

The operation is read-only: it does not execute or modify the bundle and does not upload the bundle or disassembly. It is a one-time investigation; repeat only if the Kindle's KPP application materially changes. See [the Windows tool instructions](pc-tools/kpp-disassembler/README-FIRST.txt).

## Cleanup and version reporting

Open **KPM-Update-All** to refresh repositories and upgrade packages. During installation, the cleaner merges and processes the persistent queue, the inspector and export run, the sanitised text report is uploaded, and the version report is replaced automatically. The old hidden duplicate bundle is removed only after the new Documents copy passes SHA256 verification. KOReader books, EPUBs, and the Kindle Batch Preparation repair utility are preserved.

## Safety limits

A static marker does not establish that a method is callable or that it accepts a particular payload. Do not send a guessed `invokeAction` value. Do not share a full-system `lipc-probe -a -v` dump; unrelated services can expose private authentication/account values. Stop on access-denial or Cloudflare challenge responses; do not attempt CAPTCHA or access-control bypasses.

See [architecture and staged test plan](docs/architecture-and-test-plan.md) and [KPM installation](docs/kpm-installation.md).
