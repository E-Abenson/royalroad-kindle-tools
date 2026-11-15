#!/usr/bin/env python3
"""Offline, read-only ELF marker and symbol inspection for Kindle KPP binaries."""
from __future__ import annotations

import hashlib
import re
import struct
import sys
import tarfile
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

MAX_ARCHIVE_MEMBER = 80_000_000
MAX_TOTAL_INPUT = 180_000_000
MAX_FINDINGS_PER_FILE = 180
MAX_FINDINGS_TOTAL = 700
PASTE_URL = "https://pasters.io/?expires=1w"

MARKERS = re.compile(
    r"invokeAction|getLastOpenPage|getAllSettings|webViewURL|"
    r"webViewURLRedirectActionId|navigateToKPPBrowser|redirectToWebView|"
    r"evaluateJavaScript|evaluateJavascript|executeJavaScript|"
    r"executeJavascript|runJavaScript|loadUrl|loadHTMLString|"
    r"WKWebView|WebKit|JavaScriptCore|JSContext|JSValue|"
    r"ReactNative|facebook::react|hermes|WebView|webview|"
    r"ContentController|ScriptMessageHandler|messageHandlers|"
    r"pageSource|getPageSource|getHTML|readHTML|executeScript|"
    r"LIPC|lipc|browser|Browser|Navigation|navigation|"
    r"innerText|textContent|outerHTML|documentElement|"
    r"Java_.*(KPP|kpp|browser|Browser|web|Web)",
    re.IGNORECASE,
)
SENSITIVE = re.compile(
    r"cookie|session|access.?token|auth|credential|password|passwd|"
    r"secret|account|serial|mac.?address|device.?id|email",
    re.IGNORECASE,
)
URL_RE = re.compile(r"https?://\S+", re.IGNORECASE)
EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE)
PATH_RE = re.compile(r"(?<![A-Za-z0-9])/(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]*")


def safe_preview(value: str) -> str | None:
    value = value.replace("\x00", " ").replace("\r", " ").replace("\n", " ").strip()
    if not value or SENSITIVE.search(value):
        return None
    value = URL_RE.sub("[URL withheld]", value)
    value = EMAIL_RE.sub("[email withheld]", value)
    value = PATH_RE.sub("[path withheld]", value)
    value = re.sub(r"\s+", " ", value)
    if len(value) > 200:
        value = value[:197] + "..."
    return value or None


def elf_layout(data: bytes):
    if len(data) < 52 or data[:4] != b"\x7fELF":
        return None
    elf_class = data[4]
    encoding = data[5]
    if encoding not in (1, 2) or elf_class not in (1, 2):
        return None
    endian = "<" if encoding == 1 else ">"
    if elf_class == 1:
        fmt = endian + "HHIIIIIHHHHHH"
        header_size = 52
        sh_fmt = endian + "IIIIIIIIII"
        expected_sh_size = 40
        sym_fmt = endian + "IIIBBH"
    else:
        fmt = endian + "HHIQQQIHHHHHH"
        header_size = 64
        sh_fmt = endian + "IIQQQQIIQQ"
        expected_sh_size = 64
        sym_fmt = endian + "IBBHQQ"

    if len(data) < header_size:
        return None
    fields = struct.unpack_from(fmt, data, 16)
    machine = fields[1]
    shoff = fields[5]
    shentsize = fields[10]
    shnum = fields[11]
    if shentsize < expected_sh_size or shnum > 4096:
        shnum = 0
    sections = []
    for index in range(shnum):
        offset = shoff + index * shentsize
        if offset < 0 or offset + expected_sh_size > len(data):
            break
        sections.append(struct.unpack_from(sh_fmt, data, offset))

    return {
        "class": 32 if elf_class == 1 else 64,
        "endian": "little" if endian == "<" else "big",
        "machine": machine,
        "sections": sections,
        "sym_fmt": sym_fmt,
        "endian_fmt": endian,
    }


def machine_name(machine: int) -> str:
    return {
        3: "x86",
        40: "ARM",
        62: "x86-64",
        183: "AArch64",
        243: "RISC-V",
    }.get(machine, f"ELF machine {machine}")


