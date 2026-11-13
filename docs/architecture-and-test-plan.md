# Architecture and staged test plan

## Goal

Use the Kindle's own built-in browser session to retrieve pages the user can open normally, validate completeness, and eventually build one offline EPUB. Avoid manual chapter-by-chapter copying.

## Confirmed device facts

- Kindle: 10th generation; exact model variant not yet identified.
- Firmware last reported: 5.18.1.1.1.
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A separate Kindle curl request to Royal Road returned HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser.getLastOpenPage is readable.
- com.lab126.kppbrowser.invokeAction exists as a write-only string property.
- The LIPC owner was identified as KPPMainApp, executable /app/bin/KPPMainAppV2.
- The accepted invokeAction string format remains unknown. No action payload has been sent.

## Current tools

- **KPP-Comprehensive-Diagnostic** — one manual, read-only snapshot of relevant processes, LIPC service names, individually queried property names/type/access metadata, read-only owner-process mappings, and KPP binary fingerprints. It then uploads only the sanitized report to Pasters.io. The paste link and any delete link are retained locally.
- **RR-KPP-Bytecode-Export** — one-time manual export of an unmodified KPP Hermes bundle to the USB-visible Kindle Documents folder.
- **KPM-Update-All** — manually refreshes and upgrades KPM packages, then automatically runs the private cleanup helper and refreshes the version report.
- **KindleBatchPrepareFix** — manual repair/reinstall utility for the KOReader Kindle Batch Preparation plugin.

## One-run comprehensive device diagnostic

Open the built-in KPP browser to an ordinary page the user can access, then launch **KPP-Comprehensive-Diagnostic** once from the Kindle library. It creates `/mnt/us/documents/KPP-Comprehensive-Diagnostic.txt` and uploads the sanitized report to Pasters.io.

The prior device run showed that `lipc-probe -a` exited with status 1. The revised diagnostic now preserves and parses its partial stdout even when the exit status is nonzero. It first runs `lipc-probe -l` to discover KPP/browser-related names, then runs the non-verbose all-service scan (`-a`, never `-v`), individual targeted probes, and read-only D-Bus introspection on relevant KPP/browser services. The exact previously used services (`com.lab126.kppbrowser`, `com.lab126.browser` and `com.lab126.appmgrd`) remain explicit fallbacks.

The metadata parser accepts standard `access type property` rows and the earlier project's pipe-delimited layout. It recovers rows from partial all-service stdout, summarizes individual probe status/output sizes/parsed-row counts, and retains LIPC-shaped method names from read-only D-Bus introspection when available. Raw output and property values are discarded; `-v` is never used. Service-owner lookups record process names but not PIDs or executable paths. Relevant processes are identified by name only; command lines and PIDs are omitted. KPP executable/Hermes bundle names, sizes and SHA256 fingerprints are retained.

The report does not read the current page at all. It excludes URLs, hostnames, page paths, query strings, fragments, account identifiers, cookies, history and page text. It also excludes raw command output. The single network operation is an HTTPS POST of the sanitized report to `https://pasters.io/?expires=1w`. Anyone with the resulting link can view it; one-week expiry is requested, not guaranteed. The paste link and remote-delete link, if returned, are stored locally with restricted file permissions. If upload fails, the local report remains available for USB transfer.

Historical implementations used to repair the failed inventory:
- [Earlier project per-service browser diagnostic](https://github.com/E-Abenson/royalroad-kindle-tools/commit/e1bd63af7589cd620f0b45862d3e27095225b22b), which queried the browser services individually.
- [Earlier project read-only LIPC probe](https://github.com/E-Abenson/royalroad-kindle-tools/commit/336c4c1b36c27998f2f30983533572516c0bbc2).
- [K3Libre Kindle command reference](https://github.com/dpavlin/k3libre), demonstrating `lipc-probe -l` and individual service queries.
- [OpenLIPC `lipc-probe` source](https://github.com/arkq/openlipc/blob/master/src/lipc-probe.c), documenting all-service scanning and the separate value-display flag.
- [KindleModding LIPC overview](https://kindlemodding.org/kindle-apps-and-services/index.html), documenting read-only service-owner discovery.

The diagnostic runs `lipc-probe -a` without `-v`, keeps partial output on nonzero exit, probes selected services individually, and attempts read-only D-Bus introspection. No LIPC properties are written, no events are sent, no browser action or JavaScript is attempted, no D-Bus monitor/eavesdropping policy is enabled, and no app/configuration files are changed. This remains one consolidated manual test, not multiple separate launchers.

## One-time Windows disassembly

Run **RR-KPP-Bytecode-Export** once. It copies the unmodified Hermes bundle to the USB-visible Kindle Documents folder, verifies its SHA256 and header, and writes the size/version/checksum to `KPP-Bytecode-Export.txt`. It does not modify the original application or upload the bundle.

Connect the Kindle to Windows and copy `KPPMainApp.js.hbc` from Documents. Run the supplied Windows helper beside the bundle. It uses Python 3.8+ already installed, downloads a pinned pure-Python Hermes disassembler source on first run, and needs no pip packages or compiler. It creates a focused findings report plus the full local disassembly. The bundle and disassembly remain local.

## Browser investigation safety

The accepted format for `com.lab126.kppbrowser.invokeAction` is unknown. Do not write to it, change LIPC properties, send events, or try guessed payloads until a specific action schema is established from reliable implementation evidence.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA/proof-of-work bypasses or other access-control circumvention.

## Future stages

1. Review the focused findings report and the new live LIPC metadata.
2. Design a minimal live test only when a supported method and argument format are established.
3. Test a small number of pages already accessible to the user.
4. Stop on challenge, access denial, unexpected redirect or incomplete page.
5. Only after reliable ordinary retrieval, design a local collector and EPUB validation.

Keep the existing Apps Script receiver and EPUB builder separate and unchanged.

## Cleanup and versions

The cleanup queue removes retired smoke-test scripts/logs, old KPP bundle-scan tools, the previous broad LIPC probe/uploader, and the superseded Kindle-side interface inspector/uploader, including their local reports and share-link metadata.

The active **KPP-Comprehensive-Diagnostic** launcher and report are not queued while the test is pending. The generated paste URL and delete URL are also retained until remote deletion is confirmed. After the report is reviewed, these temporary artifacts can be queued in a subsequent package update. KPM-Update-All runs the private cleanup helper automatically after a successful package upgrade; there is no manual cleanup launcher. The cleaner re-queues listed retired targets that still exist, even if an old completion ledger says they were removed.

`Kindle-Version-Report.txt` is regenerated automatically after successful Update All and successful plugin repair.
