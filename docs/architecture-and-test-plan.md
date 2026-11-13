# Architecture and staged test plan

## Goal

Use the Kindle's own built-in browser session to retrieve pages the user can open normally, validate completeness, and eventually build one offline EPUB. Avoid manual chapter-by-chapter copying.

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

The KPM package keeps only the tools needed for the current investigation stage:

- **RR-KPP-Bytecode-Export** — a one-time manual launcher that copies an unmodified KPP Hermes bundle to the USB-visible Kindle Documents folder.
- **KPM-Update-All** — manually refreshes and upgrades KPM packages, then automatically runs the private cleanup helper and refreshes the version report.
- **KindleBatchPrepareFix** — manual repair/reinstall utility for the KOReader Kindle Batch Preparation plugin.

The earlier Kindle-side KPP interface inspector and Pasters.io uploader are retired. They are not installed by current package releases, and the cleanup queue removes old launchers, reports and local upload metadata. The bytecode exporter is kept because the next stage needs its output.

## One-time Windows disassembly

Run **RR-KPP-Bytecode-Export** once. It copies the unmodified `/app/KPPMainApp/js/KPPMainApp.js.hbc` to `/mnt/us/documents/KPPMainApp.js.hbc`, verifies its SHA256 and Hermes header, and writes the size/version/checksum to `KPP-Bytecode-Export.txt`. It does not modify the original application or upload the bundle.

Connect the Kindle to Windows and copy `KPPMainApp.js.hbc` from Documents. Run the supplied `KPP-One-Time-Disassembler-Windows.zip` helper beside the bundle. It uses Python 3.8+ already installed, fetches a pinned pure-Python Hermes disassembler source on first run, and needs no pip packages or compiler. It creates a focused `KPP-Interface-Findings.txt` plus the full local disassembly. The bundle and disassembly remain local.

The findings report is intended to identify the actual browser-interface implementation path and argument handling. It does not itself prove that a live action is safe or callable.

## Browser investigation safety

The accepted format for `com.lab126.kppbrowser.invokeAction` is unknown. Do not write to it, change LIPC properties, send events, or try guessed payloads until a specific action schema is established from reliable implementation evidence.

Stop on access-denial or Cloudflare challenge responses. Do not attempt CAPTCHA/proof-of-work bypasses or other access-control circumvention.

## Future stages — only after ordinary access is demonstrated

1. Review the focused findings report for relevant browser-interface implementation details.
2. Design a minimal, read-only or otherwise harmless live test only when a supported method and argument format are established.
3. Test retrieval of a small number of chapter pages that are already accessible to the user.
4. Stop on a challenge, access denial, unexpected redirect, or incomplete page; do not retry around access controls.
5. Only after reliable ordinary retrieval, design a local collector with chapter order, progress, storage checks and EPUB validation.

Keep the existing Apps Script receiver and EPUB builder separate and unchanged.

## Cleanup and versions

The cleanup queue removes retired smoke-test scripts/logs, old KPP bundle-scan tools, the previous broad LIPC probe/uploader, and the superseded Kindle-side interface inspector/uploader, including their local reports and share-link metadata. It also removes the exact old browser test bookmark after backup and verification.

The cleanup runner is hidden under `.royalroadtools` and is invoked automatically only by **KPM-Update-All** after a successful package upgrade; there is no manual cleanup launcher. It re-queues any listed retired target that still exists, even if the completion ledger previously marked it done. It preserves the one-time USB bytecode export, the KPP bundle needed by the next test, the KOReader plugin and its repair utility.

`Kindle-Version-Report.txt` is regenerated automatically after successful Update All and successful plugin repair. Its helper is stored privately; there is no manual report launcher.
