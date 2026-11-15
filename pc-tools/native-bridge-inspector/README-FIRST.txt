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
- make any network connection or upload any file;
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
4. It creates KPP-Native-Bridge-Findings.txt in the same folder as the archive.
5. Attach KPP-Native-Bridge-Findings.txt directly in the ChatGPT conversation.

PRIVACY
-------
Everything stays on your PC. The helper performs offline ELF header,
symbol-table and selected embedded-string inspection. It does not upload
the binary archive, executable, shared libraries, full strings, findings
or any other file. It does not contact Pasters.io or any other service.
The findings report contains ELF class/architecture, file hashes, and
selected browser/bridge-related symbol or string markers. URLs, absolute
paths, emails, cookie/session/credential/account markers and runtime data
are withheld.

INTERPRETATION
--------------
A marker string or symbol is a lead, not proof that an external method is
callable or that its argument format is known. No invokeAction payload is
guessed or sent. A follow-on live test will be designed only if the native
implementation provides a specific, documented read-only path.
