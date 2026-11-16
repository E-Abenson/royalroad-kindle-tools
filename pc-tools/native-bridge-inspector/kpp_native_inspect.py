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
import shutil
from collections import defaultdict, deque
from pathlib import Path

CAPSTONE_VERSION = "5.0.9"
CAPSTONE_WHEEL = "capstone-5.0.9-py3-none-win_amd64.whl"
CAPSTONE_SHA256 = "732cedbbb56d42e723f14d7af6387f1454194a820b4b96b56d1e53f865ef85d0"

MAX_ARCHIVE_MEMBER = 120_000_000
MAX_TOTAL_INPUT = 400_000_000
MAX_FILES = 128
MAX_FINDINGS_PER_FILE = 180
MAX_FINDINGS_TOTAL = 2400
MAX_CODE_BYTES_PER_FILE = 55_000_000
MAX_CODE_BYTES_TOTAL = 320_000_000
MAX_RELEVANT_FUNCTIONS_PER_FILE = 100
MAX_FUNCTION_BYTES = 30_000
MAX_FUNCTION_INSTRUCTIONS = 160
MAX_XREFS_PER_FILE = 120
MAX_XREFS_PER_STRING = 16
MAX_REPORT_CHARS = 3_000_000
INSPECTOR_VERSION = "0.1.110"
CHECKPOINT_FORMAT_VERSION = 1
DEFAULT_BATCH_SIZE = 8
PROGRESS_INSTRUCTION_INTERVAL = 2_000_000

