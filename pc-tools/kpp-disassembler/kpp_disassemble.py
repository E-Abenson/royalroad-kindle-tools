#!/usr/bin/env python3
"""
One-time, read-only disassembly of the Kindle KPP Hermes bundle.

Uses Python already installed on Windows (3.8+). No pip installation,
compiler, administrator rights, or global Python changes are required.
Downloads a pinned MIT-licensed pure-Python hbctool source archive from GitHub.
Never uploads the Kindle bundle or the resulting disassembly.
"""
from __future__ import annotations

import hashlib
import importlib
import json
import os
from pathlib import Path
import shutil
import struct
import sys
import urllib.error
import urllib.request
import zipfile

HBC_TOOL_COMMIT = "873aa1b1a53c9d28dbec28e1a427916255980879"
HBC_TOOL_ZIP = (
    "https://github.com/Baba01hacker666/HBC-Tool/archive/"
    + HBC_TOOL_COMMIT
    + ".zip"
)
EXPECTED_MAGIC = bytes.fromhex("c61fbc03c103191f")
MAX_INPUT_BYTES = 50 * 1024 * 1024
MAX_ARCHIVE_BYTES = 100 * 1024 * 1024

TARGETS = [
    "invokeAction",
    "runJavaScript",
    "evaluateJavascript",
    "evaluateJavaScript",
    "executeJavaScript",
    "loadUrl",
    "loadURL",
    "navigate",
    "postMessage",
    "DevTools",
    "WebView",
    "WebKit",
    "getLastOpenPage",
    "getAllSettings",
    "remote-debugging",
    "javascript:",
    "addJavascriptInterface",
    "addJavaScriptInterface",
    "injectJavaScript",
    "messageHandlers",
]


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def choose_input(script_dir: Path) -> Path:
    if len(sys.argv) > 1:
        candidate = Path(sys.argv[1].strip('"')).expanduser()
        if candidate.is_file():
            return candidate.resolve()
        raise FileNotFoundError("The supplied file path does not exist: " + str(candidate))

    default = script_dir / "KPPMainApp.js.hbc"
    if default.is_file():
        return default.resolve()

    try:
        import tkinter as tk
        from tkinter import filedialog

        root = tk.Tk()
        root.withdraw()
        root.attributes("-topmost", True)
        selected = filedialog.askopenfilename(
            title="Select KPPMainApp.js.hbc copied from Kindle Documents",
            initialdir=str(script_dir),
            filetypes=[
                ("Kindle Hermes bytecode", "KPPMainApp.js.hbc"),
                ("All files", "*.*"),
            ],
        )
        root.destroy()
        if selected:
            return Path(selected).resolve()
    except Exception:
        pass

    typed = input(
        "Enter the full path to KPPMainApp.js.hbc (or drag the file here): "
    ).strip().strip('"')
    candidate = Path(typed).expanduser()
    if not candidate.is_file():
        raise FileNotFoundError("Could not find the selected HBC file.")
    return candidate.resolve()


def safe_extract_zip(archive_path: Path, destination: Path) -> Path:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path, "r") as archive:
        members = archive.infolist()
        if len(members) > 10000:
            raise RuntimeError("The hbctool source archive has an unexpected number of entries.")

        root_prefix = None
        for member in members:
            parts = Path(member.filename.replace("\\", "/")).parts
            if len(parts) >= 2 and parts[1] == "hbctool" and parts[-1] == "__init__.py":
                root_prefix = parts[0]
                break
        if not root_prefix:
            raise RuntimeError("Could not locate hbctool source inside the downloaded archive.")

        for member in members:
            parts = Path(member.filename.replace("\\", "/")).parts
            if not parts or parts[0] != root_prefix or any(p in ("..", "") for p in parts):
                continue

            target = destination.joinpath(*parts[1:])
            if member.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue

            mode = (member.external_attr >> 16) & 0xFFFF
            if (mode & 0o170000) == 0o120000:
                continue

            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output)

    if not (destination / "hbctool" / "__init__.py").is_file():
        raise RuntimeError("The hbctool source did not extract correctly.")
    return destination


