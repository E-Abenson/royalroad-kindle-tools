KINDLE KPP — ONE-TIME DISASSEMBLY TOOL
======================================

WHAT THIS DOES
--------------
It reads the Kindle's copied KPPMainApp.js.hbc Hermes bundle, checks
that it is HBC version 84, disassembles it locally, and creates a focused
report showing where browser-interface marker strings are referenced.

It does NOT execute the Kindle application, modify the bundle, patch
the Kindle, connect to the Kindle, or upload any file.

REQUIREMENTS
------------
- Windows 10/11
- Python 3.8 or later already installed
- Internet connection for the first run (to download the pinned
  pure-Python hbctool source from GitHub)
- No pip install, compiler, administrator rights, or Python packages

ONE-TIME STEPS
--------------
1. Update Royal Road Kindle Tools on your Kindle using KPM-Update-All.
2. The installer automatically places KPPMainApp.js.hbc in Kindle
   Documents and writes KPP-Bytecode-Export.txt with its checksum.
3. Connect the Kindle to Windows using USB.
4. Open the Kindle drive, then its Documents folder.
5. Copy KPPMainApp.js.hbc into this folder, beside this README and
   Run-KPP-Disassembly.bat.
6. Double-click Run-KPP-Disassembly.bat.
7. The tool checks the file, downloads hbctool source once, and performs
   the disassembly. A findings report and full local output folder are
   created here.

If the file is not beside the BAT file, a file picker will open.
You can also drag KPPMainApp.js.hbc onto the BAT file.

OUTPUT
------
KPPMainApp-disassembly/
  metadata.json
  string.json
  instruction.hasm
  KPP-Interface-Findings.txt

The findings report lists the marker strings and functions that refer
to them. The full instruction.hasm file provides the surrounding bytecode
instructions for deeper manual review.

PRIVACY
-------
The Kindle application bundle is downloaded from the Kindle to your
own computer by USB. It is never uploaded to GitHub, pasters.io, or
any other service. The hbctool source itself is downloaded from GitHub.
The disassembly and findings remain in this folder on your PC.

TOOL SOURCE
-----------
Hermes disassembler: https://github.com/Baba01hacker666/HBC-Tool
Pinned source commit: 873aa1b1a53c9d28dbec28e1a427916255980879
The disassembler is MIT-licensed. Its optional C++ acceleration is not
used; the pure-Python mode is sufficient and needs no compiler.

IMPORTANT
---------
This is a one-time static analysis step. It does not test JavaScript
execution in the live browser yet. It helps us discover the code path
and argument handling before designing a safe, minimal live test.
