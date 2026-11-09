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

The KPM package installs **RR-LIPC-READONLY-PROBE**, its optional manually confirmed uploader, KPM update, KOReader plugin repair, version-report and persistent cleanup utilities.

**RR-LIPC-READONLY-PROBE** runs lipc-probe -a -v to inventory registered LIPC services and takes a read-only snapshot of KPP-related processes. It does not set properties, send events, or interact with the browser.

**RR-LIPC-READONLY-UPLOAD** is a separate, optional script. It uploads only the saved probe log to pasters.io after an explicit typed confirmation when interactive input is available; when the Kindle launcher has no keyboard input, opening this dedicated uploader starts the transfer. It requests one-week expiry and stores the paste URL and remote-delete URL privately on the Kindle. Review the diagnostic first: the paste is accessible to anyone with its link.

**KindleBatchPrepareFix remains on purpose.** It repairs/reinstalls the separate KOReader Kindle Batch Preparation plugin from the bundled local Lua source. It is a manual utility, not a background service; it does not belong to the retired browser-test group.

## LIPC service discovery

Review /mnt/us/documents/RR-LIPC-READONLY-PROBE.log for the com.lab126.kppbrowser service and its exposed properties, plus the KPP process snapshot. If the service is not listed, do not infer that an unlisted method exists.

Do not write to invokeAction, change LIPC properties, or send events until a specific action schema is established from reliable evidence.

## Cleanup queue design

Cleanup targets are maintained in kpm/package/scriptlets/RoyalRoadTools-Cleanup-Queue.txt. Each line is a typed, narrowly scoped task:

- DOC|filename — exact file under /mnt/us/documents
- DOCGLOB|pattern — matching files directly under /mnt/us/documents, with no subdirectory traversal
- PKG|relative/path — exact file under the installed package cache
- PKGDIR|relative/path — remove a directory only if empty
- REMOTE_DELETE|filename — use a saved pasters.io deletion URL stored in the documents directory
- BOOKMARK|Royal Road Session Test — remove only the exact project-installed JavaScript bookmark

During package installation or upgrade, the installer merges any new template entries into the device queue. It does not overwrite pending items and skips entries in the completed-item ledger. The cleaner removes each queue entry only after its action is confirmed successful; failures and unverifiable results remain queued for retry. The cleaner itself remains installed. This makes future cleanup additions a one-line change to the repository template.

## Future stages — only after ordinary access is demonstrated

1. Test retrieval of a small number of chapter pages that are already accessible to the user.
2. Stop on a challenge, access denial, unexpected redirect, or incomplete page; do not retry around access controls.
3. Only after reliable ordinary retrieval, design a local collector with chapter order, progress, storage checks and EPUB validation.

Do not attempt CAPTCHA/proof-of-work bypasses. Keep the existing Apps Script receiver and EPUB builder separate and unchanged.

## Cleanup and versions

The cleanup queue removes the retired smoke-test scripts, old KPP bundle scan/uploader, their logs and temporary links, package-cache copies, and the exact old browser bookmark after backup and verification. It preserves the new LIPC probe, the KOReader plugin and its repair utility.

**RoyalRoadTools-Version-Info** writes a version inventory document on the Kindle, including device firmware, KPM and package versions, KOReader revision when available, and fingerprints of installed plugin code. Reopen it after updates.
