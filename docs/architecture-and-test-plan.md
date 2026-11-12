# Architecture and staged test plan

## Goal

Use the Kindle's own built-in browser session to retrieve Royal Road pages that the user can open normally, validate completeness, and eventually build one offline EPUB. Avoid manual chapter-by-chapter copying.

## Confirmed device facts

- Kindle: 10th generation; exact model variant not yet identified.
- Firmware last reported: 5.18.1.1.1; the version report is refreshed automatically after Update All.
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A separate Kindle curl request to Royal Road returned HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser.getLastOpenPage is readable.
- com.lab126.kppbrowser.invokeAction exists as a write-only string property.
- The LIPC owner was identified as KPPMainApp, executable /app/bin/KPPMainAppV2.
- The accepted invokeAction string format remains unknown. No action payload has been sent.

## Current tools

The KPM package installs manual launchers for **RR-KPP-Interface-Inspector**, optional pasters.io report upload, one-time USB Hermes-bundle export, KPM updates, and KOReader plugin repair. The cleanup runner is installed privately and is invoked by **KPM-Update-All** after a successful package upgrade. The version report is generated automatically after Update All and successful plugin repair; it has no manual launcher.

**RR-KPP-Interface-Inspector** performs a narrow static scan of selected system application directories. It checks candidate KPP/browser/WebKit/Chromium/Juno files for fixed interface markers such as `invokeAction`, JavaScript evaluation method names, navigation method names and debugging symbols. It prints only candidate file paths and marker names, never raw string contents. It does not run any LIPC command, read browser settings or URLs, inspect browser databases, set properties, send events, navigate, refresh, execute JavaScript, or use the network. Run the inspector manually to create its local report. Run the bytecode exporter once to copy an unmodified version of `/app/KPPMainApp/js/KPPMainApp.js.hbc` to `/mnt/us/documents/KPPMainApp.js.hbc` for USB transfer. It verifies the SHA256 and Hermes header; it never uploads, executes, patches, or modifies the original. It removes the prior hidden duplicate only after the visible copy is verified. The optional uploader remains a separate manual launcher and sends only the sanitised text report to pasters.io with one-day expiry.

The one-time Windows helper in `pc-tools/kpp-disassembler` uses Python 3.8+ already installed, downloads a pinned pure-Python hbctool source snapshot once, and needs no pip packages or compiler. It creates a focused marker/function-reference report and the full local disassembly. The findings summary omits literal application strings; keep the full disassembly private.

**Important:** The previous full `lipc-probe -a -v` inventory is retired. Broad LIPC dumps may expose authentication and account values from unrelated services. Do not run or share a full-system dump. Its old launcher, local log, uploader and saved paste links are queued for cleanup.

**KindleBatchPrepareFix remains on purpose.** It repairs/reinstalls the separate KOReader Kindle Batch Preparation plugin from the bundled local Lua source. It is a manual utility, not a background service; it does not belong to the retired browser-test group.

## KPP interface inspection

The previous read-only investigation found the browser service `com.lab126.kppbrowser`, with a write-only string property named `invokeAction`. Its accepted action format is not known.

Run **RR-KPP-Interface-Inspector** manually to write `/mnt/us/documents/RR-KPP-Interface-Inspector.log`. Run the bytecode exporter once and the optional report uploader separately, only when needed. Static markers are leads only: a string embedded in an application file does not prove the corresponding method is callable or that it accepts a particular payload.

Do not write to `invokeAction`, change LIPC properties, or send events until a specific action schema is established from reliable implementation evidence. Do not try guessed JavaScript-injection payloads.

## Future stages — only after ordinary access is demonstrated

1. Test retrieval of a small number of chapter pages that are already accessible to the user.
2. Stop on a challenge, access denial, unexpected redirect, or incomplete page; do not retry around access controls.
3. Only after reliable ordinary retrieval, design a local collector with chapter order, progress, storage checks and EPUB validation.

Do not attempt CAPTCHA/proof-of-work bypasses. Keep the existing Apps Script receiver and EPUB builder separate and unchanged.

## Cleanup and versions

The cleanup queue removes retired smoke-test scripts and logs, old KPP bundle-scan scripts/logs/paste links, the previous broad LIPC probe and uploader, their logs and saved delete links, and the exact old browser bookmark after backup and verification. The cleanup runner is hidden under `.royalroadtools` and is invoked automatically only by **KPM-Update-All** after a successful upgrade; there is no manual cleanup launcher. It preserves the current manual research tools, the KOReader plugin and its repair utility.

`Kindle-Version-Report.txt` is regenerated automatically after successful Update All and after successful plugin repair. Its helper is stored privately; there is no manual report launcher. It includes device firmware, KPM and package versions, KOReader revision when available, plugin fingerprints, and the USB-visible KPP bytecode export status/checksum.
