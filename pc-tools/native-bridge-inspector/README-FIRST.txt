KPP NATIVE BRIDGE — COMPREHENSIVE OFFLINE INSPECTION
=====================================================

PURPOSE
-------
This expands the previous native inspection into one comprehensive static
analysis pass of the Kindle archive. It examines every ELF executable and
shared library present in KPP-Native-Bridge-Binaries.tar.gz.

The Windows helper now checks:
- ELF architecture, sections and file inventory;
- full and dynamic symbol tables, including browser/bridge-related methods;
- imports and relocation entries that refer to relevant methods;
- selected embedded browser, WebView, JavaScript and LIPC strings;
- disassembly of named relevant native functions;
- code locations that appear to reference marker strings, including nearby
  instructions so AArch64 ADRP/ADD/LDR sequences can be reviewed.

IMPORTANT: this is a deeper offline analysis, not another live Kindle test.
You can reuse the KPP-Native-Bridge-Binaries.tar.gz archive already copied to
your PC. You do NOT need to rerun the Kindle export for this improved helper.

SAFETY / PRIVACY
----------------
It does NOT:
- execute or modify the Kindle binaries;
- connect to the Kindle;
- send LIPC writes, events or browser actions;
- inspect browser memory, cookies, history, page text or page source;
- connect to the internet, upload files, or contact Pasters.io;
- attempt to bypass a website challenge or access restriction.

The disassembler (Capstone 5.0.9) is bundled in this ZIP. It is verified by
SHA256 and unpacked locally when the helper runs. No pip install, compiler,
administrator rights, global Python installation change or network access
is required on your PC.

WINDOWS STEPS
-------------
1. Extract this ZIP into a folder on your Windows 10/11 64-bit PC.
2. Put your existing KPP-Native-Bridge-Binaries.tar.gz in that same folder.
3. Drag KPP-Native-Bridge-Binaries.tar.gz onto
   Run-KPP-Native-Inspection.bat.
4. The helper uses Python 3.8+ already installed on the PC.
5. It creates KPP-Native-Bridge-Findings.txt beside the archive.
6. Attach only KPP-Native-Bridge-Findings.txt in the ChatGPT conversation.

OUTPUT
------
One report: KPP-Native-Bridge-Findings.txt

The report includes all ELF files found in the supplied archive, subject to
the documented size limits, and disassembly/reference candidates for supported
architectures. The complete binaries and any unfiltered data remain on your PC.

INTERPRETATION
--------------
A named function is disassembled only when the ELF contains a usable function
symbol. A code reference is a static address-pattern match. AArch64 ADRP page
matches are candidates and must be read with the nearby ADD/LDR instructions.
Static analysis can miss indirect references, stripped functions, runtime-
generated code, and data-flow spanning multiple instructions or libraries.

A string, symbol or disassembly lead is not proof that an external method is
callable, that its arguments are known, or that it is safe to invoke. No
invokeAction payload is guessed or sent. Any later live check must be based on
a confirmed implementation and a verified read-only contract.

SCOPE LIMIT
-----------
The helper can inspect every ELF file that is already in the archive. It
cannot analyse a shared library that the earlier Kindle exporter did not
include. The report explicitly lists how many ELF files were inspected, so
we can see whether the original export included more than the main executable.
