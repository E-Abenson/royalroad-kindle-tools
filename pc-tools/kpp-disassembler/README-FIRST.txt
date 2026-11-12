KINDLE KPP — ONE-TIME DISASSEMBLY TOOL
======================================

WHAT THIS DOES
--------------
It reads the Kindle's copied KPPMainApp.js.hbc Hermes bundle, checks its
Hermes header, disassembles it locally, and creates a focused report showing
where browser-interface marker strings are referenced.

It does NOT execute the Kindle application, modify the bundle, patch the
Kindle, connect to the Kindle, or upload any file.

REQUIREMENTS
------------
- Windows 10/11
- Python 3.8 or later already installed
- Internet connection for the first run only
- No pip packages, compiler, administrator rights, or system-wide install

ONE-TIME STEPS
--------------
1. On the Kindle, open RR-KPP-Bytecode-Export once. This creates
   KPPMainApp.js.hbc directly in the Kindle Documents folder and verifies
   its size and SHA256.
2. Connect the Kindle to Windows with USB.
3. Open the Kindle drive, then Documents, and copy KPPMainApp.js.hbc.
4. Extract this ZIP and put KPPMainApp.js.hbc beside
   Run-KPP-Disassembly.bat.
5. Double-click Run-KPP-Disassembly.bat.
6. The helper uses your existing Python installation. On the first run it
   downloads a pinned, pure-Python hbctool source snapshot from GitHub.
   You do not need to install hbctool or any Python packages.
7. It creates a findings report and full local disassembly folder.

If you keep the bundle in a different folder, a file picker opens.
You can also drag KPPMainApp.js.hbc onto the BAT file.

OUTPUT
------
KPPMainApp-disassembly/
  metadata.json
  string.json
  instruction.hasm
  KPP-Interface-Findings.txt

The findings report focuses on browser-interface strings and the functions
that reference them. It deliberately omits embedded literal strings from
the summary. The full disassembly files can contain application strings;
keep them private and share only the findings report unless we review
the contents first.

PRIVACY
-------
The Kindle bundle is copied to your own computer by USB. It is never
uploaded to GitHub, pasters.io, or any other service. The hbctool source
code is downloaded from GitHub. The disassembly remains local.

TOOL SOURCE
-----------
Hermes disassembler: https://github.com/Baba01hacker666/HBC-Tool
Pinned source commit: 873aa1b1a53c9d28dbec28e1a427916255980879
The disassembler is MIT-licensed. Its optional C++ acceleration is not
used; the pure-Python mode needs no compiler or pip installation.

IMPORTANT
---------
This is a one-time static analysis step. It does not test JavaScript
execution in the live browser yet. It helps us discover the real code path
and argument handling before designing a safe, minimal live test.