def obtain_hbctool(script_dir: Path) -> Path:
    source_root = script_dir / (".hbctool-source-" + HBC_TOOL_COMMIT[:12])
    if (source_root / "hbctool" / "__init__.py").is_file():
        return source_root

    download_dir = script_dir / ".hbctool-download"
    download_dir.mkdir(exist_ok=True)
    archive_path = download_dir / (HBC_TOOL_COMMIT + ".zip")
    temp_path = archive_path.with_suffix(".zip.part")
    request = urllib.request.Request(
        HBC_TOOL_ZIP,
        headers={"User-Agent": "KPP-One-Time-Local-Disassembly/1.0"},
    )

    print("Downloading the pinned hbctool source from GitHub (first run only)...")
    try:
        with urllib.request.urlopen(request, timeout=60) as response, temp_path.open("wb") as output:
            total = 0
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_ARCHIVE_BYTES:
                    raise RuntimeError("hbctool source archive exceeded the 100 MB safety limit.")
                output.write(chunk)
        temp_path.replace(archive_path)
    except (urllib.error.URLError, OSError, RuntimeError) as exc:
        try:
            if temp_path.exists():
                temp_path.unlink()
        except OSError:
            pass
        raise RuntimeError(
            "Could not download hbctool from GitHub. Check the computer's internet connection "
            "and run this tool again. Details: " + str(exc)
        ) from exc

    source_root.mkdir(parents=True, exist_ok=True)
    try:
        safe_extract_zip(archive_path, source_root)
    except Exception:
        shutil.rmtree(source_root, ignore_errors=True)
        raise
    return source_root


def load_hbctool(source_root: Path):
    sys.path.insert(0, str(source_root))
    importlib.invalidate_caches()
    import hbctool.hbc as hbc_module
    import hbctool.hasm as hasm_module
    return hbc_module, hasm_module


def disassemble_bundle(bundle: Path, output_dir: Path, hbc_module, hasm_module):
    size = bundle.stat().st_size
    if size <= 0 or size > MAX_INPUT_BYTES:
        raise RuntimeError(
            "Bundle size is outside the allowed 1–50 MB range: {:,} bytes".format(size)
        )

    with bundle.open("rb") as stream:
        header = stream.read(12)
    if len(header) < 12 or header[:8] != EXPECTED_MAGIC:
        raise RuntimeError(
            "This file does not have the Hermes HBC header expected from the Kindle export."
        )

    version = struct.unpack("<I", header[8:12])[0]
    print("Input: {}".format(bundle))
    print("Size: {:,} bytes".format(size))
    digest = sha256_file(bundle)
    print("SHA256: {}".format(digest))
    print("Hermes bytecode version: {}".format(version))
    print("Loading the matching Hermes parser...")
    with bundle.open("rb") as stream:
        hbc = hbc_module.load(stream)

    function_count = hbc.getFunctionCount()
    string_count = hbc.getStringCount()
    print("Disassembling {} functions and {} strings...".format(function_count, string_count))
    hasm_module.dump(hbc, str(output_dir))
    return {
        "version": version,
        "functions": function_count,
        "strings": string_count,
        "size": size,
        "sha256": digest,
    }


def read_marker_strings(strings_path: Path):
    with strings_path.open("r", encoding="utf-8") as stream:
        entries = json.load(stream)

    matches = {}
    for marker in TARGETS:
        folded = marker.casefold()
        matches[marker] = [
            (entry.get("id"), entry.get("value", ""))
            for entry in entries
            if isinstance(entry.get("value", ""), str)
            and folded in entry.get("value", "").casefold()
        ]
    return matches


def redact_asm_line(line: str) -> str:
    # hbctool comments include the full literal value; retain the string ID only.
    if "; Oper[" in line:
        return line.split("; Oper[", 1)[0] + "; [literal text omitted]\n"
    return line