def get_c_string(table: bytes, offset: int) -> str:
    if offset < 0 or offset >= len(table):
        return ""
    end = table.find(b"\x00", offset)
    if end < 0:
        end = len(table)
    return table[offset:end].decode("utf-8", "replace")


def matching_symbols(data: bytes, layout) -> list[str]:
    results = []
    seen = set()
    sections = layout["sections"]
    symbol_fmt = layout["sym_fmt"]
    symbol_size = struct.calcsize(symbol_fmt)
    for section in sections:
        section_type = section[1]
        if section_type not in (2, 11):  # SHT_SYMTAB / SHT_DYNSYM
            continue
        offset, size, link, entry_size = section[4], section[5], section[6], section[9]
        if link >= len(sections) or offset + size > len(data):
            continue
        if entry_size < symbol_size or entry_size == 0:
            entry_size = symbol_size
        string_section = sections[link]
        string_offset, string_size = string_section[4], string_section[5]
        if string_offset + string_size > len(data):
            continue
        strings = data[string_offset:string_offset + string_size]
        count = min(size // entry_size, 250_000)
        for i in range(count):
            pos = offset + i * entry_size
            if pos + symbol_size > len(data):
                break
            symbol = struct.unpack_from(symbol_fmt, data, pos)
            name = get_c_string(strings, symbol[0])
            if name and MARKERS.search(name):
                preview = safe_preview(name)
                if preview and preview not in seen:
                    seen.add(preview)
                    results.append(preview)
                    if len(results) >= MAX_FINDINGS_PER_FILE:
                        return results
    return results


def matching_strings(data: bytes) -> list[tuple[int, str]]:
    results = []
    seen = set()

    for match in re.finditer(rb"[\x20-\x7e]{5,}", data):
        raw = match.group(0).decode("utf-8", "replace")
        if not MARKERS.search(raw):
            continue
        preview = safe_preview(raw)
        key = (match.start(), preview)
        if preview and key not in seen:
            seen.add(key)
            results.append(key)
            if len(results) >= MAX_FINDINGS_PER_FILE:
                return results

    # UTF-16LE strings also occur in native framework resources.
    for match in re.finditer(rb"(?:[\x20-\x7e]\x00){5,}", data):
        raw = match.group(0).decode("utf-16le", "replace")
        if not MARKERS.search(raw):
            continue
        preview = safe_preview(raw)
        key = (match.start(), preview)
        if preview and key not in seen:
            seen.add(key)
            results.append(key)
            if len(results) >= MAX_FINDINGS_PER_FILE:
                break
    return results


def inspect_archive(path: Path):
    files = []
    total = 0
    with tarfile.open(path, mode="r:gz") as archive:
        for member in archive.getmembers():
            if not member.isfile() or "/files/" not in ("/" + member.name):
                continue
            if member.size <= 0 or member.size > MAX_ARCHIVE_MEMBER:
                continue
            total += member.size
            if total > MAX_TOTAL_INPUT:
                raise ValueError("archive exceeds supported total input size")
            source = archive.extractfile(member)
            if source is None:
                continue
            data = source.read(MAX_ARCHIVE_MEMBER + 1)
            if len(data) != member.size:
                raise ValueError("archive member size mismatch")
            layout = elf_layout(data)
            if layout is None:
                continue
            basename = Path(member.name).name
            digest = hashlib.sha256(data).hexdigest()
            files.append((basename, data, layout, digest))
    if not files:
        raise ValueError("no readable ELF files found")
    return files


def build_report(files, archive_name: str) -> str:
    lines = [
        "KPP NATIVE BRIDGE — OFFLINE STATIC INSPECTION",
        f"Input archive: {Path(archive_name).name}",
        f"ELF files inspected: {len(files)}",
        "Method: ELF metadata, symbol-table names, and selected embedded strings only",
        "No executable was run; no file was modified; no network retrieval occurred during inspection.",
        "No page URL, page text, cookies, account data, process IDs, command lines, or absolute device paths are included.",
        "",
        "ELF INVENTORY",
    ]
    total_findings = 0
    for name, data, layout, digest in files:
        lines.append(
            f"- {name}: ELF{layout['class']} {layout['endian']} {machine_name(layout['machine'])}; "
            f"{len(data)} bytes; SHA256 {digest}"
        )

    lines.extend(["", "RELEVANT NATIVE SYMBOLS AND STRINGS"])
    for name, data, layout, digest in files:
        symbols = matching_symbols(data, layout)
        strings = matching_strings(data)
        if not symbols and not strings:
            continue
        lines.extend(["", f"[{name}]"])
        if symbols:
            lines.append("Symbol-table entries:")
            for item in symbols:
                if total_findings >= MAX_FINDINGS_TOTAL:
                    break
                lines.append(f"  SYMBOL {item}")
                total_findings += 1
        if strings:
            lines.append("Embedded marker strings (offsets are hexadecimal):")
            for offset, item in strings:
                if total_findings >= MAX_FINDINGS_TOTAL:
                    break
                lines.append(f"  0x{offset:x}  {item}")
                total_findings += 1
        if total_findings >= MAX_FINDINGS_TOTAL:
            lines.append("Finding cap reached; additional matches were omitted.")
            break

    if total_findings == 0:
        return ""
    lines.extend([
        "",
        "INTERPRETATION LIMIT",
        "A string or symbol is only a lead. It does not prove that a callable interface is exposed,",
        "that its arguments are known, or that it is safe to invoke. No LIPC write or browser action",
        "was attempted. The next test must be based on a verified implementation path and documented",
        "read-only behavior; do not guess invokeAction payloads.",
    ])
    return "\n".join(lines) + "\n"


def upload_report(report: str):
    request = urllib.request.Request(
        PASTE_URL,
        data=report.encode("utf-8"),
        headers={
            "Content-Type": "text/plain; charset=utf-8",
            "Accept": "text/plain",
            "User-Agent": "KPP-Native-Bridge-Inspector/1.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=35) as response:
        status = response.status
        body = response.read(4096).decode("utf-8", "replace").strip()
        location = response.headers.get("Location", "").strip()
        delete_url = response.headers.get("x-delete-url", "").strip()

    paste_url = body if body.startswith("https://pasters.io/") else location
    parsed = urlsplit(paste_url)
    if status not in (200, 201) or parsed.scheme != "https" or parsed.netloc.lower() not in ("pasters.io", "www.pasters.io"):
        raise RuntimeError(f"Pasters.io did not confirm a valid paste (HTTP {status})")
    return paste_url, delete_url


def main() -> int:
    if len(sys.argv) > 1:
        archive_path = Path(sys.argv[1].strip('"')).expanduser()
    else:
        candidates = list(Path.cwd().glob("KPP-Native-Bridge-Binaries.tar.gz"))
        if len(candidates) != 1:
            print("FAILURE: Drag KPP-Native-Bridge-Binaries.tar.gz onto this BAT file.")
            return 1
        archive_path = candidates[0]
    if not archive_path.is_file():
        print("FAILURE: The native-inspection archive was not found.")
        return 1

    try:
        files = inspect_archive(archive_path)
        report = build_report(files, str(archive_path))
    except (OSError, tarfile.TarError, ValueError, struct.error):
        print("FAILURE: Could not inspect the archive. The local input was not uploaded.")
        return 1

    if not report:
        print("FAILURE: No relevant native browser/bridge markers were found. No paste was uploaded.")
        return 1

    report_path = archive_path.with_name("KPP-Native-Bridge-Findings.txt")
    report_path.write_text(report, encoding="utf-8", newline="\n")
    try:
        paste_url, delete_url = upload_report(report)
    except (OSError, urllib.error.URLError, RuntimeError) as error:
        print(f"UPLOAD FAILED: Findings saved locally at {report_path.name}; no binary was uploaded.")
        print(f"Upload detail: {type(error).__name__}")
        return 0

    archive_path.with_name("KPP-Native-Bridge-Findings-upload-url.txt").write_text(
        paste_url + "\n", encoding="utf-8"
    )
    if delete_url.startswith("https://pasters.io/d/"):
        archive_path.with_name("KPP-Native-Bridge-Findings-delete-url.txt").write_text(
            delete_url + "\n", encoding="utf-8"
        )
    print("SUCCESS: Native findings uploaded to Pasters.io:")
    print(paste_url)
    print("One-week expiry requested. The archive and raw binaries were not uploaded.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
