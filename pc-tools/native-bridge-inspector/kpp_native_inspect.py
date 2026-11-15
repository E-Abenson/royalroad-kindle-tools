#!/usr/bin/env python3
"""Offline, read-only ELF symbol, string, relocation and native-code inspection."""
from __future__ import annotations

import hashlib
import importlib
import json
import re
import struct
import sys
import tarfile
import zipfile
from collections import defaultdict, deque
from pathlib import Path

CAPSTONE_VERSION = "5.0.9"
CAPSTONE_WHEEL = "capstone-5.0.9-py3-none-win_amd64.whl"
CAPSTONE_SHA256 = "732cedbbb56d42e723f14d7af6387f1454194a820b4b96b56d1e53f865ef85d0"

MAX_ARCHIVE_MEMBER = 80_000_000
MAX_TOTAL_INPUT = 180_000_000
MAX_FILES = 96
MAX_FINDINGS_PER_FILE = 240
MAX_FINDINGS_TOTAL = 1600
MAX_CODE_BYTES_PER_FILE = 55_000_000
MAX_CODE_BYTES_TOTAL = 135_000_000
MAX_RELEVANT_FUNCTIONS_PER_FILE = 70
MAX_FUNCTION_BYTES = 48_000
MAX_FUNCTION_INSTRUCTIONS = 180
MAX_XREFS_PER_FILE = 100
MAX_XREFS_PER_STRING = 12
MAX_REPORT_CHARS = 1_400_000

MARKER_RE = re.compile(
    r"invokeAction|getLastOpenPage|getAllSettings|webViewURL|"
    r"webViewURLRedirectActionId|navigateToKPPBrowser|redirectToWebView|"
    r"BrowserDataProvider|ApplicationLipcProvider|NavigationInterface|"
    r"evaluateJavaScript|evaluateJavascript|executeJavaScript|"
    r"executeJavascript|runJavaScript|loadUrl|loadURL|loadHTMLString|"
    r"WKWebView|WebKit|JavaScriptCore|JSContext|JSValue|"
    r"ReactNative|facebook::react|hermes|WebView|webview|"
    r"ContentController|ScriptMessageHandler|messageHandlers|"
    r"pageSource|getPageSource|getHTML|readHTML|executeScript|"
    r"innerText|textContent|outerHTML|documentElement|"
    r"getStringProperty|setStringProperty|getIntProperty|setIntProperty|"
    r"getHashArrayProperty|registerProperty|LIPC|lipc|"
    r"browser|Browser|Navigation|navigation",
    re.IGNORECASE,
)
SENSITIVE_RE = re.compile(
    r"cookie|session|access.?token|auth|credential|password|passwd|"
    r"secret|account|serial|mac.?address|device.?id|email",
    re.IGNORECASE,
)
URL_RE = re.compile(r"https?://\S+", re.IGNORECASE)
EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE)
PATH_RE = re.compile(r"(?<![A-Za-z0-9])/(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]*")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_preview(value: str) -> str | None:
    value = value.replace("\x00", " ").replace("\r", " ").replace("\n", " ").strip()
    if not value or SENSITIVE_RE.search(value):
        return None
    value = URL_RE.sub("[URL withheld]", value)
    value = EMAIL_RE.sub("[email withheld]", value)
    value = PATH_RE.sub("[path withheld]", value)
    value = re.sub(r"\s+", " ", value)
    if len(value) > 180:
        value = value[:177] + "..."
    return value or None


def machine_name(machine: int) -> str:
    return {
        3: "x86",
        40: "ARM",
        62: "x86-64",
        183: "AArch64",
        243: "RISC-V",
    }.get(machine, "ELF machine {}".format(machine))


def get_c_string(table: bytes, offset: int) -> str:
    if offset < 0 or offset >= len(table):
        return ""
    end = table.find(b"\x00", offset)
    if end < 0:
        end = len(table)
    return table[offset:end].decode("utf-8", "replace")


