KPP NATIVE BRIDGE — SELECTIVE OFFLINE INSPECTION
==================================================

PURPOSE
-------
This is one read-only inspection of the Kindle's exported KPP browser native
code. It avoids spending hours disassembling unrelated system libraries.

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
5. The first pass inventories symbols, imports/exports, relocations and
   relevant strings in EVERY exported ELF file. Specific bridge markers are
   prioritised over generic words such as browser or navigation.
6. The second pass selects at most 12 files with the strongest, specific
   browser/bridge evidence for named-function disassembly. Generic words such
   as "browser" alone do not qualify.
7. Static code-reference scans run on at most 8 selected files. Each ARM or
   Thumb pass is capped at 4 MB (so an ARM32 file can receive up to 8 MB total).
   The disassembler uses bounded 256 KB chunks and can split a chunk further
   if Capstone reports memory pressure.
8. The command window shows the inventory count, candidate selection, current
   file, chunk progress, elapsed time and estimated remaining time.
9. Inventory is checkpointed after each ELF; code-reference scans are
   checkpointed after each chunk; completed per-file results are also saved.
   If interrupted, run the same BAT again with the same archive. Completed
   results and compatible prior scan checkpoints are reused automatically.
10. Version 0.1.112 reuses compatible v0.1.111 per-file and within-file
    chunk checkpoints for the same archive SHA256. It also reuses completed
    v0.1.110 per-file checkpoints; an interrupted v0.1.110 file restarts.
    If no compatible checkpoints exist, it begins with the inventory pass.
11. The verified Capstone wheel is bundled. No PyPI download or pip
    installation is required.
12. Attach KPP-Native-Bridge-Findings.txt here. Also attach
    KPP-Native-Bridge-Export.txt if the exporter reports skipped files.

OUTPUT
------
Findings report: KPP-Native-Bridge-Findings.txt
Checkpoint folder:
KPP-Native-Bridge-Checkpoint-<archive-sha-prefix>-<inspector-version>
(or a compatible older-version folder while resuming)

The checkpoint folder is removed only after the final report is written
successfully.

The report includes:
- architecture, executable-section and ELF inventory for every exported file;
- relevant symbols, imports/exports, relocations and marker strings;
- exact browser/bridge import-to-definition matches across the ELF files;
- named-function disassembly for the strongest candidates;
- bounded static address-reference candidates and nearby instructions.

The report explicitly lists how many files were inventoried, selected for
focused analysis and scanned for code references. Files not selected for
expensive disassembly remain represented in the inventory.

INTERPRETATION
--------------
A named function is disassembled only when a usable function symbol resolves
to executable code. A cross-library link requires an exact symbol-name match
between an import and a definition. Static address references are candidates,
not proof of runtime calls or data flow.

This is intentionally a selective analysis. It can miss code references in
later portions of a large executable section, stripped functions, indirect
references and runtime-generated code. The inventory still covers all
exported ELF files, but native disassembly is limited to the highest-scoring
candidates. If the report does not identify the relevant code, a subsequent
analysis can expand the selected set or increase the bounded scan budget using
the already-exported archive.

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
