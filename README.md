# Royal Road Kindle Tools

An experimental KPM toolkit for investigating the jailbroken Kindle's built-in KPP browser and, if ordinary access proves reliable, eventually building an offline EPUB. It is not yet a story downloader.

## Device facts and confirmed browser findings

- Kindle: 10th generation; exact Basic/Paperwhite variant not yet identified.
- Firmware last reported: `5.18.1.1.1` (refresh on-device with the version report).
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A direct Kindle `curl` request received HTTP 403 with Cloudflare challenge markers.
- `com.lab126.kppbrowser` exposes `getLastOpenPage` and a write-only string property named `invokeAction`.
- The active LIPC service owner was reported as `KPPMainApp` at `/app/bin/KPPMainAppV2`.
- The accepted `invokeAction` string format remains unknown; no payload has been sent.

## Current Kindle tools

- **RR-KPP-Bundle-Scan** — the one remaining read-only investigation, scanning installed KPP application files for browser/action strings.
- **RR-Upload-Bundle-Scan** — manually shares the filtered scan log via an expiring paste link.
- **RoyalRoadTools-Version-Info** — creates `/mnt/us/documents/Kindle-Version-Report.txt` with installed versions and code fingerprints.
- **KPM-Update-All** — updates installed KPM packages.
- **KindleBatchPrepareFix** — on-demand repair/reinstall tool for the separate KOReader Kindle Batch Preparation plugin. It is not continuously running.
- **RoyalRoadTools-Cleanup** — one-time removal of completed smoke/LIPC/bookmarklet tests and their obsolete logs/links.

## Update and maintenance

Open **KPM-Update-All** from the Kindle library to refresh the repository index and upgrade packages. Then open **RoyalRoadTools-Version-Info** to refresh the version report. The report is a snapshot; rerun it after updating KPM or KOReader.

Open **RoyalRoadTools-Cleanup** once after installing the cleanup release. It removes old test launchers and their artifacts, and removes only the old Royal Road Session Test bookmark after backing up and verifying the browser database. It preserves the current bundle scan, its uploader, the KPM updater, the KOReader repair tool, and the KOReader plugin itself.

Keep **KindleBatchPrepareFix** installed. Use it only when the separate KOReader plugin needs to be repaired or reinstalled. It is not a background service.

## Remaining browser investigation

The current scan searches the installed KPP JavaScript Hermes bundle and native executable as data. It does not execute either file, navigate the browser, or send an `invokeAction` payload. The next step is to identify the action string from reliable installed-code evidence, not to guess it.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA or other access-control bypasses. Full chapter collection and EPUB creation have not been implemented.

See [architecture and staged test plan](docs/architecture-and-test-plan.md) and [KPM installation](docs/kpm-installation.md).
