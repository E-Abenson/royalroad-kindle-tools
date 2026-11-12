# Kindle installation and maintenance

## Update and automatic cleanup

Open **KPM-Update-All** from the Kindle library. It refreshes configured package repositories and upgrades installed KPM packages.

As part of package installation or upgrade, the installer:
1. Installs the read-only KPP inspector, internal report uploader, internal bytecode exporter and maintenance tools.
2. Merges new entries from the repository cleanup queue template into the existing Kindle queue.
3. Runs **RoyalRoadTools-Cleanup** automatically.
4. Runs the KPP inspector and uploads only its sanitised text report to pasters.io with one-day expiry.
5. Exports the installed KPP Hermes bundle to the USB-visible Documents folder and verifies its SHA256.
6. Regenerates `Kindle-Version-Report.txt` automatically.

The queue is `/mnt/us/documents/RoyalRoadTools-Cleanup-Queue.txt`. Successful actions are removed from the queue and recorded in `RoyalRoadTools-Cleanup-Completed.txt`; failed actions remain queued.

## Version report

`/mnt/us/documents/Kindle-Version-Report.txt` is regenerated automatically after every KPM package installation/upgrade and after a successful Kindle Batch Preparation repair. There is no separate manual version-report launcher.

## Kindle Batch Preparation repair

Keep **KindleBatchPrepareFix** installed. It is an on-demand repair/reinstall utility for the separate KOReader Kindle Batch Preparation plugin, not a background service. Use it only if the plugin disappears, fails to load, or needs the validated menu fix reapplied.

## One-time KPP browser investigation — USB option

During package installation/upgrade, the internal exporter reads only `/app/KPPMainApp/js/KPPMainApp.js.hbc`, checks the Hermes magic/version and SHA256, then atomically writes a copy to:

`/mnt/us/documents/KPPMainApp.js.hbc`

The exported file is not hidden, is readable over USB, and has mode 644. The accompanying `KPP-Bytecode-Export.txt` records size, Hermes version, SHA256, and the exact transfer location. The previous hidden duplicate under `.rr-kpp-research` is removed only after the Documents copy is verified. The original application in `/app` is never changed.

### Windows disassembly

Download `KPP-One-Time-Disassembler-Windows.zip` from the latest project release and extract it. Copy `KPPMainApp.js.hbc` from Kindle Documents into that folder, beside `Run-KPP-Disassembly.bat`, then double-click the BAT file.

Requirements: Python 3.8+ already installed and internet access for the first run. No pip packages, compiler, administrator rights or system-wide installation are needed. The helper downloads a pinned MIT-licensed pure-Python version of hbctool to its own working folder, verifies the HBC header is version 84, disassembles locally, and writes `KPP-Interface-Findings.txt` plus the full HASM output. The Kindle binary and disassembly are never uploaded. See `pc-tools/kpp-disassembler/README-FIRST.txt`.

This is a one-time test. It does not test live JavaScript execution yet; it gives us the implementation details needed to design a safe, narrow live test. Repeat only after a material KPP application update.

## Privacy and safety

The inspector never runs LIPC commands, reads browser URLs/settings/cookies/history/database rows, sends LIPC writes/events, navigates, refreshes or executes JavaScript. The only pasters.io upload is the fixed-marker/file-path inspector text report, not the binary application file. A paste link can be read by anyone who obtains it.

The old full-system LIPC dump remains retired; broad service inventories can expose account/authentication values. Do not guess an `invokeAction` payload or try one against the live browser. Stop on access-denial or Cloudflare challenge responses; do not attempt CAPTCHA/proof-of-work bypasses.

## Active Kindle logs

- `/mnt/us/documents/RR-KPP-Interface-Inspector.log`
- `/mnt/us/documents/KPP-Bytecode-Export.txt`
- `/mnt/us/documents/RoyalRoadTools-Cleanup.log`
- `/mnt/us/documents/KPM-Update-All.log`
- `/mnt/us/documents/Kindle-Version-Report.txt`
