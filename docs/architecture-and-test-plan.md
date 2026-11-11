# Architecture and staged test plan

## Goal

Use the Kindle's own built-in browser session to retrieve Royal Road pages that the user can open normally, validate completeness, and eventually build one offline EPUB. Avoid manual chapter-by-chapter copying.

## Confirmed device facts

- Kindle: 10th generation; exact model variant not yet identified.
- Firmware last reported: 5.18.1.1.1; refresh with the on-device version report.
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A separate Kindle curl request to Royal Road returned HTTP 403 with Cloudflare challenge markers.
- com.lab126.kppbrowser.getLastOpenPage is readable.
- com.lab126.kppbrowser.invokeAction exists as a write-only string property.
- The LIPC owner was identified as KPPMainApp, executable /app/bin/KPPMainAppV2.
- The accepted invokeAction string format remains unknown. No action payload has been sent.

## Current tools

The KPM package installs **RR-KPP-Interface-Inspector**, an internal Hermes-bundle export helper, an internal pasters.io report uploader, KOReader plugin repair, automatic version reporting, KPM update and persistent cleanup utilities.

**RR-KPP-Interface-Inspector** performs a narrow static scan of selected system application directories. It checks candidate KPP/browser/WebKit/Chromium/Juno files for fixed interface markers such as `invokeAction`, JavaScript evaluation method names, navigation method names and debugging symbols. It prints only candidate file paths and marker names, never raw string contents. It does not run any LIPC command, read browser settings or URLs, inspect browser databases, set properties, send events, navigate, refresh, execute JavaScript, or use the network. During each KPM package installation/upgrade, the installer runs the inspector automatically, saves a private local copy of `/app/KPPMainApp/js/KPPMainApp.js.hbc` under `/mnt/us/documents/.rr-kpp-research/`, and uploads only the sanitised text report to pasters.io with a one-day expiry. The returned link is placed at the top of the local inspector log. The Hermes bytecode bundle is never uploaded to pasters.io. This release exports it locally only; remote disassembly still requires a private authenticated receiver.

**Important:** The previous full `lipc-probe -a -v` inventory is retired. Broad LIPC dumps may expose authentication and account values from unrelated services. Do not run or share a full-system dump. Its old launcher, local log, uploader and saved paste links are queued for cleanup.

**KindleBatchPrepareFix remains on purpose.** It repairs/reinstalls the separate KOReader Kindle Batch Preparation plugin from the bundled local Lua source. It is a manual utility, not a background service; it does not belong to the retired browser-test group.

## KPP interface inspection

The previous read-only investigation found the browser service `com.lab126.kppbrowser`, with a write-only string property named `invokeAction`. Its accepted action format is not known.

The installer automatically runs **RR-KPP-Interface-Inspector** and writes `/mnt/us/documents/RR-KPP-Interface-Inspector.log`. The private Hermes bundle copy is refreshed at the same time. Static markers are leads only: a string embedded in an application file does not prove the corresponding method is callable or that it accepts a particular payload.

Do not write to `invokeAction`, change LIPC properties, or send events until a specific action schema is established from reliable implementation evidence. Do not try guessed JavaScript-injection payloads.

## Future stages — only after ordinary access is demonstrated

1. Test retrieval of a small number of chapter pages that are already accessible to the user.
2. Stop on a challenge, access denial, unexpected redirect, or incomplete page; do not retry around access controls.
3. Only after reliable ordinary retrieval, design a local collector with chapter order, progress, storage checks and EPUB validation.

Do not attempt CAPTCHA/proof-of-work bypasses. Keep the existing Apps Script receiver and EPUB builder separate and unchanged.

## Cleanup and versions

The cleanup queue removes retired smoke-test scripts and logs, old KPP bundle-scan scripts/logs/paste links, the previous broad LIPC probe and uploader, their logs and saved delete links, and the exact old browser bookmark after backup and verification. It preserves the new KPP interface inspector, the KOReader plugin and its repair utility.

`Kindle-Version-Report.txt` is automatically regenerated during package installation/upgrade and after a successful Kindle Batch Preparation repair. It includes device firmware, KPM and package versions, KOReader revision when available, plugin fingerprints, and the local KPP bytecode export status/checksum. There is no separate manual version-report launcher.
