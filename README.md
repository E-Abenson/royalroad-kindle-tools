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

- **RR-LIPC-READONLY-PROBE** — lists registered LIPC services using lipc-probe -a -v and records a read-only KPP process snapshot. It does not set LIPC properties, send events, navigate, refresh, or run JavaScript.
- **RR-LIPC-READONLY-UPLOAD** — separately uploads a sanitized copy of that log to pasters.io. Credential-bearing service sections and identity fields are omitted or redacted, and the current browser URL is hidden. The raw log remains unchanged. It asks you to type UPLOAD when keyboard input is available; otherwise opening the dedicated launcher starts the transfer. It requests one-week expiry, stores the paste link and delete link locally, and does not run the probe or interact with the browser.
- **RoyalRoadTools-Cleanup** — persistent, queue-based cleanup for retired tests, scripts, logs, temporary files and exact old bookmarklets. Successful items are removed from the queue; failed or unverifiable items remain for retry.
- **RoyalRoadTools-Version-Info** — creates /mnt/us/documents/Kindle-Version-Report.txt with installed versions and code fingerprints.
- **KPM-Update-All** — updates installed KPM packages.
- **KindleBatchPrepareFix** — on-demand repair/reinstall tool for the separate KOReader Kindle Batch Preparation plugin. It is not a background service.

## Update and cleanup

Open **KPM-Update-All** from the Kindle library. During the package update, the installer merges new cleanup entries and automatically runs **RoyalRoadTools-Cleanup**. It retains a pending queue at /mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt and a completed-item ledger at /mnt/us/documents/RoyalRoadTools-Cleanup-Completed.txt.

To add future cleanup targets, add one line to kpm/package/scriptlets/RoyalRoadTools-Cleanup-Queue.txt. Supported forms are DOC|filename, DOCGLOB|pattern, PKG|relative/path, PKGDIR|relative/path, REMOTE_DELETE|filename, and the narrowly scoped BOOKMARK|Royal Road Session Test. A task is removed from the pending queue only after verified success. The completed ledger prevents later package updates from re-adding the same finished task. The cleanup runner remains installed so it can be run manually to retry pending items.

The cleanup deliberately preserves RR-LIPC-READONLY-PROBE and its log, KPM-Update-All and its log, KindleBatchPrepareFix and its log, the installed KOReader plugin, KOReader books and EPUBs.

Open **RR-LIPC-READONLY-PROBE** after updating, then review /mnt/us/documents/RR-LIPC-READONLY-PROBE.log. When ready to share it, open **RR-LIPC-READONLY-UPLOAD**. It asks you to type `UPLOAD` when the launcher supports keyboard input; otherwise opening this dedicated uploader starts the transfer. The sanitized paste is accessible to anyone with its link and is requested to expire after one week. The uploader hides credential values and personal identifiers before sending it. Open **RoyalRoadTools-Version-Info** to refresh the version report.

Keep **KindleBatchPrepareFix** installed. Use it only when the separate KOReader plugin needs to be repaired or reinstalled. It is not a background service.

## Remaining browser investigation

The new probe inventories registered LIPC services and KPP processes without writing LIPC properties or interacting with the browser. Its results should tell us which service and properties are actually exposed. The accepted invokeAction payload remains unknown; do not guess or send one.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA or other access-control bypasses. Full chapter collection and EPUB creation have not been implemented.

See [architecture and staged test plan](docs/architecture-and-test-plan.md) and [KPM installation](docs/kpm-installation.md).