def elf_layout(data: bytes):
    if len(data) < 52 or data[:4] != b"\x7fELF":
        return None
    elf_class, encoding = data[4], data[5]
    if elf_class not in (1, 2) or encoding not in (1, 2):
        return None

    endian = "<" if encoding == 1 else ">"
    if elf_class == 1:
        header_fmt = endian + "HHIIIIIHHHHHH"
        section_fmt = endian + "IIIIIIIIII"
        symbol_fmt = endian + "IIIBBH"
        rel_fmt, rela_fmt = endian + "II", endian + "IIi"
        header_size, section_size, symbol_size = 52, 40, 16
        rel_size, rela_size = 8, 12
    else:
        header_fmt = endian + "HHIQQQIHHHHHH"
        section_fmt = endian + "IIQQQQIIQQ"
        symbol_fmt = endian + "IBBHQQ"
        rel_fmt, rela_fmt = endian + "QQ", endian + "QQq"
        header_size, section_size, symbol_size = 64, 64, 24
        rel_size, rela_size = 16, 24

    if len(data) < header_size:
        return None
    header = struct.unpack_from(header_fmt, data, 16)
    e_type, machine = header[0], header[1]
    entry, section_offset = header[3], header[5]
    section_entry_size, section_count, section_names_index = header[10], header[11], header[12]
    if section_count > 8192 or section_entry_size < section_size:
        return None
    if section_offset > len(data):
        return None

    sections = []
    for index in range(section_count):
        position = section_offset + index * section_entry_size
        if position + section_size > len(data):
            return None
        values = struct.unpack_from(section_fmt, data, position)
        if elf_class == 1:
            name_off, sec_type, flags, addr, offset, size, link, info, align, entsize = values
        else:
            name_off, sec_type, flags, addr, offset, size, link, info, align, entsize = values
        if offset > len(data) or (sec_type != 8 and size > len(data) - offset):
            # SHT_NOBITS has no bytes in the file.
            if sec_type != 8:
                return None
        sections.append({
            "index": index, "name_offset": name_off, "type": sec_type,
            "flags": flags, "addr": addr, "offset": offset, "size": size,
            "link": link, "info": info, "align": align, "entsize": entsize,
            "name": "section_{}".format(index),
        })

    if 0 <= section_names_index < len(sections):
        names_section = sections[section_names_index]
        if names_section["offset"] + names_section["size"] <= len(data):
            names = data[names_section["offset"]:names_section["offset"] + names_section["size"]]
            for section in sections:
                section["name"] = get_c_string(names, section["name_offset"]) or section["name"]

    return {
        "class": 32 if elf_class == 1 else 64,
        "endian": "little" if endian == "<" else "big",
        "endian_fmt": endian,
        "machine": machine,
        "type": e_type,
        "entry": entry,
        "sections": sections,
        "symbol_fmt": symbol_fmt,
        "symbol_size": symbol_size,
        "rel_fmt": rel_fmt,
        "rela_fmt": rela_fmt,
        "rel_size": rel_size,
        "rela_size": rela_size,
    }


def section_for_file_offset(layout, offset: int):
    for section in layout["sections"]:
        if section["type"] == 8 or section["size"] <= 0:
            continue
        start, end = section["offset"], section["offset"] + section["size"]
        if start <= offset < end:
            return section
    return None


def section_for_address(layout, address: int):
    for section in layout["sections"]:
        if section["type"] == 8 or section["size"] <= 0:
            continue
        if section["addr"] <= address < section["addr"] + section["size"]:
            return section
    return None


def extract_marker_strings(data: bytes, layout):
    found = []
    seen = set()

    def add(offset: int, raw: str):
        if not MARKER_RE.search(raw):
            return
        preview = safe_preview(raw)
        if not preview:
            return
        section = section_for_file_offset(layout, offset)
        address = None
        if section is not None and (section["flags"] & 2):
            address = section["addr"] + offset - section["offset"]
        key = (offset, preview)
        if key in seen:
            return
        seen.add(key)
        found.append({
            "offset": offset, "text": preview, "address": address,
            "section": section["name"] if section else "?",
        })

    for match in re.finditer(rb"[\x20-\x7e]{5,}", data):
        add(match.start(), match.group(0).decode("utf-8", "replace"))
        if len(found) >= MAX_FINDINGS_PER_FILE:
            return found

    for match in re.finditer(rb"(?:[\x20-\x7e]\x00){5,}", data):
        add(match.start(), match.group(0).decode("utf-16le", "replace"))
        if len(found) >= MAX_FINDINGS_PER_FILE:
            break
    return found


