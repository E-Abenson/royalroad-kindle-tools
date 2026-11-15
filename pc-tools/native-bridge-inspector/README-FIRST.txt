KPP NATIVE BRIDGE — OFFLINE INSPECTION
======================================

PURPOSE
-------
This is the next investigation after the already-completed Hermes bytecode
export/disassembly and the successful getLastOpenPage URL check.

It examines the native KPP executable and shared libraries mapped into the
running KPPMainApp process. It looks for native bridge, browser, WebView,
JavaScript, LIPC and related symbol/string references.

It does NOT:
- run or modify the Kindle binaries;
- send LIPC writes, events or browser actions;
- inspect browser memory, cookies, history, page text or page source;
- upload any binary or the original archive;
- attempt to bypass a website challenge or access restriction.

KINDLE STEP
-----------
1. Open the Kindle's built-in browser. Leave it open.
2. Run KPP-Native-Bridge-Export once from the Kindle library.
3. It creates KPP-Native-Bridge-Binaries.tar.gz in Kindle Documents.
   KPP-Native-Bridge-Export.txt records the file count and archive checksum.
   The archive contains unchanged copies of KPPMainAppV2 and selected shared
   libraries mapped by the running process.
4. Connect the Kindle to Windows and copy KPP-Native-Bridge-Binaries.tar.gz
   to a folder on the computer.

WINDOWS STEP
------------
1. Extract this ZIP to that same folder.
2. Drag KPP-Native-Bridge-Binaries.tar.gz onto
   Run-KPP-Native-Inspection.bat.
3. The helper uses Python 3.8+ already installed. It needs no pip packages,
   compiler, administrator rights or system-wide installation.
4. It creates KPP-Native-Bridge-Findings.txt and attempts to upload only
   that filtered text report to Pasters.io with one-week expiry requested.
5. Send the displayed paste link. If upload fails, send the local report.

PRIVACY
-------
Only the final filtered findings report is uploaded. The native executable,
shared libraries, archive, full strings and full symbol tables remain local.
The report includes ELF class/architecture, hashes, and selected browser/
bridge-related symbol or string markers. URLs, absolute paths, emails,
cookie/session/credential/account markers and runtime data are withheld.
Anyone with the paste link can view the report; expiry is requested, not
guaranteed.

INTERPRETATION
--------------
A marker string or symbol is a lead, not proof that an external method is
callable or that its argument format is known. No invokeAction payload is
guessed or sent. A follow-on live test will be designed only if the native
implementation provides a specific, documented read-only path.
