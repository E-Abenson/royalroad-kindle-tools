# Architecture and staged test plan

## Goal

Determine whether the Kindle's built-in KPP browser exposes a legitimate callable interface for JavaScript execution in the currently displayed page. Only after that is understood should a harmless live-page execution test be designed. Later, if ordinary page retrieval works, the project may build an offline EPUB tool.

## Confirmed device facts

- Kindle firmware last reported: 5.18.1.1.1.
- SpringBoard jailbreak completed; KPM works.
- Built-in browser can open Royal Road chapters.
- A separate Kindle curl request to Royal Road returned HTTP 403 with Cloudflare challenge markers.
- `com.lab126.kppbrowser.getLastOpenPage` is readable.
- `com.lab126.kppbrowser.invokeAction` exists as a write-only string property.
- The accepted `invokeAction` format remains unknown; no action payload has been sent.

## Current Kindle automation

At KPM installation/upgrade, the package automatically:
1. Runs the static read-only KPP interface inspector.
2. Uploads only the sanitised marker/path report to pasters.io with a one-day expiry; the paste URL is placed at the top of the local log.
3. Copies the original Hermes bundle without modification to `/mnt/us/documents/KPPMainApp.js.hbc` and verifies its size, HBC header version and SHA256.
4. Replaces the Kindle software version report automatically.

The bundle is not uploaded. It is placed in Documents for the one-time USB workflow below. The old hidden duplicate is removed only after the new visible copy is verified.

## One-time bytecode investigation — Option C

The PC helper is in `pc-tools/kpp-disassembler` and is released as `KPP-One-Time-Disassembler-Windows.zip`.

- Connect Kindle by USB and copy `KPPMainApp.js.hbc` from Documents into the extracted Windows helper folder.
- Double-click `Run-KPP-Disassembly.bat`.
- Requires Python 3.8+ already installed and internet for the first run. No pip modules or compiler are required.
- The helper downloads a pinned MIT-licensed hbctool source archive and uses its pure-Python HBC v84 parser/disassembler.
- It checks the 8-byte HBC magic and the 32-bit bytecode version before parsing.
- It writes the full local disassembly (`metadata.json`, `string.json`, `instruction.hasm`) and a targeted `KPP-Interface-Findings.txt` report listing browser markers and functions referencing them.
- It never executes the bundle, changes the original, patches the application, or uploads the file/output.

This is a one-time investigation, not a recurring user task. Repeat only after a material KPP application update.

## KPP interface inspection

The previous read-only investigation found service `com.lab126.kppbrowser`, with write-only string property `invokeAction`. Its accepted format remains unknown.

Static markers only show that a text string occurs in a file. The bytecode disassembly should let us trace references and call sites for `invokeAction`, `runJavaScript`, `evaluateJavaScript`, `postMessage`, navigation functions and related bridge methods. It still does not prove an external LIPC call is supported.

Do not write to `invokeAction`, change LIPC properties or send events until a specific action schema is established from reliable implementation evidence. Do not try guessed JavaScript-injection payloads.

## Future live test

After reviewing the disassembly:
1. Identify one well-supported callable route and its exact argument contract.
2. Design a minimal harmless test on a page the user is already entitled to view.
3. Record success/failure without reading page contents, credentials or browser databases.
4. Do not proceed with collection if the browser denies access, shows a Cloudflare challenge, or returns incomplete content. Do not attempt CAPTCHA/proof-of-work bypasses.

Only after ordinary access and JavaScript integration are demonstrated should we design chapter collection, ordering, progress, storage checks and EPUB validation.

## Cleanup and versions

The cleanup queue retires old smoke-test scripts/logs, old bundle-scan artifacts, the previous broad LIPC probe/uploader and saved links, and the exact old test bookmark. It preserves the current read-only inspector, KPM updater, automatic version reporting, KOReader and the Kindle Batch Preparation repair utility.

`Kindle-Version-Report.txt` is regenerated automatically during package installation/upgrade and after a successful plugin repair. No separate manual version-report launcher is required.
