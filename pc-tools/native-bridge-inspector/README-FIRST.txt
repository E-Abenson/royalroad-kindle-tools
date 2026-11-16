KPP NATIVE BRIDGE — COMPREHENSIVE OFFLINE INSPECTION
=====================================================

PURPOSE
-------
This is one comprehensive, read-only collection and static-analysis pass of
the native code currently mapped by the Kindle's running KPP browser process.
It is designed to avoid a long series of small device tests.

KINDLE — ONE EXPORT
-------------------
1. Open the Kindle's built-in browser and leave it open.
2. Run the manual launcher named KPP-Native-Bridge-Export once.
3. The launcher copies KPPMainAppV2 and every readable ELF file found in a
   file-backed executable mapping of the running KPPMainApp process.
4. Library selection is based on ELF contents and executable mappings, NOT
   names. Generic names such as libcore.so or libgraphics.so are included.
5. Repeated mappings of the same file are deduplicated by SHA256.
6. Copy KPP-Native-Bridge-Binaries.tar.gz from Kindle Documents to Windows.

The archive has explicit safety caps: 128 ELF files, 120 MB per file, and
400 MB total uncompressed. The exporter writes a separate
KPP-Native-Bridge-Export.txt summary with the number of mapped candidates,
exported files, duplicates and skipped items.

The archive includes only unchanged file-backed ELF binaries. It does not
include raw process maps, original paths, PIDs, process memory, URLs, page
text, cookies, browser history, command lines or runtime property values.
Nothing is executed, changed or uploaded.

WINDOWS — ONE ANALYSIS
----------------------
1. Extract this complete ZIP into a folder on Windows 10/11 64-bit.
2. Put KPP-Native-Bridge-Binaries.tar.gz in that folder.
3. Drag the archive onto Run-KPP-Native-Inspection.bat.
4. Python 3.8+ must already be installed. No compiler or administrator rights
   are needed.
5. Progress is printed live: archive loading, batch number, current ELF file,
   named-function disassembly, and ARM/Thumb reference-scan progress.
6. Results are checkpointed after each completed ELF. If the command window is
   closed or the run is interrupted, launch the same BAT again with the same
   archive; completed files are reused automatically. The checkpoint folder
   is removed after the final report is successfully written.
7. The verified Capstone wheel is bundled. The helper accepts compatible
   Capstone 5.x patch versions, including 5.0.7 and 5.0.9, and records the
   version actually used. No PyPI download or pip installation is required.
8. Attach KPP-Native-Bridge-Findings.txt here. Also attach
   KPP-Native-Bridge-Export.txt if the report still lists only one ELF or
   reports skipped files.

OUTPUT
------
One findings report: KPP-Native-Bridge-Findings.txt
Temporary resume data: KPP-Native-Bridge-Checkpoint-<archive-sha-prefix>
(The checkpoint folder is automatically removed when the final report is saved.)

The report includes:
- ELF architecture, section, symbol, import/export and relocation inventories;
- prioritized browser, navigation, WebView, JavaScript and LIPC symbols/strings;
- disassembly of named browser/bridge functions where usable symbols exist;
- ARM32 scans in both ARM and Thumb modes;
- static string-reference candidates and nearby instructions;
- exact browser/bridge import-to-definition matches across the supplied ELF
  files, showing which library defines a method imported by another file.

The complete binaries and all unfiltered content remain on the PC. The helper
makes no network connections and saves only the local text findings report.

INTERPRETATION
--------------
A named function is disassembled only when a usable function symbol resolves
to executable code. A cross-library link requires an exact symbol-name match
between an import and a definition. Static address references are candidates,
not proof of runtime calls or data flow.

Static analysis can miss indirect references, stripped functions, runtime-
generated code, and data flow spanning several instructions or libraries.
A string or symbol is not proof that an external method is callable, that its
argument format is known, or that invoking it would be read-only.

SAFETY / PRIVACY
----------------
The workflow does NOT:
- execute or modify Kindle binaries;
- inspect process memory, page text, cookies, browser history or authenticated
  storage;
- send LIPC writes, events, browser actions or guessed invokeAction payloads;
- connect to the Kindle, internet, upload services or paste sites;
- attempt to bypass Cloudflare, CAPTCHA or any other access restriction.

Any later live check must be based on a confirmed implementation and a
verified read-only contract. A discovered function name alone is insufficient.
