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

- **RR-KPP-Interface-Inspector** — performs read-only static inspection of selected KPP/browser application files for interface markers. It reports only file paths and fixed marker names; it does not query LIPC values, touch the browser session, or upload anything.
- **RoyalRoadTools-Cleanup** — persistent cleanup for retired tests, scripts, logs, temporary files, package-cache files, saved paste links, and the exact old bookmark. Successful items are removed from the queue; failed items remain for retry.
- **RoyalRoadTools-Version-Info** — creates `/mnt/us/documents/Kindle-Version-Report.txt` with installed versions and code fingerprints.
- **KPM-Update-All** — updates installed KPM packages.
- **KindleBatchPrepareFix** — on-demand repair/reinstall tool for the separate KOReader Kindle Batch Preparation plugin. It is not a background service.

## Update and cleanup

Open **KPM-Update-All** from the Kindle library. During package update, the installer merges new cleanup entries and automatically runs **RoyalRoadTools-Cleanup**. It retains a pending queue at `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt` and a completed-item ledger at `/mnt/us/documents/RoyalRoadTools-Cleanup-Completed.txt`.

To add future cleanup targets, add one line to `kpm/package/scriptlets/RoyalRoadTools-Cleanup-Queue.txt`. The next package update removes the retired broad LIPC dump and uploader, their local logs and saved links, along with the older smoke-test and KPP-bundle-scan artifacts already queued. It preserves the new KPP interface inspector, KPM updater, version report, and KOReader plugin repair tool.

Open **RR-KPP-Interface-Inspector** after updating, then review `/mnt/us/documents/RR-KPP-Interface-Inspector.log`. Share only that report if you want the static findings reviewed. There is no upload function in the inspector.

Open **RoyalRoadTools-Version-Info** to refresh the version report. Keep **KindleBatchPrepareFix** installed; use it only when the separate KOReader plugin needs repair or reinstalling.

## Remaining browser investigation

The previous LIPC inventory established that `com.lab126.kppbrowser` has a write-only string property called `invokeAction`, but its accepted format is unknown. The old full-system LIPC dump has been retired because broad service inventories can contain private authentication and account values.

The new inspector searches selected installed application files for static method and interface markers. A marker is only a clue; it does not establish a supported action or prove that JavaScript injection is accessible. Do not send a guessed `invokeAction` payload.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA or other access-control bypasses. Full chapter collection and EPUB creation have not been implemented.



See [architecture and staged test plan](docs/architecture-and-test-plan.md) and [KPM installation](docs/kpm-installation.md).