def make_findings_report(output_dir: Path, info: dict, bundle: Path):
    matches = read_marker_strings(output_dir / "string.json")
    asm_lines = (output_dir / "instruction.hasm").read_text(
        encoding="utf-8", errors="replace"
    ).splitlines()

    string_ids = {
        marker: {sid for sid, _ in values if isinstance(sid, int)}
        for marker, values in matches.items()
    }

    function_blocks = []
    current_header, current_lines = None, []
    for line in asm_lines:
        if line.startswith("Function<"):
            if current_header is not None:
                function_blocks.append((current_header, current_lines))
            current_header, current_lines = line, [line]
        elif current_header is not None:
            current_lines.append(line)
    if current_header is not None:
        function_blocks.append((current_header, current_lines))

    report_path = output_dir / "KPP-Interface-Findings.txt"
    with report_path.open("w", encoding="utf-8") as report:
        report.write("KINDLE KPP HERMES BYTECODE — ONE-TIME READ-ONLY DISASSEMBLY\n")
        report.write("=" * 72 + "\n")
        report.write("Input: {}\n".format(bundle.name))
        report.write("Input SHA256: {}\n".format(info["sha256"]))
        report.write("Input size: {:,} bytes\n".format(info["size"]))
        report.write("Hermes bytecode version: {}\n".format(info["version"]))
        report.write("Functions: {}\n".format(info["functions"]))
        report.write("String-table entries: {}\n".format(info["strings"]))
        report.write("hbctool source commit: {}\n".format(HBC_TOOL_COMMIT))
        report.write("The bundle was only parsed/disassembled; it was not executed or modified.\n")
        report.write("This summary omits embedded literal text; the full string table stays local.\n")
        report.write("All output remains local on this computer; nothing was uploaded.\n\n")

        report.write("MARKER STRING TABLE MATCHES\n" + "-" * 72 + "\n")
        for marker in TARGETS:
            values = matches[marker]
            report.write("\n{}: {} match(es)\n".format(marker, len(values)))
            for sid, value in values[:50]:
                report.write(
                    "  String ID {} ({} characters; literal omitted)\n".format(
                        sid, len(value) if isinstance(value, str) else 0
                    )
                )
            if len(values) > 50:
                report.write(
                    "  ... {} additional matches omitted from this summary.\n".format(
                        len(values) - 50
                    )
                )

        report.write("\nFUNCTIONS REFERENCING MATCHING STRINGS\n" + "-" * 72 + "\n")
        for marker in TARGETS:
            ids = string_ids[marker]
            if not ids:
                continue

            relevant = []
            for heading, block in function_blocks:
                matched_lines = [
                    i
                    for i, line in enumerate(block)
                    if any("String({})".format(sid) in line for sid in ids)
                ]
                if matched_lines:
                    relevant.append((heading, matched_lines, block))

            report.write("\n{} — {} function(s)\n".format(marker, len(relevant)))
            for heading, matched_lines, block in relevant[:40]:
                report.write("\n  " + heading + "\n")
                windows = []
                for index in matched_lines[:8]:
                    start, end = max(1, index - 3), min(len(block), index + 4)
                    if windows and start <= windows[-1][1] + 1:
                        windows[-1] = (windows[-1][0], max(windows[-1][1], end))
                    else:
                        windows.append((start, end))

                for start, end in windows:
                    for line in block[start:end]:
                        report.write("    " + redact_asm_line(line))
                if len(matched_lines) > 8:
                    report.write("    ... additional references in this function omitted.\n")

            if len(relevant) > 40:
                report.write(
                    "  ... {} additional functions omitted. Full disassembly is in instruction.hasm.\n".format(
                        len(relevant) - 40
                    )
                )

        report.write("\nNEXT REVIEW\n" + "-" * 72 + "\n")
        report.write(
            "Inspect call sites and surrounding control flow for invokeAction, "
            "runJavaScript, evaluateJavaScript, postMessage and navigation methods.\n"
        )
        report.write(
            "A string or call-site reference does not establish that an external LIPC "
            "command is supported. Do not send guessed actions to the live browser.\n"
        )
        report.write(
            "Full disassembly files: metadata.json, string.json, instruction.hasm\n"
        )
        report.write("Findings report: {}\n".format(report_path))
    return report_path


def main():
    if sys.version_info < (3, 8):
        raise RuntimeError("Python 3.8 or later is required. No packages need to be installed.")

    script_dir = Path(__file__).resolve().parent
    bundle = choose_input(script_dir)
    hbc_module, hasm_module = load_hbctool(obtain_hbctool(script_dir))

    output_base = script_dir / "KPPMainApp-disassembly"
    output_dir, suffix = output_base, 1
    while output_dir.exists():
        output_dir = script_dir / "KPPMainApp-disassembly-{}".format(suffix)
        suffix += 1

    info = disassemble_bundle(bundle, output_dir, hbc_module, hasm_module)
    report_path = make_findings_report(output_dir, info, bundle)

    print("\nSUCCESS")
    print("Findings report: {}".format(report_path))
    print("Full disassembly: {}".format(output_dir))
    print("No files were uploaded or sent anywhere.")
    try:
        os.startfile(str(output_dir))
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        print("\nCancelled by user.", file=sys.stderr)
        raise SystemExit(130)
    except Exception as exc:
        print("\nFAILED: {}".format(exc), file=sys.stderr)
        raise SystemExit(1)
