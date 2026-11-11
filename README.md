# Royal Road Kindle Tools

An experimental KPM toolkit for investigating the jailbroken Kindle's built-in KPP browser and, if ordinary access proves reliable, eventually building an offline EPUB. It is not yet a story downloader.

## Device facts and confirmed browser findings

- Kindle: 10th generation; exact Basic/Paperwhite variant not yet identified.
- Firmware last reported: 5.18.1.1.1 (refresh on-device with the version report).
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A direct Kindle curl request received HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser exposes getLastOpenPage and a write-only string property named invokeAction.
- The active LIPC service owner was reported as KPPMainApp at /app/bin/KPPMainAppV2.
- The accepted invokeAction string format remains unknown; no payload has been sent.

## Current Kindle tools

- **RR-KPP-Interface-Inspector** — performs read-only static inspection of selected KPP/browser application files for interface markers. It reports only file paths and fixed marker names; it does not query LIPC values, touch the browser session, or use the network.
- **Automatic KPP research** — during every KPM package install/upgrade, the inspector runs, a private copy of the Hermes bytecode bundle is saved locally, and the sanitised inspector report is uploaded to pasters.io with a one-day expiry. The returned share link is placed at the top of the inspector log. The binary bundle is never sent to pasters.io. This stage makes a private local export only; disassembly still requires a private authenticated receiver, which is not part of the current package yet.
- **RoyalRoadTools-Cleanup** — persistent cleanup for retired tests, scripts, logs, temporary files, package-cache files, saved paste links, and the exact old bookmark. Successful items are removed from the queue; failed items remain for retry.
- **Kindle-Version-Report.txt** — automatically regenerated during package installation/upgrade and after a successful Kindle Batch Preparation repair. There is no separate manual report launcher.
- **KPM-Update-All** — updates installed KPM packages.
- **KindleBatchPrepareFix** — on-demand repair/reinstall tool for the separate KOReader Kindle Batch Preparation plugin. It is not a background service.

## Update and cleanup

Open **KPM-Update-All** from the Kindle library. During package update, the installer merges new cleanup entries and automatically runs **RoyalRoadTools-Cleanup**. It retains a pending queue at `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt` and a completed-item ledger at `/mnt/us/documents/RoyalRoadTools-Cleanup-Completed.txt`.

To add future cleanup targets, add one line to `kpm/package/scriptlets/RoyalRoadTools-Cleanup-Queue.txt`. The next package update removes the retired broad LIPC dump and uploader, their local logs and saved links, along with the older smoke-test and KPP-bundle-scan artifacts already queued. It preserves the new KPP interface inspector, KPM updater, version report, and KOReader plugin repair tool.

After a KPM installation/upgrade, the inspector runs automatically and its sanitised report is uploaded to pasters.io. The returned one-day share link is saved at the top of `/mnt/us/documents/RR-KPP-Interface-Inspector.log`. The bundle itself is copied privately to `/mnt/us/documents/.rr-kpp-research/KPPMainApp.js.hbc` and is never sent to pasters.io. This release does not yet disassemble it; the final automated stage needs a private authenticated receiver. `Kindle-Version-Report.txt` is also regenerated automatically; there is no manual report launcher. Keep **KindleBatchPrepareFix** installed; it refreshes the version report automatically after a successful plugin repair.

## Remaining browser investigation

The previous LIPC inventory established that `com.lab126.kppbrowser` has a write-only string property called `invokeAction`, but its accepted format is unknown. The old full-system LIPC dump has been retired because broad service inventories can contain private authentication and account values.

The new inspector searches selected installed application files for static method and interface markers. A marker is only a clue; it does not establish a supported action or prove that JavaScript injection is accessible. Do not send a guessed `invokeAction` payload.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA or other access-control bypasses. Full chapter collection and EPUB creation have not been implemented.



See [architecture and staged test plan](docs/architecture-and-test-plan.md) and [KPM installation](docs/kpm-installation.md).