def parse_symbol_tables(data: bytes, layout):
    all_symbols = []
    table_symbols = {}
    fmt = layout["symbol_fmt"]
    symbol_size = layout["symbol_size"]

    for section in layout["sections"]:
        if section["type"] not in (2, 11):  # SHT_SYMTAB / SHT_DYNSYM
            continue
        if section["link"] >= len(layout["sections"]):
            continue
        if section["offset"] + section["size"] > len(data):
            continue
        string_section = layout["sections"][section["link"]]
        if string_section["offset"] + string_section["size"] > len(data):
            continue
        strings = data[
            string_section["offset"]:string_section["offset"] + string_section["size"]
        ]
        entry_size = section["entsize"] or symbol_size
        if entry_size < symbol_size:
            continue
        count = min(section["size"] // entry_size, 500_000)
        symbols = []
        for index in range(count):
            position = section["offset"] + index * entry_size
            if position + symbol_size > len(data):
                break
            raw = struct.unpack_from(fmt, data, position)
            if layout["class"] == 32:
                name_index, value, size, info, other, section_index = raw
            else:
                name_index, info, other, section_index, value, size = raw
            name = get_c_string(strings, name_index)
            symbol = {
                "name": name, "value": value, "size": size, "info": info,
                "type": info & 0x0F, "bind": info >> 4,
                "section_index": section_index, "table_index": index,
                "table_section": section["index"],
            }
            symbols.append(symbol)
            if name and MARKER_RE.search(name):
                preview = safe_preview(name)
                if preview:
                    all_symbols.append({**symbol, "preview": preview})
        table_symbols[section["index"]] = symbols
    return all_symbols, table_symbols


def parse_relocations(data: bytes, layout, table_symbols):
    results = []
    for section in layout["sections"]:
        if section["type"] not in (4, 9):  # SHT_RELA / SHT_REL
            continue
        if section["link"] not in table_symbols:
            continue
        fmt = layout["rela_fmt"] if section["type"] == 4 else layout["rel_fmt"]
        expected = layout["rela_size"] if section["type"] == 4 else layout["rel_size"]
        entry_size = section["entsize"] or expected
        if entry_size < expected or section["offset"] + section["size"] > len(data):
            continue
        symbols = table_symbols[section["link"]]
        count = min(section["size"] // entry_size, 500_000)
        for index in range(count):
            pos = section["offset"] + index * entry_size
            raw = struct.unpack_from(fmt, data, pos)
            relocation_offset, info = raw[0], raw[1]
            symbol_index = (info >> 32) if layout["class"] == 64 else (info >> 8)
            symbol_type = (info & 0xFFFFFFFF) if layout["class"] == 64 else (info & 0xFF)
            if symbol_index >= len(symbols):
                continue
            symbol = symbols[symbol_index]
            if not symbol["name"] or not MARKER_RE.search(symbol["name"]):
                continue
            preview = safe_preview(symbol["name"])
            if not preview:
                continue
            target_section = (
                layout["sections"][section["info"]]["name"]
                if section["info"] < len(layout["sections"]) else "?"
            )
            results.append({
                "offset": relocation_offset, "type": symbol_type,
                "symbol": preview, "target_section": target_section,
                "relocation_section": section["name"],
            })
            if len(results) >= MAX_FINDINGS_PER_FILE:
                return results
    return results


def load_capstone(script_dir: Path):
    if sys.platform == "win32":
        wheel = script_dir / CAPSTONE_WHEEL
        if not wheel.is_file():
            raise RuntimeError(
                "The bundled Capstone disassembler is missing. Re-extract the complete Windows ZIP."
            )
        actual = sha256_file(wheel)
        if actual.lower() != CAPSTONE_SHA256:
            raise RuntimeError("The bundled Capstone file failed its SHA256 integrity check.")
        runtime = script_dir / (".capstone-runtime-" + CAPSTONE_VERSION)
        if not (runtime / "capstone" / "__init__.py").is_file():
            runtime.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(wheel, "r") as archive:
                for item in archive.infolist():
                    name = item.filename.replace("\\", "/")
                    parts = Path(name).parts
                    if not parts or name.startswith("/") or ".." in parts:
                        raise RuntimeError("The bundled Capstone wheel contains an unsafe path.")
                    target = runtime.joinpath(*parts)
                    if item.is_dir():
                        target.mkdir(parents=True, exist_ok=True)
                    else:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        with archive.open(item) as source, target.open("wb") as output:
                            output.write(source.read())
        sys.path.insert(0, str(runtime))
        importlib.invalidate_caches()
    import capstone
    version = getattr(capstone, "__version__", "unknown")
    if sys.platform == "win32":
        # The distributed Windows helper is tied to the exact wheel verified by SHA256.
        if version != CAPSTONE_VERSION:
            raise RuntimeError(
                "Expected bundled Capstone {}, but loaded {}. Re-extract the Windows helper ZIP.".format(
                    CAPSTONE_VERSION, version
                )
            )
    elif not str(version).startswith("5."):
        # Linux CI checks the Capstone 5 API; package and native-core patch versions
        # can differ between distribution builds.
        raise RuntimeError("Capstone 5.x is required for the Linux-side validation; loaded {}.".format(version))
    return capstone


def make_engine(capstone, machine: int, elf_class: int, endian: str, thumb: bool = False):
    mode = capstone.CS_MODE_BIG_ENDIAN if endian == "big" else capstone.CS_MODE_LITTLE_ENDIAN
    if machine == 183:
        architecture = capstone.CS_ARCH_ARM64
        mode = capstone.CS_MODE_ARM
    elif machine == 40:
        architecture = capstone.CS_ARCH_ARM
        mode |= capstone.CS_MODE_THUMB if thumb else capstone.CS_MODE_ARM
    elif machine == 62:
        architecture, mode = capstone.CS_ARCH_X86, capstone.CS_MODE_64
    elif machine == 3:
        architecture, mode = capstone.CS_ARCH_X86, capstone.CS_MODE_32
    else:
        return None
    engine = capstone.Cs(architecture, mode)
    engine.detail = True
    engine.skipdata = True
    return engine


def instruction_text(insn) -> str:
    operands = (" " + insn.op_str) if insn.op_str else ""
    return "0x{:x}: {:<9}{}".format(insn.address, insn.mnemonic, operands)


def instruction_references(insn, capstone, machine: int):
    references = set()
    for operand in getattr(insn, "operands", []):
        if operand.type == capstone.CS_OP_IMM:
            try:
                references.add(int(operand.imm) & 0xFFFFFFFFFFFFFFFF)
            except Exception:
                pass
        elif operand.type == capstone.CS_OP_MEM:
            try:
                base = insn.reg_name(operand.mem.base).lower()
                if machine == 62 or machine == 3:
                    if base == "rip":
                        references.add(
                            (insn.address + insn.size + int(operand.mem.disp))
                            & 0xFFFFFFFFFFFFFFFF
                        )
                elif machine == 40 and base == "pc":
                    pc_bias = 4 if insn.size == 2 else 8
                    references.add(
                        (insn.address + pc_bias + int(operand.mem.disp))
                        & 0xFFFFFFFFFFFFFFFF
                    )
            except Exception:
                pass
    return references


def find_string_xrefs(data: bytes, layout, strings, capstone):
    targets = defaultdict(list)
    page_targets = defaultdict(list)
    for index, item in enumerate(strings):
        if item["address"] is None:
            continue
        targets[item["address"]].append(index)
        if layout["machine"] == 183:
            page_targets[item["address"] & ~0xFFF].append(index)

    results = []
    seen = set()
    instructions_scanned = 0
    code_bytes_scanned = 0
    notes = []
    for section in layout["sections"]:
        if not (section["flags"] & 4) or section["type"] == 8 or section["size"] <= 0:
            continue
        if section["offset"] + section["size"] > len(data):
            continue
        if section["size"] > MAX_CODE_BYTES_PER_FILE:
            notes.append("{} skipped (executable section exceeds per-file scan limit)".format(section["name"]))
            continue
        if code_bytes_scanned + section["size"] > MAX_CODE_BYTES_TOTAL:
            notes.append("Further executable sections skipped at total code-scan limit.")
            break

        engine = make_engine(
            capstone, layout["machine"], layout["class"], layout["endian"]
        )
        if engine is None:
            return results, instructions_scanned, code_bytes_scanned, "Architecture not supported by Capstone."
        code_bytes_scanned += section["size"]
        code = data[section["offset"]:section["offset"] + section["size"]]
        recent = deque(maxlen=4)
        pending = []
        for insn in engine.disasm(code, section["addr"]):
            instructions_scanned += 1
            if getattr(insn, "is_data", False):
                continue
            line = instruction_text(insn)

            still_pending = []
            for item in pending:
                if item["remaining"] > 0:
                    item["window"].append(line)
                    item["remaining"] -= 1
                if item["remaining"] <= 0:
                    results.append(item)
                else:
                    still_pending.append(item)
            pending = still_pending

            refs = instruction_references(insn, capstone, layout["machine"])
            matched = set()
            for address in refs:
                matched.update(targets.get(address, []))
            if layout["machine"] == 183 and insn.mnemonic.lower() == "adrp":
                for address in refs:
                    matched.update(page_targets.get(address & ~0xFFF, []))

            for string_index in sorted(matched):
                key = (string_index, insn.address)
                already = sum(1 for old in results if old["key"][0] == string_index)
                already += sum(1 for old in pending if old["key"][0] == string_index)
                if key in seen or already >= MAX_XREFS_PER_STRING:
                    continue
                seen.add(key)
                pending.append({
                    "key": key,
                    "string_index": string_index,
                    "address": insn.address,
                    "section": section["name"],
                    "window": list(recent) + [line],
                    "remaining": 5,
                    "kind": (
                        "AArch64 ADRP page candidate"
                        if layout["machine"] == 183 and insn.mnemonic.lower() == "adrp"
                        else "direct address reference candidate"
                    ),
                })
                if len(results) + len(pending) >= MAX_XREFS_PER_FILE:
                    break
            recent.append(line)
            if len(results) >= MAX_XREFS_PER_FILE:
                break
        results.extend(pending)
        if len(results) >= MAX_XREFS_PER_FILE:
            results = results[:MAX_XREFS_PER_FILE]
            notes.append("Cross-reference cap reached; additional sites were omitted.")
            break

    note = "; ".join(notes) if notes else "All executable sections within limits were scanned."
    return results, instructions_scanned, code_bytes_scanned, note


def relevant_function_symbols(symbols, layout):
    candidates = []
    for symbol in symbols:
        if symbol["type"] != 2 or symbol["section_index"] <= 0:
            continue
        if symbol["section_index"] >= len(layout["sections"]):
            continue
        if not MARKER_RE.search(symbol["name"]):
            continue
        section = layout["sections"][symbol["section_index"]]
        if not (section["flags"] & 4):
            continue
        raw_value = symbol["value"]
        thumb = layout["machine"] == 40 and bool(raw_value & 1)
        value = raw_value & ~1 if layout["machine"] == 40 else raw_value
        if value < section["addr"] or value >= section["addr"] + section["size"]:
            continue
        candidates.append({**symbol, "value": value, "thumb": thumb, "section": section})
    candidates.sort(key=lambda item: (item["section"]["index"], item["value"], item["name"]))
    return candidates


def disassemble_relevant_functions(data: bytes, layout, symbols, capstone):
    functions = relevant_function_symbols(symbols, layout)
    output = []
    total_instructions = 0
    for function_index, symbol in enumerate(functions[:MAX_RELEVANT_FUNCTIONS_PER_FILE]):
        section = symbol["section"]
        start = section["offset"] + symbol["value"] - section["addr"]
        size = symbol["size"]
        if size <= 0:
            later = [
                other["value"] for other in functions
                if other["section"]["index"] == section["index"] and other["value"] > symbol["value"]
            ]
            size = min(later) - symbol["value"] if later else 2048
        size = min(size, MAX_FUNCTION_BYTES, len(data) - start)
        if size <= 0 or start < 0 or start + size > len(data):
            continue
        thumb = bool(symbol.get("thumb", False))
        engine = make_engine(
            capstone, layout["machine"], layout["class"], layout["endian"], thumb=thumb
        )
        if engine is None:
            continue
        instructions = []
        code = data[start:start + size]
        for insn in engine.disasm(code, symbol["value"]):
            if getattr(insn, "is_data", False):
                continue
            instructions.append(instruction_text(insn))
            if len(instructions) >= MAX_FUNCTION_INSTRUCTIONS:
                break
        if not instructions:
            continue
        total_instructions += len(instructions)
        output.append({
            "name": safe_preview(symbol["name"]) or "[symbol withheld]",
            "address": symbol["value"],
            "size": symbol["size"],
            "section": section["name"],
            "binding": symbol["bind"],
            "instructions": instructions,
        })
    return output, len(functions), total_instructions


def inspect_archive(path: Path):
    files = []
    total = 0
    manifest_lines = []
    skipped_note = "No exporter manifest was found."
    candidate_members = 0
    invalid_elf_members = 0
    with tarfile.open(path, mode="r:gz") as archive:
        members = archive.getmembers()
        if len(members) > 10000:
            raise ValueError("archive contains an unexpected number of entries")
        for member in members:
            if not member.isfile():
                continue
            normalized_name = member.name.replace("\\\\", "/")
            parts = [part for part in normalized_name.split("/") if part]
            if parts and parts[-1] == "manifest.tsv":
                source = archive.extractfile(member)
                if source is not None:
                    manifest_lines = source.read(2_000_000).decode("utf-8", "replace").splitlines()
                    skipped_note = "Exporter manifest was present."
            # The exporter stores native files below a directory named "files".
            # Accept the component anywhere in the archive path, not by substring.
            if "files" not in parts:
                continue
            candidate_members += 1
            if member.size <= 0 or member.size > MAX_ARCHIVE_MEMBER:
                continue
            total += member.size
            if total > MAX_TOTAL_INPUT:
                raise ValueError("archive exceeds supported total input size")
            if len(files) >= MAX_FILES:
                raise ValueError("archive contains more native files than the 96-file safety limit")
            source = archive.extractfile(member)
            if source is None:
                continue
            data = source.read(MAX_ARCHIVE_MEMBER + 1)
            if len(data) != member.size:
                raise ValueError("archive member size mismatch")
            layout = elf_layout(data)
            if layout is None:
                invalid_elf_members += 1
                continue
            basename = Path(member.name).name
            files.append({
                "name": basename, "data": data, "layout": layout,
                "sha256": sha256_bytes(data),
            })
    if not files:
        raise ValueError(
            "no readable ELF files found; native file entries under 'files': {}; invalid ELF headers: {}".format(
                candidate_members, invalid_elf_members
            )
        )
    if manifest_lines:
        skipped_note = "Exporter manifest was present."
    return files, manifest_lines, skipped_note


def build_report(files, archive_name: str, manifest_lines, capstone):
    lines = [
        "KPP NATIVE BRIDGE — COMPREHENSIVE OFFLINE STATIC ANALYSIS",
        "=" * 78,
        "Input archive: {}".format(Path(archive_name).name),
        "ELF files fully inspected: {}".format(len(files)),
        "Disassembly backend: Capstone {}".format(CAPSTONE_VERSION),
        "Coverage: ELF sections, symbol tables, imports, relocations, selected strings,",
        "native function disassembly and code references to marker strings.",
        "No binary was executed or modified. No LIPC request or browser action was sent.",
        "No network access, upload, paste service or external lookup was used.",
        "No page text, cookies, browser history, process IDs, command lines or account data were collected.",
        "",
        "EXPORT MANIFEST",
        "-" * 78,
    ]
    if manifest_lines:
        for row in manifest_lines[:100]:
            parts = row.split("\t")
            if len(parts) >= 4:
                lines.append(
                    "- {}: {} ({} bytes; SHA256 {})".format(parts[0], parts[1], parts[2], parts[3])
                )
        if len(manifest_lines) > 100:
            lines.append("- Further manifest rows omitted from report.")
    else:
        lines.append("No manifest.tsv was present in the archive.")

    lines.extend(["", "ELF INVENTORY", "-" * 78])
    for item in files:
        layout = item["layout"]
        executable_sections = [
            section for section in layout["sections"]
            if section["flags"] & 4 and section["size"] > 0
        ]
        lines.append(
            "- {}: ELF{} {}, {}; {:,} bytes; {} executable section(s); SHA256 {}".format(
                item["name"], layout["class"], layout["endian"], machine_name(layout["machine"]),
                len(item["data"]), len(executable_sections), item["sha256"]
            )
        )

    total_symbols = total_strings = total_relocations = total_functions = total_xrefs = 0
    total_instructions = 0
    total_code_scanned = 0
    for file_index, item in enumerate(files):
        data, layout = item["data"], item["layout"]
        symbols, symbol_tables = parse_symbol_tables(data, layout)
        strings = extract_marker_strings(data, layout)
        relocations = parse_relocations(data, layout, symbol_tables)
        functions, function_count, function_instruction_count = disassemble_relevant_functions(
            data, layout, symbols, capstone
        )
        xrefs, instruction_count, code_bytes, scan_note = find_string_xrefs(
            data, layout, strings, capstone
        )
        total_symbols += len(symbols)
        total_strings += len(strings)
        total_relocations += len(relocations)
        total_functions += len(functions)
        total_xrefs += len(xrefs)
        total_instructions += instruction_count + function_instruction_count
        total_code_scanned += code_bytes

        lines.extend([
            "",
            "=" * 78,
            "FILE {} OF {}: {}".format(file_index + 1, len(files), item["name"]),
            "=" * 78,
            "Architecture: ELF{} {} {}".format(layout["class"], layout["endian"], machine_name(layout["machine"])),
            "Entry point: 0x{:x}".format(layout["entry"]),
            "Marker symbols found: {}".format(len(symbols)),
            "Marker strings found: {}".format(len(strings)),
            "Relevant relocations found: {}".format(len(relocations)),
            "Named relevant functions disassembled: {} of {}".format(len(functions), function_count),
            "Executable bytes scanned for string references: {:,}".format(code_bytes),
            "Instructions decoded during reference scan: {:,}".format(instruction_count),
            "Scan note: {}".format(scan_note),
        ])

        lines.extend(["", "RELEVANT SYMBOLS", "-" * 78])
        if symbols:
            for symbol in symbols[:MAX_FINDINGS_PER_FILE]:
                section_name = (
                    layout["sections"][symbol["section_index"]]["name"]
                    if 0 < symbol["section_index"] < len(layout["sections"])
                    else ("UND/import" if symbol["section_index"] == 0 else "ABS/other")
                )
                kind = {0: "NOTYPE", 1: "OBJECT", 2: "FUNC", 3: "SECTION", 4: "FILE"}.get(symbol["type"], str(symbol["type"]))
                lines.append(
                    "  {} [{}; {}; value=0x{:x}; size={}]".format(
                        symbol["preview"], kind, section_name, symbol["value"], symbol["size"]
                    )
                )
        else:
            lines.append("  No marker-matching symbol names found.")

        lines.extend(["", "RELEVANT RELOCATIONS / IMPORT REFERENCES", "-" * 78])
        if relocations:
            for relocation in relocations:
                lines.append(
                    "  {} -> {} at 0x{:x} (relocation type {}; {})".format(
                        relocation["symbol"], relocation["target_section"],
                        relocation["offset"], relocation["type"], relocation["relocation_section"]
                    )
                )
        else:
            lines.append("  No marker-matching relocation names found.")

        lines.extend(["", "MARKER STRINGS", "-" * 78])
        if strings:
            for string in strings[:MAX_FINDINGS_PER_FILE]:
                address = "0x{:x}".format(string["address"]) if string["address"] is not None else "not mapped"
                lines.append(
                    "  {} | {} | file offset 0x{:x} | virtual address {} | {}".format(
                        string["text"], string["section"], string["offset"], address, string["section"]
                    )
                )
        else:
            lines.append("  No browser/bridge marker strings found.")

        lines.extend(["", "DISASSEMBLED RELEVANT FUNCTIONS", "-" * 78])
        if functions:
            for function in functions:
                lines.append(
                    "\n  FUNCTION {} at 0x{:x} ({} bytes declared; section {})".format(
                        function["name"], function["address"], function["size"], function["section"]
                    )
                )
                for instruction in function["instructions"]:
                    lines.append("    " + instruction)
        else:
            lines.append("  No named marker-matching function symbols were available.")

        lines.extend(["", "CODE REFERENCES TO MARKER STRINGS", "-" * 78])
        if xrefs:
            for xref in xrefs:
                string = strings[xref["string_index"]]
                lines.append(
                    "\n  {}: {} (string at 0x{})".format(
                        xref["kind"], string["text"],
                        "{:x}".format(string["address"]) if string["address"] is not None else "unknown"
                    )
                )
                lines.append(
                    "  Reference site: 0x{:x} in {}; candidate containing function: {}".format(
                        xref["address"], xref["section"],
                        next(
                            (
                                function["name"] for function in functions
                                if function["section"] == xref["section"]
                                and function["address"] <= xref["address"] <
                                    function["address"] + max(function["size"], 1)
                            ),
                            "not resolved from named symbols"
                        )
                    )
                )
                for instruction in xref["window"]:
                    lines.append("    " + instruction)
        else:
            lines.append("  No direct code references were resolved for the marker strings.")

    lines.extend([
        "",
        "=" * 78,
        "COVERAGE SUMMARY",
        "=" * 78,
        "ELF files inspected: {}".format(len(files)),
        "Marker symbols: {}".format(total_symbols),
        "Marker strings: {}".format(total_strings),
        "Relevant relocations: {}".format(total_relocations),
        "Named functions disassembled: {}".format(total_functions),
        "String-reference sites: {}".format(total_xrefs),
        "Executable bytes scanned: {:,}".format(total_code_scanned),
        "Decoded instructions (scan plus named functions): {:,}".format(total_instructions),
        "",
        "HOW TO READ THE RESULTS",
        "-" * 78,
        "A named function is disassembled only when the ELF contains a usable function symbol.",
        "A code reference is a static address-pattern match; AArch64 ADRP page matches are candidates",
        "and should be checked alongside the nearby ADD/LDR instructions shown in the window.",
        "Static analysis can miss indirect references, stripped functions, runtime-generated code,",
        "and data-flow that crosses several instructions or libraries. A lead is not proof of a usable API.",
        "No function was called and no live browser test was attempted.",
        "",
        "SAFETY",
        "-" * 78,
        "Do not guess invokeAction values or send LIPC writes. Any future live check must be based",
        "on a confirmed method implementation and a verified read-only contract.",
        "The helper processed all ELF files it found in the supplied archive. It cannot inspect a",
        "library that the Kindle exporter did not place in that archive.",
        "",
        "This is one comprehensive static-analysis pass of the supplied archive. All outputs remain local.",
    ])
    report = "\n".join(lines) + "\n"
    if len(report) > MAX_REPORT_CHARS:
        report = report[:MAX_REPORT_CHARS] + "\n[Report truncated at the 1.4 MB safety limit.]\n"
    return report


def main() -> int:
    if sys.version_info < (3, 8):
        print("FAILURE: Python 3.8 or later is required.", file=sys.stderr)
        return 2
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
        files, manifest_lines, manifest_note = inspect_archive(archive_path)
        capstone = load_capstone(Path(__file__).resolve().parent)
        report = build_report(files, str(archive_path), manifest_lines, capstone)
    except (OSError, tarfile.TarError, ValueError, struct.error, zipfile.BadZipFile, RuntimeError, ImportError) as error:
        print("FAILURE: Could not complete the native inspection ({}).".format(type(error).__name__))
        print(str(error))
        return 1

    report_path = archive_path.with_name("KPP-Native-Bridge-Findings.txt")
    try:
        report_path.write_text(report, encoding="utf-8", newline="\n")
    except OSError as error:
        print("FAILURE: Could not save the findings report ({}).".format(type(error).__name__))
        return 1

    print("SUCCESS: Comprehensive offline native inspection completed.")
    print("ELF files inspected: {}".format(len(files)))
    print("Findings report saved locally: {}".format(report_path))
    print("The report includes relevant function disassembly and code-reference candidates.")
    print("No Kindle connection, network connection, upload or paste service was used.")
    print("Attach KPP-Native-Bridge-Findings.txt in ChatGPT.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
