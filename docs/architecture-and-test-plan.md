# Architecture and staged test plan

## Goal

Use the Kindle's own built-in browser session to retrieve Royal Road pages that the user can open normally, validate completeness, and eventually build one offline EPUB. Avoid manual chapter-by-chapter copying.

## Confirmed device facts

- Kindle: 10th generation; exact model variant not yet identified.
- Firmware last reported: 5.18.1.1.1; refresh with the on-device version report.
- SpringBoard jailbreak completed; KPM works.
- The built-in Kindle browser can open Royal Road chapters.
- A separate Kindle `curl` request to Royal Road returned HTTP 403 with Cloudflare challenge markers.
- `com.lab126.kppbrowser.getLastOpenPage` is readable.
- `com.lab126.kppbrowser.invokeAction` exists as a write-only string property.
- The LIPC owner was identified as `KPPMainApp`, executable `/app/bin/KPPMainAppV2`.
- The accepted `invokeAction` string format remains unknown. No action payload has been sent.

## Current tools

The KPM package installs one pending **RR-KPP-Bundle-Scan** scriptlet and its manual uploader, plus KPM update, KOReader plugin repair, version-report and one-time cleanup launchers. The older smoke/LIPC test scripts, test bookmarklet and helpers, and KOReader diagnostics launcher have been retired.

**KindleBatchPrepareFix remains on purpose.** It repairs/reinstalls the separate KOReader Kindle Batch Preparation plugin from the bundled local Lua source. It is a manual utility, not a background service; it does not belong to the retired browser-test group.

## Browser action discovery

The KPP bundle scanner reads the installed Hermes JavaScript bundle and native KPP executable as data. It filters for a narrow set of browser/LIPC action strings and redacts URL-like content. It does not execute the app code, contact the browser, navigate, refresh, or send `invokeAction`.

The next step is to inspect those filtered strings and, only if they reveal an actual call site or documented action schema, design a harmless test. Do not guess the action payload.

## Future stages — only after ordinary access is demonstrated

1. Test retrieval of a small number of chapter pages that are already accessible to the user.
2. Stop on a challenge, access denial, unexpected redirect, or incomplete page; do not retry around access controls.
3. Only after reliable ordinary retrieval, design a local collector with chapter order, progress, storage checks and EPUB validation.

Do not attempt CAPTCHA/proof-of-work bypasses. Keep the existing Apps Script receiver and EPUB builder separate and unchanged.

## Cleanup and versions

**RoyalRoadTools-Cleanup** removes finished test files and their old browser bookmark, after backup and verification. It preserves the KOReader plugin and its repair utility.

**RoyalRoadTools-Version-Info** writes a version inventory document on the Kindle, including device firmware, KPM and package versions, KOReader revision when available, and fingerprints of installed plugin code. Reopen it after updates.
