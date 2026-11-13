# Royal Road Kindle Tools

An experimental KPM toolkit for investigating the jailbroken Kindle's built-in KPP browser and, if ordinary access proves reliable, eventually building an offline EPUB. It is not yet a story downloader.

## Device facts

- Kindle: 10th generation; exact Basic/Paperwhite variant not yet identified.
- Firmware last reported: 5.18.1.1.1.
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A direct Kindle curl request to Royal Road returned HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser.getLastOpenPage is readable.
- com.lab126.kppbrowser.invokeAction exists as a write-only string property.
- The accepted invokeAction string format remains unknown; no payload has been sent.

## Current Kindle tools

- **KPP-Comprehensive-Diagnostic** — one manual, read-only diagnostic run. It discovers service names, probes only relevant KPP/browser services, records property names/type/access metadata, performs read-only service-owner lookups, lists relevant process names, and fingerprints the KPP binaries. It then uploads only this sanitized technical report to pasters.io with one-week expiry requested. The paste link is displayed and saved privately on the Kindle.
- **RR-KPP-Bytecode-Export** — one-time manual export of a verified copy of the Hermes bundle to Kindle Documents for USB transfer.
- **KPM-Update-All** — manual repository refresh and package upgrade. After a successful upgrade, it automatically runs the private cleanup helper and refreshes the version report.
- **KindleBatchPrepareFix** — manual repair/reinstall tool for the KOReader Kindle Batch Preparation plugin.

The cleanup runner is private at `/mnt/us/documents/.royalroadtools/cleanup.sh`. There is no separate cleanup launcher. Other tools are not automatically started by Update All; the version report is generated internally as part of the update.

## One-run comprehensive diagnostic

Open the Kindle's built-in browser to an ordinary page you can access, then launch **KPP-Comprehensive-Diagnostic** once. It creates `/mnt/us/documents/KPP-Comprehensive-Diagnostic.txt` and uploads that report automatically to pasters.io.

The previous device run showed `lipc-probe -a` exiting with status 1. The new script now preserves and parses any partial stdout from that command, even when its exit status is nonzero. It first uses `lipc-probe -l` for service discovery, then runs the non-verbose all-service metadata scan (`-a`, never `-v`), summarizes individual service probes, and performs read-only D-Bus introspection on relevant KPP/browser services as a fallback. It always includes `com.lab126.kppbrowser`, `com.lab126.browser` and `com.lab126.appmgrd` from earlier project checks.

The metadata parser accepts standard `access type property` rows and the earlier project's pipe-delimited layout. The all-service scan is parsed even after a nonzero exit, so partial results are not discarded. Individual probes report status, output byte/line counts and parsed-row counts. The D-Bus fallback retains only LIPC-shaped method names. Raw stdout/stderr is temporary and discarded; property values are not requested because `-v` is never used. The paste omits PIDs, executable paths, command lines, page URLs, account identifiers, cookies, browser history and page text. It retains KPP binary names, sizes and SHA256 fingerprints.

The report is uploaded over HTTPS to `https://pasters.io/?expires=1w`. Anyone with the paste link can view it; a one-week expiry is requested, not guaranteed. The link and any remote-delete link are stored in Documents with owner-only file permissions. Only this sanitized report is uploaded; raw probe output and temporary files are never uploaded. If upload fails, the local report remains in Documents and can be transferred over USB.

Historical references used to repair the failed inventory:
- [Earlier project per-service browser diagnostic](https://github.com/E-Abenson/royalroad-kindle-tools/commit/e1bd63af7589cd620f0b45862d3e27095225b22b), which queried `com.lab126.kppbrowser` and `com.lab126.browser` individually.
- [Earlier project read-only LIPC probe](https://github.com/E-Abenson/royalroad-kindle-tools/commit/336c4c1b36c27998f2f30983533572516c0bbc2).
- [K3Libre Kindle command reference](https://github.com/dpavlin/k3libre), which demonstrates `lipc-probe -l` and individual `lipc-probe SERVICE` queries.
- [OpenLIPC `lipc-probe` implementation](https://github.com/arkq/openlipc/blob/master/src/lipc-probe.c), which documents the `-a`/`-v` option distinction.
- [KindleModding LIPC overview](https://kindlemodding.org/kindle-apps-and-services/index.html), which documents service-owner lookup using the read-only D-Bus method.

The diagnostic does not use `lipc-probe -v`, write LIPC properties, emit events, invoke browser actions, execute JavaScript, enable D-Bus eavesdropping, inspect cookies/storage, change configuration, or make any other network request apart from submitting the sanitized report to Pasters.io.

## One-time KPP browser investigation — USB workflow

Run **RR-KPP-Bytecode-Export** once. It copies the unmodified `/app/KPPMainApp/js/KPPMainApp.js.hbc` to `/mnt/us/documents/KPPMainApp.js.hbc`, verifies its SHA256 and Hermes header, and writes the size/version/checksum to `KPP-Bytecode-Export.txt`. It does not modify the original application or upload the bundle.

Connect the Kindle to Windows and copy `KPPMainApp.js.hbc` from Documents. Run the supplied `KPP-One-Time-Disassembler-Windows.zip` helper beside the bundle. It uses Python 3.8+ already installed, fetches a pinned pure-Python Hermes disassembler source on first run, and needs no pip packages or compiler. It creates a focused `KPP-Interface-Findings.txt` plus the full local disassembly. The bundle and disassembly remain local.

## Update and cleanup

Open **KPM-Update-All** from the Kindle library. After a successful package upgrade, it runs the hidden cleanup helper and then refreshes `Kindle-Version-Report.txt`.

The cleanup queue is `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt`; its completed-item ledger is `RoyalRoadTools-Cleanup-Completed.txt`. Successful actions are removed from the queue; failed or unverifiable actions remain for the next Update All run. If a retired target still exists after being marked complete, the installer re-queues it.

The existing KPP-Comprehensive-Diagnostic launcher and report are intentionally not queued: they are the active test and its report destination. Older LIPC probes, uploaders and smoke-test artifacts remain queued for removal. The paste URL and remote-delete URL are retained locally until the paste is no longer needed; they must not be deleted before remote deletion is confirmed.

## Remaining browser investigation

The accepted format for `com.lab126.kppbrowser.invokeAction` remains unknown. The one-time Windows disassembly is intended to identify the real implementation path and argument handling before designing a safe, narrow live test. Do not send a guessed `invokeAction` payload.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA or other access-control bypasses. Full chapter collection and EPUB creation have not been implemented.