MARKER_RE = re.compile(
    r"invokeAction|getLastOpenPage|getAllSettings|webViewURL|"
    r"webViewURLRedirectActionId|navigateToKPPBrowser|redirectToWebView|"
    r"BrowserDataProvider|ApplicationLipcProvider|NavigationInterface|"
    r"KPPBrowser|KPPNavigation|WebViewURLRedirectActionHandler|"
    r"evaluateJavaScript|evaluateJavascript|executeJavaScript|"
    r"executeJavascript|runJavaScript|loadUrl|loadURL|loadHTMLString|"
    r"WKWebView|WebKit|JavaScriptCore|JSContext|JSValue|"
    r"ContentController|ScriptMessageHandler|messageHandlers|"
    r"pageSource|getPageSource|getHTML|readHTML|executeScript|"
    r"innerText|textContent|outerHTML|documentElement|"
    r"getStringProperty|setStringProperty|getIntProperty|setIntProperty|"
    r"getHashArrayProperty|registerProperty|LIPC|lipc|"
    r"browser|navigation",
    re.IGNORECASE,
)
STRING_MARKER_RE = re.compile(
    MARKER_RE.pattern + r"|webview|webkit|javascript|browser|navigation|hermes",
    re.IGNORECASE,
)
FUNCTION_MARKER_RE = re.compile(
    r"invokeAction|getLastOpenPage|getAllSettings|webViewURL|"
    r"webViewURLRedirectActionId|navigateToKPPBrowser|redirectToWebView|"
    r"BrowserDataProvider|ApplicationLipcProvider|NavigationInterface|"
    r"KPPBrowser|KPPNavigation|WebViewURLRedirectActionHandler|"
    r"evaluateJavaScript|evaluateJavascript|executeJavaScript|"
    r"executeJavascript|runJavaScript|loadUrl|loadURL|loadHTMLString|"
    r"pageSource|getPageSource|getHTML|readHTML|executeScript|"
    r"getStringProperty|setStringProperty|getIntProperty|setIntProperty|"
    r"getHashArrayProperty|registerProperty",
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
        if not STRING_MARKER_RE.search(raw):
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
    """Load a local Capstone 5.x backend without requiring one exact patch version."""
    if sys.platform == "win32":
        wheel = script_dir / CAPSTONE_WHEEL
        if wheel.is_file():
            actual = sha256_file(wheel)
            if actual.lower() != CAPSTONE_SHA256:
                raise RuntimeError("The bundled Capstone wheel failed its SHA256 integrity check.")

            runtime = script_dir / (".capstone-runtime-" + CAPSTONE_VERSION)
            # Always rebuild from the verified wheel; never reuse stale extracted files.
            if runtime.exists():
                shutil.rmtree(runtime)
            runtime.mkdir(parents=True, exist_ok=False)
            try:
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
                                shutil.copyfileobj(source, output)
            except Exception:
                shutil.rmtree(runtime, ignore_errors=True)
                raise

            # A prior failed import must not pin an already-loaded system copy.
            sys.modules.pop("capstone", None)
            sys.path.insert(0, str(runtime))
            importlib.invalidate_caches()

    try:
        import capstone
    except ImportError as error:
        raise RuntimeError(
            "Capstone is unavailable. Use the complete inspector ZIP, which includes "
            "the verified Windows wheel, or install any Capstone 5.x release."
        ) from error

    version = str(getattr(capstone, "__version__", "unknown"))
    # 5.0.7, 5.0.9 and later compatible 5.x patch releases are accepted.
    if not version.startswith("5."):
        raise RuntimeError(
            "Capstone 5.x is required; loaded version {}. The exact patch version is not restricted.".format(version)
        )
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


def instruction_references(insn, capstone, machine: int, thumb: bool = False):
    references = set()
    # Do not call this function for Capstone skip-data pseudo-instructions (id 0).
    for operand in getattr(insn, "operands", []):
        if operand.type == capstone.CS_OP_IMM:
            try:
                references.add(int(operand.imm) & 0xFFFFFFFFFFFFFFFF)
            except Exception:
                pass
        elif operand.type == capstone.CS_OP_MEM:
            try:
                base = insn.reg_name(operand.mem.base).lower()
                if machine in (62, 3) and base == "rip":
                    references.add(
                        (insn.address + insn.size + int(operand.mem.disp))
                        & 0xFFFFFFFFFFFFFFFF
                    )
                elif machine == 40 and base in ("pc", "r15"):
                    # ARM reads PC as instruction address + 8; Thumb uses +4.
                    pc_bias = 4 if thumb else 8
                    references.add(
                        (insn.address + pc_bias + int(operand.mem.disp))
                        & 0xFFFFFFFFFFFFFFFF
                    )
            except Exception:
                pass
    return references




def find_string_xrefs(data: bytes, layout, strings, capstone, progress_callback=None):
    targets = defaultdict(list)
    page_targets = defaultdict(list)
    for index, item in enumerate(strings):
        if item["address"] is None:
            continue
        targets[item["address"]].append(index)
        if layout["machine"] == 183:
            page_targets[item["address"] & ~0xFFF].append(index)

    if not targets:
        if progress_callback:
            progress_callback(
                "Skipping code scan: this ELF has no marker strings mapped to executable addresses."
            )
        return (
            [], 0, 0,
            "Code scan skipped because no mapped marker-string addresses were found.",
            0,
        )

    results = []
    seen = set()
    instructions_scanned = 0
    code_bytes_scanned = 0
    skipped_data = 0
    notes = []

    executable_sections = [
        section for section in layout["sections"]
        if (section["flags"] & 4) and section["type"] != 8 and section["size"] > 0
    ]
    total_executable_sections = len(executable_sections)
    for section_number, section in enumerate(executable_sections, start=1):
        if not (section["flags"] & 4) or section["type"] == 8 or section["size"] <= 0:
            continue
        if section["offset"] + section["size"] > len(data):
            continue
        if section["size"] > MAX_CODE_BYTES_PER_FILE:
            notes.append("{} skipped (executable section exceeds per-file scan limit)".format(section["name"]))
            continue

        # ARM Kindle executables can mix ARM and Thumb functions. Scan both
        # instruction sets; other architectures have one applicable mode here.
        scan_modes = (False, True) if layout["machine"] == 40 else (False,)
        code = data[section["offset"]:section["offset"] + section["size"]]

        for mode_number, thumb_mode in enumerate(scan_modes, start=1):
            mode_label = "Thumb" if layout["machine"] == 40 and thumb_mode else (
                "ARM" if layout["machine"] == 40 else machine_name(layout["machine"])
            )
            if progress_callback:
                progress_callback(
                    "Section {}/{} — {} pass ({} bytes)".format(
                        section_number, total_executable_sections, mode_label, section["size"]
                    )
                )
            last_progress_instructions = instructions_scanned
            if code_bytes_scanned + section["size"] > MAX_CODE_BYTES_TOTAL:
                notes.append("Further executable scans skipped at total code-scan limit.")
                break

            engine = make_engine(
                capstone, layout["machine"], layout["class"], layout["endian"],
                thumb=thumb_mode
            )
            if engine is None:
                return (
                    results, instructions_scanned, code_bytes_scanned,
                    "Architecture not supported by Capstone.", skipped_data
                )

            code_bytes_scanned += section["size"]
            recent = deque(maxlen=4)
            pending = []
            for insn in engine.disasm(code, section["addr"]):
                instructions_scanned += 1
                if (
                    progress_callback
                    and instructions_scanned - last_progress_instructions
                    >= PROGRESS_INSTRUCTION_INTERVAL
                ):
                    section_offset = max(0, min(section["size"], insn.address - section["addr"]))
                    section_percent = int(section_offset * 100 / section["size"])
                    progress_callback(
                        "{} pass: {:,} instructions scanned; section approximately {}%".format(
                            mode_label, instructions_scanned, section_percent
                        )
                    )
                    last_progress_instructions = instructions_scanned

                # Capstone skip-data records have id 0. Do not inspect op_str,
                # operands, or any detail fields on these pseudo-instructions.
                if getattr(insn, "id", 0) == 0:
                    skipped_data += 1
                    continue

                line = instruction_text(insn)
                still_pending = []
                for pending_item in pending:
                    if pending_item["remaining"] > 0:
                        pending_item["window"].append(line)
                        pending_item["remaining"] -= 1
                    if pending_item["remaining"] <= 0:
                        results.append(pending_item)
                    else:
                        still_pending.append(pending_item)
                pending = still_pending

                refs = instruction_references(
                    insn, capstone, layout["machine"], thumb=thumb_mode
                )
                matched = set()
                for address in refs:
                    matched.update(targets.get(address, []))
                if layout["machine"] == 183 and insn.mnemonic.lower() == "adrp":
                    for address in refs:
                        matched.update(page_targets.get(address & ~0xFFF, []))

                for string_index in sorted(matched):
                    key = (string_index, insn.address, thumb_mode)
                    already = sum(
                        1 for old in results
                        if old["key"][0] == string_index
                    )
                    already += sum(
                        1 for old in pending
                        if old["key"][0] == string_index
                    )
                    if key in seen or already >= MAX_XREFS_PER_STRING:
                        continue
                    seen.add(key)
                    if layout["machine"] == 40:
                        mode_label = "Thumb" if thumb_mode else "ARM"
                    else:
                        mode_label = machine_name(layout["machine"])
                    pending.append({
                        "key": key,
                        "string_index": string_index,
                        "address": insn.address,
                        "section": section["name"],
                        "window": list(recent) + [line],
                        "remaining": 5,
                        "kind": (
                            "{} AArch64 ADRP page candidate".format(mode_label)
                            if layout["machine"] == 183 and insn.mnemonic.lower() == "adrp"
                            else "{} direct address-reference candidate".format(mode_label)
                        ),
                    })
                    if len(results) + len(pending) >= MAX_XREFS_PER_FILE:
                        break

                recent.append(line)
                if len(results) + len(pending) >= MAX_XREFS_PER_FILE:
                    break

            results.extend(pending)
            if len(results) >= MAX_XREFS_PER_FILE:
                results = results[:MAX_XREFS_PER_FILE]
                notes.append("Cross-reference cap reached; further sites were omitted.")
                break
        if len(results) >= MAX_XREFS_PER_FILE:
            break

    note = "; ".join(notes) if notes else "All executable sections scanned in supported instruction modes."
    if progress_callback:
        progress_callback(
            "Code-reference scan finished: {:,} instructions; {:,} executable bytes.".format(
                instructions_scanned, code_bytes_scanned
            )
        )
    return results, instructions_scanned, code_bytes_scanned, note, skipped_data




def function_priority(name: str) -> int:
    if FUNCTION_MARKER_RE.search(name):
        return 3
    if MARKER_RE.search(name):
        return 2
    return 0


def relevant_function_symbols(symbols, layout):
    candidates = []
    for symbol in symbols:
        if symbol["type"] != 2:
            continue

        raw_value = symbol["value"]
        thumb = layout["machine"] == 40 and bool(raw_value & 1)
        value = raw_value & ~1 if layout["machine"] == 40 else raw_value

        # Prefer the symbol's declared section, but recover from bad/missing
        # section indices by resolving its value against executable sections.
        section = None
        section_index = symbol["section_index"]
        if 0 < section_index < len(layout["sections"]):
            candidate_section = layout["sections"][section_index]
            if candidate_section["flags"] & 4:
                section = candidate_section
        if section is None:
            candidate_section = section_for_address(layout, value)
            if candidate_section is not None and (candidate_section["flags"] & 4):
                section = candidate_section
        if section is None or not (section["addr"] <= value < section["addr"] + section["size"]):
            continue

        priority = function_priority(symbol["name"])
        if priority <= 0:
            continue
        candidates.append({
            **symbol, "value": value, "thumb": thumb,
            "section": section, "priority": priority
        })

    # Highest-value browser/bridge functions are disassembled first, not the
    # first generic C++/React Native symbols encountered in the symbol table.
    candidates.sort(
        key=lambda item: (
            -item["priority"], item["section"]["index"],
            item["value"], item["name"]
        )
    )
    deduplicated = []
    seen = set()
    for item in candidates:
        key = (item["name"], item["value"], item["section"]["index"])
        if key not in seen:
            seen.add(key)
            deduplicated.append(item)
    return deduplicated

def disassemble_relevant_functions(data: bytes, layout, symbols, capstone):
    functions = relevant_function_symbols(symbols, layout)
    output = []
    total_instructions = 0

    for symbol in functions[:MAX_RELEVANT_FUNCTIONS_PER_FILE]:
        section = symbol["section"]
        start = section["offset"] + symbol["value"] - section["addr"]
        size = symbol["size"]
        if size <= 0:
            later = [
                other["value"] for other in functions
                if other["section"]["index"] == section["index"]
                and other["value"] > symbol["value"]
            ]
            size = min(later) - symbol["value"] if later else 2048
        size = min(size, MAX_FUNCTION_BYTES, len(data) - start)
        if size <= 0 or start < 0 or start + size > len(data):
            continue

        thumb = bool(symbol.get("thumb", False))
        engine = make_engine(
            capstone, layout["machine"], layout["class"],
            layout["endian"], thumb=thumb
        )
        if engine is None:
            continue

        instructions = []
        code = data[start:start + size]
        for insn in engine.disasm(code, symbol["value"]):
            # id 0 is Capstone's skip-data pseudo-instruction. Skip it before
            # instruction_text accesses op_str or any operand details.
            if getattr(insn, "id", 0) == 0:
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
            "priority": symbol["priority"],
            "mode": "Thumb" if thumb else ("ARM" if layout["machine"] == 40 else machine_name(layout["machine"])),
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
    print("Opening archive and checking its file index...", flush=True)
    with tarfile.open(path, mode="r:gz") as archive:
        members = archive.getmembers()
        if len(members) > 10000:
            raise ValueError("archive contains an unexpected number of entries")
        candidate_total = sum(
            1 for member in members
            if member.isfile()
            and "files" in [
                part for part in member.name.replace("\\\\", "/").split("/") if part
            ]
        )
        print("Archive contains {} native-file entries.".format(candidate_total), flush=True)
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
            if candidate_members == 1 or candidate_members % DEFAULT_BATCH_SIZE == 0:
                print(
                    "Loading ELF inputs: {} of {} archive entries...".format(
                        candidate_members, candidate_total
                    ),
                    flush=True,
                )
            if member.size <= 0 or member.size > MAX_ARCHIVE_MEMBER:
                continue
            total += member.size
            if total > MAX_TOTAL_INPUT:
                raise ValueError("archive exceeds supported total input size")
            if len(files) >= MAX_FILES:
                raise ValueError(
                    "archive contains more native files than the {}-file safety limit".format(MAX_FILES)
                )
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
    print("Loaded {} valid ELF files ({} bytes total).".format(len(files), total), flush=True)
    if not files:
        raise ValueError(
            "no readable ELF files found; native file entries under 'files': {}; invalid ELF headers: {}".format(
                candidate_members, invalid_elf_members
            )
        )
    if manifest_lines:
        skipped_note = "Exporter manifest was present."
    return files, manifest_lines, skipped_note


def cross_file_symbol_links(files):
    """Match browser/bridge imports in one ELF to exact definitions in another."""
    exports = defaultdict(set)
    imports = []
    for item in files:
        _, tables = parse_symbol_tables(item["data"], item["layout"])
        seen = set()
        for table_symbols in tables.values():
            for symbol in table_symbols:
                name = symbol["name"]
                if not name or not MARKER_RE.search(name):
                    continue
                key = (name, symbol["section_index"], symbol["type"])
                if key in seen:
                    continue
                seen.add(key)
                if symbol["section_index"] == 0:
                    imports.append((item["name"], name))
                elif symbol["type"] == 2:
                    exports[name].add(item["name"])

    links = []
    for importer, name in imports:
        providers = sorted(provider for provider in exports.get(name, set()) if provider != importer)
        for provider in providers:
            preview = safe_preview(name)
            if preview:
                links.append((importer, provider, preview))
    links.sort()
    return links


def load_cached_file_result(cache_file: Path, archive_sha256: str, item):
    """Return a completed per-ELF result only when every cache identity matches."""
    if not cache_file.is_file():
        return None
    try:
        payload = json.loads(cache_file.read_text(encoding="utf-8"))
    except (OSError, ValueError, json.JSONDecodeError):
        return None
    if not isinstance(payload, dict):
        return None
    if (
        payload.get("inspector_version") != INSPECTOR_VERSION
        or payload.get("checkpoint_format") != CHECKPOINT_FORMAT_VERSION
        or payload.get("archive_sha256") != archive_sha256
        or payload.get("elf_sha256") != item["sha256"]
        or payload.get("elf_name") != item["name"]
    ):
        return None
    result = payload.get("result")
    return result if isinstance(result, dict) else None


def save_cached_file_result(cache_file: Path, archive_sha256: str, item, result):
    """Atomically persist one completed ELF so an interrupted run can resume."""
    payload = {
        "inspector_version": INSPECTOR_VERSION,
        "checkpoint_format": CHECKPOINT_FORMAT_VERSION,
        "archive_sha256": archive_sha256,
        "elf_sha256": item["sha256"],
        "elf_name": item["name"],
        "result": result,
    }
    cache_file.parent.mkdir(parents=True, exist_ok=True)
    temporary = cache_file.with_suffix(cache_file.suffix + ".tmp")
    temporary.write_text(
        json.dumps(payload, separators=(",", ":"), ensure_ascii=False),
        encoding="utf-8",
    )
    temporary.replace(cache_file)


def build_report(
    files, archive_name: str, manifest_lines, capstone,
    checkpoint_dir: Path | None = None, archive_sha256: str | None = None,
    batch_size: int = DEFAULT_BATCH_SIZE,
):
    backend_version = str(getattr(capstone, "__version__", "unknown"))
    archive_path = Path(archive_name)
    if archive_sha256 is None:
        archive_sha256 = sha256_file(archive_path)
    if checkpoint_dir is None:
        checkpoint_dir = archive_path.with_name(
            "KPP-Native-Bridge-Checkpoint-" + archive_sha256[:12]
        )
    checkpoint_dir.mkdir(parents=True, exist_ok=True)
    if batch_size < 1:
        batch_size = DEFAULT_BATCH_SIZE
    total_batches = (len(files) + batch_size - 1) // batch_size
    print(
        "Starting analysis: {} ELF files, {} batches of up to {}.".format(
            len(files), total_batches, batch_size
        ),
        flush=True,
    )
    print("Completed-file checkpoints: {}".format(checkpoint_dir), flush=True)
    lines = [
        "KPP NATIVE BRIDGE — COMPREHENSIVE OFFLINE STATIC ANALYSIS",
        "=" * 78,
        "Input archive: {}".format(Path(archive_name).name),
        "ELF files fully inspected: {}".format(len(files)),
        "Disassembly backend: Capstone {}".format(backend_version),
        "Coverage: ELF sections, symbols/imports/exports, relocations, selected strings,",
        "ARM and Thumb code, browser/bridge function disassembly, static string references,",
        "and exact cross-library symbol links.",
        "No binary was executed or modified. No LIPC request or browser action was sent.",
        "No network access, upload, paste service or external lookup was used.",
        "No process memory, page text, cookies, browser history, URLs, command lines or account data were collected.",
        "",
        "EXPORT MANIFEST",
        "-" * 78,
    ]

    if manifest_lines:
        for row in manifest_lines[:MAX_FILES]:
            parts = row.split("\t")
            if len(parts) >= 4:
                lines.append("- {}: {} ({} bytes; SHA256 {})".format(
                    parts[0], parts[1], parts[2], parts[3]
                ))
        if len(manifest_lines) > MAX_FILES:
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
                item["name"], layout["class"], layout["endian"],
                machine_name(layout["machine"]), len(item["data"]),
                len(executable_sections), item["sha256"]
            )
        )

    links = cross_file_symbol_links(files)
    lines.extend(["", "CROSS-LIBRARY BROWSER/BRIDGE IMPORT LINKS", "-" * 78])
    if links:
        for importer, provider, name in links[:MAX_FINDINGS_TOTAL]:
            lines.append("  {} imports {} -> defined in {}".format(importer, name, provider))
    else:
        lines.append(
            "No exact browser/bridge import-to-definition pairs were found across the supplied ELF files."
        )

    total_symbols = total_strings = total_relocations = total_functions = total_xrefs = 0
    total_instructions = total_code_scanned = total_skipdata = 0

    for file_index, item in enumerate(files):
        data, layout = item["data"], item["layout"]
        batch_number = file_index // batch_size + 1
        if file_index % batch_size == 0:
            print(
                "\nBATCH {}/{} — files {}–{} of {}".format(
                    batch_number, total_batches, file_index + 1,
                    min(file_index + batch_size, len(files)), len(files)
                ),
                flush=True,
            )

        cache_file = checkpoint_dir / (item["sha256"] + ".json")
        cached_result = load_cached_file_result(cache_file, archive_sha256, item)
        if cached_result is not None:
            symbols = cached_result["symbols"]
            strings = cached_result["strings"]
            relocations = cached_result["relocations"]
            functions = cached_result["functions"]
            function_count = cached_result["function_count"]
            function_instruction_count = cached_result["function_instruction_count"]
            xrefs = cached_result["xrefs"]
            instruction_count = cached_result["instruction_count"]
            code_bytes = cached_result["code_bytes"]
            scan_note = cached_result["scan_note"]
            skipped_data = cached_result["skipped_data"]
            print(
                "File {}/{}: {} — resumed from checkpoint.".format(
                    file_index + 1, len(files), item["name"]
                ),
                flush=True,
            )
        else:
            print(
                "File {}/{}: {} — parsing symbols, strings and relocations...".format(
                    file_index + 1, len(files), item["name"]
                ),
                flush=True,
            )
            symbols, symbol_tables = parse_symbol_tables(data, layout)
            strings = extract_marker_strings(data, layout)
            relocations = parse_relocations(data, layout, symbol_tables)

            print(
                "File {}/{}: disassembling named functions...".format(
                    file_index + 1, len(files)
                ),
                flush=True,
            )
            functions, function_count, function_instruction_count = disassemble_relevant_functions(
                data, layout, symbols, capstone
            )

            print(
                "File {}/{}: scanning code for string references...".format(
                    file_index + 1, len(files)
                ),
                flush=True,
            )
            def report_xref_progress(message):
                print("    " + message, flush=True)

            xrefs, instruction_count, code_bytes, scan_note, skipped_data = find_string_xrefs(
                data, layout, strings, capstone,
                progress_callback=report_xref_progress,
            )

            cached_result = {
                "symbols": symbols,
                "strings": strings,
                "relocations": relocations,
                "functions": functions,
                "function_count": function_count,
                "function_instruction_count": function_instruction_count,
                "xrefs": xrefs,
                "instruction_count": instruction_count,
                "code_bytes": code_bytes,
                "scan_note": scan_note,
                "skipped_data": skipped_data,
            }
            try:
                save_cached_file_result(cache_file, archive_sha256, item, cached_result)
                print(
                    "File {}/{}: checkpoint saved.".format(
                        file_index + 1, len(files)
                    ),
                    flush=True,
                )
            except OSError as error:
                print(
                    "WARNING: Could not save checkpoint for {} ({}).".format(
                        item["name"], type(error).__name__
                    ),
                    flush=True,
                )

        total_symbols += len(symbols)
        total_strings += len(strings)
        total_relocations += len(relocations)
        total_functions += len(functions)
        total_xrefs += len(xrefs)
        total_instructions += instruction_count + function_instruction_count
        total_code_scanned += code_bytes
        total_skipdata += skipped_data

        lines.extend([
            "",
            "=" * 78,
            "FILE {} OF {}: {}".format(file_index + 1, len(files), item["name"]),
            "=" * 78,
            "Architecture: ELF{} {} {}".format(
                layout["class"], layout["endian"], machine_name(layout["machine"])
            ),
            "Entry point: 0x{:x}".format(layout["entry"]),
            "Browser/bridge marker symbols found: {}".format(len(symbols)),
            "Browser/bridge marker strings found: {}".format(len(strings)),
            "Relevant relocations found: {}".format(len(relocations)),
            "Priority functions identified: {}".format(function_count),
            "Priority functions disassembled: {}".format(len(functions)),
            "Executable bytes scanned (including ARM+Thumb passes): {:,}".format(code_bytes),
            "Instructions decoded during reference scan: {:,}".format(instruction_count),
            "Skip-data pseudo-instructions safely skipped: {:,}".format(skipped_data),
            "Scan note: {}".format(scan_note),
        ])

        lines.extend(["", "BROWSER / BRIDGE SYMBOLS", "-" * 78])
        if symbols:
            for symbol in symbols[:MAX_FINDINGS_PER_FILE]:
                section_name = (
                    layout["sections"][symbol["section_index"]]["name"]
                    if 0 < symbol["section_index"] < len(layout["sections"])
                    else ("UND/import" if symbol["section_index"] == 0 else "ABS/other")
                )
                kind = {
                    0: "NOTYPE", 1: "OBJECT", 2: "FUNC",
                    3: "SECTION", 4: "FILE"
                }.get(symbol["type"], str(symbol["type"]))
                lines.append(
                    "  {} [{}; {}; value=0x{:x}; size={}]".format(
                        symbol["preview"], kind, section_name,
                        symbol["value"], symbol["size"]
                    )
                )
        else:
            lines.append("  No focused browser/bridge symbol names were found.")

        lines.extend(["", "RELEVANT RELOCATIONS / IMPORT REFERENCES", "-" * 78])
        if relocations:
            for relocation in relocations[:MAX_FINDINGS_PER_FILE]:
                lines.append(
                    "  {} -> {} at 0x{:x} (relocation type {}; {})".format(
                        relocation["symbol"], relocation["target_section"],
                        relocation["offset"], relocation["type"],
                        relocation["relocation_section"]
                    )
                )
        else:
            lines.append("  No focused browser/bridge relocation names were found.")

        lines.extend(["", "BROWSER / BRIDGE STRINGS", "-" * 78])
        if strings:
            for string in strings[:MAX_FINDINGS_PER_FILE]:
                address = (
                    "0x{:x}".format(string["address"])
                    if string["address"] is not None else "not mapped"
                )
                lines.append(
                    "  {} | file offset 0x{:x} | virtual address {} | section {}".format(
                        string["text"], string["offset"], address, string["section"]
                    )
                )
        else:
            lines.append("  No browser/bridge marker strings found.")

        lines.extend(["", "PRIORITY FUNCTION DISASSEMBLY", "-" * 78])
        if functions:
            for function in functions:
                lines.append(
                    "\n  FUNCTION {} at 0x{:x} ({} bytes declared; {}; section {})".format(
                        function["name"], function["address"],
                        function["size"], function["mode"], function["section"]
                    )
                )
                for instruction in function["instructions"]:
                    lines.append("    " + instruction)
        else:
            lines.append(
                "  No priority function symbols could be resolved to executable sections. "
                "The report still includes symbols, strings, relocations and import/export matches."
            )

        lines.extend(["", "STATIC CODE REFERENCES TO MARKER STRINGS", "-" * 78])
        if xrefs:
            for xref in xrefs:
                string = strings[xref["string_index"]]
                lines.append(
                    "\n  {}: {} (string at 0x{})".format(
                        xref["kind"], string["text"],
                        "{:x}".format(string["address"])
                        if string["address"] is not None else "unknown"
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
            lines.append("  No direct code references were resolved for the selected marker strings.")

    lines.extend([
        "",
        "=" * 78,
        "COVERAGE SUMMARY",
        "=" * 78,
        "ELF files inspected: {}".format(len(files)),
        "Focused browser/bridge symbols: {}".format(total_symbols),
        "Browser/bridge strings: {}".format(total_strings),
        "Relevant relocations: {}".format(total_relocations),
        "Priority functions disassembled: {}".format(total_functions),
        "String-reference sites: {}".format(total_xrefs),
        "Executable bytes scanned: {:,}".format(total_code_scanned),
        "Decoded instructions (scan plus named functions): {:,}".format(total_instructions),
        "Skip-data pseudo-instructions safely skipped: {:,}".format(total_skipdata),
        "Cross-library exact symbol links: {}".format(len(links)),
        "",
        "HOW TO READ THE RESULTS",
        "-" * 78,
        "ARM32 executable sections are scanned in both ARM and Thumb modes because one ELF can mix them.",
        "Named functions are disassembled only when a function symbol can be resolved to executable code.",
        "Cross-library links require an exact imported-symbol name to match a defined function symbol in another ELF.",
        "Code-reference matches are static address candidates, not proof of calls or runtime data flow.",
        "Static analysis can miss indirect references, stripped functions, runtime-generated code,",
        "and data flow spanning multiple instructions or libraries. A lead is not proof of a usable API.",
        "No function was called and no live browser test was attempted.",
        "",
        "SAFETY",
        "-" * 78,
        "Do not guess invokeAction values or send LIPC writes. Any live check must be based on a",
        "confirmed method implementation and a verified read-only contract.",
        "The helper only inspected ELF files supplied by the Kindle exporter. It cannot inspect",
        "a mapped library that was unreadable or excluded by the exporter's explicit size/count caps.",
        "",
        "This is offline static analysis only. All inputs and outputs remain local.",
    ])
    report = "\n".join(lines) + "\n"
    print("Combining saved per-file results into the final report...", flush=True)
    if len(report) > MAX_REPORT_CHARS:
        report = report[:MAX_REPORT_CHARS] + "\n[Report truncated at the 3 MB safety limit.]\n"
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

    print("KPP Native Bridge Inspector {}".format(INSPECTOR_VERSION), flush=True)
    print("Input archive: {}".format(archive_path), flush=True)
    checkpoint_dir = None
    try:
        print("Calculating archive checksum...", flush=True)
        archive_sha256 = sha256_file(archive_path)
        checkpoint_dir = archive_path.with_name(
            "KPP-Native-Bridge-Checkpoint-" + archive_sha256[:12]
        )
        files, manifest_lines, manifest_note = inspect_archive(archive_path)
        print("Loading bundled Capstone disassembly engine...", flush=True)
        capstone = load_capstone(Path(__file__).resolve().parent)
        print(
            "Capstone {} ready. Matching cross-library symbols...".format(
                getattr(capstone, "__version__", "unknown")
            ),
            flush=True,
        )
        report = build_report(
            files, str(archive_path), manifest_lines, capstone,
            checkpoint_dir=checkpoint_dir,
            archive_sha256=archive_sha256,
            batch_size=DEFAULT_BATCH_SIZE,
        )
    except KeyboardInterrupt:
        print(
            "\nINTERRUPTED. Completed ELF files have been checkpointed. "
            "Run this same BAT again with the same archive to resume.",
            flush=True,
        )
        if checkpoint_dir is not None:
            print("Checkpoint folder: {}".format(checkpoint_dir), flush=True)
        return 130
    except (OSError, tarfile.TarError, ValueError, struct.error, zipfile.BadZipFile, RuntimeError, ImportError) as error:
        print("FAILURE: Could not complete the native inspection ({}).".format(type(error).__name__))
        print(str(error))
        if checkpoint_dir is not None and checkpoint_dir.exists():
            print("Completed-file checkpoints were kept at: {}".format(checkpoint_dir))
        return 1

    report_path = archive_path.with_name("KPP-Native-Bridge-Findings.txt")
    try:
        print("Writing final findings report...", flush=True)
        report_path.write_text(report, encoding="utf-8", newline="\n")
    except OSError as error:
        print("FAILURE: Could not save the findings report ({}).".format(type(error).__name__))
        print("Completed-file checkpoints were kept at: {}".format(checkpoint_dir))
        return 1

    if checkpoint_dir is not None:
        shutil.rmtree(checkpoint_dir, ignore_errors=True)
    print("SUCCESS: Comprehensive offline native inspection completed.")
    print("ELF files inspected: {}".format(len(files)))
    print("Findings report saved locally: {}".format(report_path))
    print("The report includes relevant function disassembly and code-reference candidates.")
    print("No Kindle connection, network connection, upload or paste service was used.")
    print("Attach KPP-Native-Bridge-Findings.txt in ChatGPT.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
