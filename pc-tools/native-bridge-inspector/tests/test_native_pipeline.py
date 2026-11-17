from __future__ import annotations

import importlib.util
import os
import struct
import subprocess
import sys
import tarfile
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
INSPECTOR_DIR = ROOT / "pc-tools" / "native-bridge-inspector"
EXPORTER = ROOT / "kpm" / "package" / "scriptlets" / "KPP-Native-Bridge-Export.sh"

spec = importlib.util.spec_from_file_location(
    "kpp_native_inspect", INSPECTOR_DIR / "kpp_native_inspect.py"
)
inspector = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(inspector)


def align(value: int, boundary: int = 4) -> int:
    return (value + boundary - 1) & ~(boundary - 1)


def make_elf32_arm(
    symbol_name: str, *, defined: bool = True, thumb: bool = False,
    code_size: int | None = None,
) -> bytes:
    """Make a valid ELF32 ARM image with one named function and a marker string."""
    instruction_bytes = bytes.fromhex("7047") if thumb else bytes.fromhex("1eff2fe1")
    if code_size is None:
        code = instruction_bytes + b"\xff"  # trailing byte exercises safe skip-data handling
    else:
        code = instruction_bytes + bytes(max(0, code_size - len(instruction_bytes)))
    rodata = b"getLastOpenPage\x00"

    ident = b"\x7fELF" + bytes((1, 1, 1, 0)) + bytes(8)
    data = bytearray(ident + bytes(36))
    text_offset = len(data)
    data.extend(code)
    rodata_offset = align(len(data))
    data.extend(bytes(rodata_offset - len(data)))
    data.extend(rodata)

    strtab = b"\x00" + symbol_name.encode("ascii") + b"\x00"
    strtab_offset = align(len(data))
    data.extend(bytes(strtab_offset - len(data)))

    symtab_offset = align(len(data))
    data.extend(bytes(symtab_offset - len(data)))
    data.extend(bytes(16))  # STN_UNDEF
    data.extend(
        struct.pack(
            "<IIIBBH",
            1,
            (0x1001 if thumb else 0x1000) if defined else 0,
            len(instruction_bytes) if defined else 0,
            0x12,  # STB_GLOBAL | STT_FUNC
            0,
            1 if defined else 0,  # .text or SHN_UNDEF
        )
    )
    data.extend(strtab)

    shstrtab = b"\x00.text\x00.rodata\x00.symtab\x00.strtab\x00.shstrtab\x00"
    shstrtab_offset = len(data)
    data.extend(shstrtab)
    shoff = align(len(data))
    data.extend(bytes(shoff - len(data)))

    def name_offset(name: bytes) -> int:
        return shstrtab.index(name)

    sections = [
        (0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        (name_offset(b".text"), 1, 6, 0x1000, text_offset, len(code), 0, 0, 4 if not thumb else 2, 0),
        (name_offset(b".rodata"), 1, 2, 0x2000, rodata_offset, len(rodata), 0, 0, 1, 0),
        (name_offset(b".symtab"), 2, 0, 0, symtab_offset, 32, 4, 1, 4, 16),
        (name_offset(b".strtab"), 3, 0, 0, symtab_offset + 32, len(strtab), 0, 0, 1, 0),
        (name_offset(b".shstrtab"), 3, 0, 0, shstrtab_offset, len(shstrtab), 0, 0, 1, 0),
    ]

    for section in sections:
        data.extend(struct.pack("<IIIIIIIIII", *section))

    header = struct.pack(
        "<HHIIIIIHHHHHH",
        2,      # ET_EXEC
        40,     # EM_ARM
        1,
        0x1000,
        0,
        shoff,
        0,
        52,
        32,
        0,
        40,
        len(sections),
        5,
    )
    data[16:16 + len(header)] = header
    return bytes(data)


def tar_add_bytes(archive: tarfile.TarFile, name: str, data: bytes) -> None:
    info = tarfile.TarInfo(name)
    info.size = len(data)
    archive.addfile(info, __import__("io").BytesIO(data))


class NativeInspectorTests(unittest.TestCase):
    def test_capstone_507_is_accepted(self):
        fake = types.SimpleNamespace(__version__="5.0.7")
        with patch.dict(sys.modules, {"capstone": fake}):
            loaded = inspector.load_capstone(INSPECTOR_DIR)
        self.assertEqual("5.0.7", loaded.__version__)

    def test_multi_elf_arm_thumb_and_cross_library_linkage(self):
        imported = make_elf32_arm(
            "_ZN13KPPNavigation15getLastOpenPageEv",
            defined=False,
        )
        arm_library = make_elf32_arm(
            "_ZN13KPPNavigation15getLastOpenPageEv",
            defined=True,
            thumb=False,
        )
        thumb_library = make_elf32_arm(
            "_ZN13KPPBrowser16getAllSettingsEv",
            defined=True,
            thumb=True,
        )
        with tempfile.TemporaryDirectory() as temp:
            archive_path = Path(temp) / "KPP-Native-Bridge-Binaries.tar.gz"
            with tarfile.open(archive_path, "w:gz") as archive:
                tar_add_bytes(archive, "files/001_KPPMainAppV2.elf", imported)
                tar_add_bytes(archive, "files/002_libbrowser.so.elf", arm_library)
                tar_add_bytes(archive, "files/003_libengine.so.elf", thumb_library)

            files, manifest, _ = inspector.inspect_archive(archive_path)
            capstone = inspector.load_capstone(INSPECTOR_DIR)
            report = inspector.build_report(files, str(archive_path), manifest, capstone)

            self.assertEqual(3, len(files))
            self.assertIn("ELF32 little, ARM", report)
            self.assertIn("CROSS-LIBRARY BROWSER/BRIDGE IMPORT LINKS", report)
            self.assertIn("defined in 002_libbrowser.so.elf", report)
            self.assertIn("getLastOpenPage", report)
            self.assertIn("getAllSettings", report)
            self.assertIn("Thumb", report)
            self.assertIn("Skip-data pseudo-instructions safely skipped:", report)
            self.assertIn("Capstone 5.", report)

    def test_no_marker_strings_still_scans_arm_and_thumb_code(self):
        data = make_elf32_arm("_ZN13KPPNavigation15getLastOpenPageEv")
        layout = inspector.elf_layout(data)
        progress = []
        capstone = inspector.load_capstone(INSPECTOR_DIR)
        results = inspector.find_string_xrefs(
            data, layout, [], capstone, progress_callback=progress.append
        )
        self.assertEqual([], results[0])
        self.assertGreater(results[1], 0)
        self.assertEqual(len(data[layout["sections"][1]["offset"]:
                                  layout["sections"][1]["offset"] + layout["sections"][1]["size"]]) * 2,
                         results[2])
        self.assertIn("no marker strings", results[3].lower())
        self.assertTrue(any("ARM pass" in line for line in progress))
        self.assertTrue(any("Thumb pass" in line for line in progress))

    def test_capstone_memory_failure_retries_with_smaller_chunks(self):
        class FakeCsError(Exception):
            pass

        class LimitedEngine:
            def __init__(self):
                self.seen_sizes = []

            def __init__(self):
                self.seen_sizes = []
                self.successful_sizes = []

            def disasm(self, code, address):
                self.seen_sizes.append(len(code))
                if len(code) > 4096:
                    raise FakeCsError("Out of memory (CS_ERR_MEM)")
                self.successful_sizes.append(len(code))
                return list(range(len(code)))

        engine = LimitedEngine()
        decoded = inspector.decode_chunk_resilient(
            engine, b"X" * 16384, 0x1000, object(), alignment=4
        )
        self.assertEqual(16384, len(decoded))
        self.assertGreater(len(engine.seen_sizes), 1)
        self.assertLessEqual(max(engine.successful_sizes), 4096)

    def test_scan_checkpoint_resumes_inside_an_elf(self):
        data = make_elf32_arm(
            "_ZN13KPPNavigation15getLastOpenPageEv", code_size=300_000
        )
        layout = inspector.elf_layout(data)
        capstone = inspector.load_capstone(INSPECTOR_DIR)
        with tempfile.TemporaryDirectory() as temp:
            checkpoint = Path(temp) / "one-file.scan.json"
            original_decode = inspector.decode_chunk_resilient
            calls = {"count": 0}

            def interrupt_after_first_chunk(
                engine, code, address, backend, alignment=4, lite=False
            ):
                calls["count"] += 1
                if calls["count"] == 2:
                    raise KeyboardInterrupt()
                return original_decode(
                    engine, code, address, backend,
                    alignment=alignment, lite=lite,
                )

            with patch.object(
                inspector, "decode_chunk_resilient",
                side_effect=interrupt_after_first_chunk,
            ):
                with self.assertRaises(KeyboardInterrupt):
                    inspector.find_string_xrefs(
                        data, layout, [], capstone,
                        checkpoint_path=checkpoint,
                        archive_sha256="archive-test",
                        elf_sha256="elf-test",
                    )

            self.assertTrue(checkpoint.is_file())
            resumed = inspector.find_string_xrefs(
                data, layout, [], capstone,
                checkpoint_path=checkpoint,
                archive_sha256="archive-test",
                elf_sha256="elf-test",
            )
            expected_bytes = layout["sections"][1]["size"] * 2
            self.assertEqual(expected_bytes, resumed[2])
            self.assertGreater(resumed[1], 0)

    def test_build_report_resumes_completed_elf_checkpoints(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive_path = root / "KPP-Native-Bridge-Binaries.tar.gz"
            first = make_elf32_arm("_ZN13KPPNavigation15getLastOpenPageEv")
            second = make_elf32_arm("_ZN13KPPBrowser16getAllSettingsEv", thumb=True)
            with tarfile.open(archive_path, "w:gz") as archive:
                tar_add_bytes(archive, "files/001_KPPMainAppV2.elf", first)
                tar_add_bytes(archive, "files/002_libbrowser.so.elf", second)
            files, manifest, _ = inspector.inspect_archive(archive_path)
            capstone = inspector.load_capstone(INSPECTOR_DIR)
            checkpoint_dir = root / "inspection-checkpoint"
            archive_sha = inspector.sha256_file(archive_path)

            first_report = inspector.build_report(
                files, str(archive_path), manifest, capstone,
                checkpoint_dir=checkpoint_dir, archive_sha256=archive_sha,
                batch_size=1,
            )
            completed_file_caches = [
                path for path in checkpoint_dir.glob("*.json")
                if not path.name.endswith(".scan.json")
                and not path.name.endswith(".inventory.json")
            ]
            self.assertEqual(2, len(completed_file_caches))

            with patch.object(
                inspector, "find_string_xrefs",
                side_effect=AssertionError("completed work should be read from checkpoint"),
            ):
                resumed_report = inspector.build_report(
                    files, str(archive_path), manifest, capstone,
                    checkpoint_dir=checkpoint_dir, archive_sha256=archive_sha,
                    batch_size=1,
                )
            self.assertEqual(first_report, resumed_report)



    def test_targeted_code_scan_stops_at_its_budget_and_reuses_checkpoint(self):
        data = make_elf32_arm(
            "_ZN13KPPNavigation15getLastOpenPageEv", code_size=300_000
        )
        layout = inspector.elf_layout(data)
        capstone = inspector.load_capstone(INSPECTOR_DIR)
        with tempfile.TemporaryDirectory() as temp:
            checkpoint = Path(temp) / "bounded.scan.json"
            first = inspector.find_string_xrefs(
                data, layout, [], capstone,
                checkpoint_path=checkpoint,
                archive_sha256="archive-budget",
                elf_sha256="elf-budget",
                max_code_bytes=64 * 1024,
            )
            # The fixed budget applies separately to ARM and Thumb passes.
            self.assertEqual(128 * 1024, first[2])
            self.assertTrue(checkpoint.is_file())
            self.assertEqual(
                2 * 64 * 1024,
                first[2],
                "ARM and Thumb must each receive the requested per-mode budget",
            )
            resumed = inspector.find_string_xrefs(
                data, layout, [], capstone,
                checkpoint_path=checkpoint,
                archive_sha256="archive-budget",
                elf_sha256="elf-budget",
                max_code_bytes=64 * 1024,
            )
            self.assertEqual(first[2], resumed[2])
            self.assertEqual(first[1], resumed[1])
            self.assertIn("budget", resumed[3].lower())

    def test_0111_scan_checkpoint_is_compatible_with_new_inspector(self):
        with tempfile.TemporaryDirectory() as temp:
            checkpoint = Path(temp) / "previous.scan.json"
            state = {
                "work_index": 0,
                "chunk_offset": 0,
                "results": [],
                "seen": [],
                "instructions_scanned": 0,
                "code_bytes_scanned": 0,
                "skipped_data": 0,
                "recent": [],
                "pending": [],
            }
            payload = {
                "inspector_version": "0.1.111",
                "checkpoint_format": 2,
                "archive_sha256": "archive-old",
                "elf_sha256": "elf-old",
                "state": state,
            }
            checkpoint.write_text(__import__("json").dumps(payload), encoding="utf-8")
            loaded = inspector._load_scan_checkpoint(
                checkpoint, "archive-old", "elf-old"
            )
            self.assertIsNotNone(loaded)
            self.assertEqual(0, loaded["work_index"])



    def test_targeted_scan_eta_accounts_for_both_arm_and_thumb_budgets(self):
        item = {
            "layout": {
                "machine": 40,
                "sections": [
                    {"flags": 4, "type": 1, "size": 10 * 1024 * 1024},
                ],
            }
        }
        self.assertEqual(
            8 * 1024 * 1024,
            inspector.estimate_targeted_scan_budget([item]),
        )

    def test_v0110_completed_file_checkpoint_is_reused(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            checkpoint = root / "legacy.json"
            item = {"name": "libbrowser.so.elf", "sha256": "elf-sha"}
            result = {
                "symbols": [], "strings": [], "relocations": [],
                "functions": [], "function_count": 0,
                "function_instruction_count": 0, "xrefs": [],
                "instruction_count": 0, "code_bytes": 0,
                "scan_note": "legacy completed file",
                "skipped_data": 0,
            }
            payload = {
                "inspector_version": "0.1.110",
                "checkpoint_format": 1,
                "archive_sha256": "archive-sha",
                "elf_sha256": "elf-sha",
                "elf_name": "libbrowser.so.elf",
                "result": result,
            }
            checkpoint.write_text(
                __import__("json").dumps(payload), encoding="utf-8"
            )
            loaded = inspector.load_cached_file_result(
                checkpoint, "archive-sha", item
            )
            self.assertEqual(result, loaded)
            self.assertIsNone(
                inspector.load_cached_file_result(
                    checkpoint, "different-archive", item
                )
            )

    def test_build_report_selects_only_high_signal_candidates(self):
        main_app = make_elf32_arm("_ZN13KPPNavigation15getLastOpenPageEv")
        bridge = make_elf32_arm("_ZN13KPPBrowser16getAllSettingsEv", thumb=True)
        noise = make_elf32_arm("OrdinaryFunction").replace(
            b"getLastOpenPage", b"ordinaryMarker!"
        )
        self.assertEqual(len(b"getLastOpenPage"), len(b"ordinaryMarker!"))
        with tempfile.TemporaryDirectory() as temp:
            archive_path = Path(temp) / "KPP-Native-Bridge-Binaries.tar.gz"
            with tarfile.open(archive_path, "w:gz") as archive:
                tar_add_bytes(archive, "files/KPPMainAppV2.elf", main_app)
                tar_add_bytes(archive, "files/libbridge.so.elf", bridge)
                tar_add_bytes(archive, "files/libnoise-a.so.elf", noise)
                tar_add_bytes(archive, "files/libnoise-b.so.elf", noise)
            files, manifest, _ = inspector.inspect_archive(archive_path)
            capstone = inspector.load_capstone(INSPECTOR_DIR)
            with patch.object(
                inspector, "find_string_xrefs",
                wraps=inspector.find_string_xrefs,
            ) as scan:
                report = inspector.build_report(
                    files, str(archive_path), manifest, capstone,
                    archive_sha256=inspector.sha256_file(archive_path),
                )
            self.assertIn("ELF files inventoried: 4", report)
            self.assertIn("ELF files selected for focused analysis: 2", report)
            self.assertIn("libnoise-a.so.elf", report)
            self.assertIn("not selected for expensive code analysis", report)
            self.assertEqual(2, scan.call_count)
            for call in scan.call_args_list:
                self.assertEqual(
                    inspector.MAX_TARGETED_CODE_BYTES_PER_FILE,
                    call.kwargs["max_code_bytes"],
                )

    def test_exporter_captures_every_executable_mapped_elf_not_just_named_libraries(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            docs = root / "documents"
            proc = root / "proc" / "4242"
            app_root = root / "app"
            (proc / "map_files").mkdir(parents=True)
            (app_root / "bin").mkdir(parents=True)
            (app_root / "lib").mkdir(parents=True)
            (root / "usr" / "lib").mkdir(parents=True)

            main = app_root / "bin" / "KPPMainAppV2"
            webkit = app_root / "lib" / "libwebkit2gtk.so"
            generic = root / "usr" / "lib" / "libgraphics runtime.so.1"
            non_elf = app_root / "lib" / "not-a-library.so"
            main.write_bytes(make_elf32_arm("_ZN13KPPNavigation15getLastOpenPageEv"))
            webkit.write_bytes(make_elf32_arm("_ZN13KPPBrowser16getAllSettingsEv"))
            generic.write_bytes(make_elf32_arm("_ZN13KPPBrowser18genericBridgeCallEv"))
            non_elf.write_bytes(b"this is not an ELF file")
            (proc / "comm").write_text("KPPMainAppV2\n", encoding="ascii")
            (proc / "exe").symlink_to(main)

            mappings = [
                ("00400000-00401000", "08:01", "100", main),
                ("00500000-00501000", "08:01", "101", webkit),
                ("00600000-00601000", "08:01", "102", generic),
                ("00700000-00701000", "08:01", "103", non_elf),
                # A second mapping for the same main executable must be deduplicated.
                ("00800000-00801000", "08:01", "100", main),
            ]
            map_lines = []
            for address, device, inode, path in mappings:
                map_lines.append(
                    f"{address} r-xp 00000000 {device} {inode} {path}\n"
                )
                (proc / "map_files" / address).symlink_to(path)
            (proc / "maps").write_text("".join(map_lines), encoding="utf-8")

            environment = os.environ.copy()
            environment["KPP_EXPORT_TEST_ROOT"] = str(root)
            result = subprocess.run(
                ["sh", str(EXPORTER)],
                env=environment,
                capture_output=True,
                text=True,
                timeout=30,
                check=False,
            )
            self.assertEqual(0, result.returncode, msg=result.stdout + "\n" + result.stderr)
            self.assertIn("Files: 3", result.stdout)

            archive_path = docs / "KPP-Native-Bridge-Binaries.tar.gz"
            self.assertTrue(archive_path.is_file())
            with tarfile.open(archive_path, "r:gz") as archive:
                names = archive.getnames()
                native_members = [name for name in names if name.startswith("files/")]
                manifest = archive.extractfile("manifest.tsv").read().decode("utf-8")
                readme = archive.extractfile("README.txt").read().decode("utf-8")

            self.assertEqual(3, len(native_members))
            self.assertIn("KPPMainAppV2", manifest)
            self.assertIn("libwebkit2gtk.so", manifest)
            self.assertIn("libgraphics_runtime.so.1", manifest)
            self.assertNotIn("not-a-library", manifest)
            self.assertIn("Selection is NOT based on the", readme)
            self.assertIn("every readable ELF file", readme)
            self.assertNotIn(str(root), manifest + readme)
            self.assertNotIn("4242", manifest + readme)

            summary = (docs / "KPP-Native-Bridge-Export.txt").read_text(encoding="utf-8")
            self.assertIn("Files exported: 3", summary)
            self.assertIn("Non-ELF: 1", summary)
            self.assertNotIn(str(root), summary)
            self.assertNotIn("4242", summary)


if __name__ == "__main__":
    unittest.main(verbosity=2)
