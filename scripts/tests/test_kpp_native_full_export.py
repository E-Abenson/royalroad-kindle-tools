import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[2]
    / "kpm"
    / "package"
    / "scriptlets"
    / "KPP-Native-Bridge-Export.sh"
)


class NativeFullExportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.documents = self.root / "documents"
        self.proc = self.root / "proc"
        self.fs = self.root / "rootfs"
        self.pid = "314"
        self.pid_dir = self.proc / self.pid
        self.app_dir = self.fs / "app" / "bin"
        self.lib_dir = self.fs / "usr" / "lib"
        self.extra_lib_dir = self.fs / "lib"
        for directory in (self.documents, self.pid_dir, self.app_dir, self.lib_dir, self.extra_lib_dir):
            directory.mkdir(parents=True, exist_ok=True)

        self.main_exe = self.app_dir / "KPPMainAppV2"
        self.mapped_library = self.lib_dir / "libmapped-readonly.so"
        self.unmapped_library = self.extra_lib_dir / "libfound-by-root-scan.so.1"
        self.browser_db = self.fs / "var" / "local" / "KPPBrowser.db"
        self.browser_db.parent.mkdir(parents=True, exist_ok=True)

        self._elf(self.main_exe, b"KPP MAIN EXECUTABLE")
        self._elf(self.mapped_library, b"READ ONLY MAPPED SHARED LIBRARY")
        self._elf(self.unmapped_library, b"UNMAPPED LIBRARY FOUND BY ROOT SCAN")
        self.browser_db.write_bytes(b"SQLite format 3\0must not be exported")

        (self.pid_dir / "comm").write_text("KPPMainAppV2\n", encoding="utf-8")
        (self.pid_dir / "exe").symlink_to(self.main_exe)
        (self.pid_dir / "maps").write_text(
            f"00400000-00450000 r-xp 00000000 08:01 1 {self.main_exe}\n"
            f"00600000-00610000 r--p 00000000 08:01 2 {self.mapped_library}\n"
            f"00700000-00710000 rw-p 00000000 08:01 3 {self.browser_db}\n",
            encoding="utf-8",
        )

    def tearDown(self):
        self.temp.cleanup()

    @staticmethod
    def _elf(path: Path, payload: bytes) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\x7fELF" + payload)

    def _run_worker(self):
        env = os.environ.copy()
        env["KPP_NATIVE_TEST_ROOT"] = str(self.root)
        env["KPP_NATIVE_TEST_SETTLE_SECONDS"] = "0"
        return subprocess.run(
            ["sh", str(SCRIPT), "--worker"],
            env=env,
            text=True,
            capture_output=True,
            check=False,
            timeout=30,
        )

    def test_collects_main_mapped_readonly_and_unmapped_shared_libraries(self):
        result = self._run_worker()
        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
        exports = list(self.documents.glob("KPP-Native-Bridge-FULL-*"))
        self.assertEqual(len(exports), 1)
        export = exports[0]

        main_copy = export / "files" / str(self.main_exe).lstrip("/")
        mapped_copy = export / "files" / str(self.mapped_library).lstrip("/")
        root_scan_copy = export / "files" / str(self.unmapped_library).lstrip("/")
        self.assertEqual(main_copy.read_bytes(), self.main_exe.read_bytes())
        self.assertEqual(mapped_copy.read_bytes(), self.mapped_library.read_bytes())
        self.assertEqual(root_scan_copy.read_bytes(), self.unmapped_library.read_bytes())

        manifest = (export / "manifest.tsv").read_text(encoding="utf-8")
        self.assertIn("main-executable", manifest)
        self.assertIn("process-map", manifest)
        self.assertIn("library-search", manifest)
        self.assertTrue((export / "metadata" / "process-maps.txt").is_file())

    def test_skips_browser_database_and_records_why(self):
        result = self._run_worker()
        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
        export = next(self.documents.glob("KPP-Native-Bridge-FULL-*"))
        copied_paths = [p for p in (export / "files").rglob("*") if p.is_file()]
        self.assertFalse(any(p.name == "KPPBrowser.db" for p in copied_paths))
        skipped = (export / "skipped.tsv").read_text(encoding="utf-8")
        self.assertIn(str(self.browser_db), skipped)
        self.assertIn("not-elf", skipped)

    def test_reports_off_device_analysis_and_does_not_make_archive(self):
        result = self._run_worker()
        self.assertEqual(result.returncode, 0, msg=result.stdout + result.stderr)
        report = (self.documents / "KPP-Native-Bridge-Full-Export.txt").read_text(encoding="utf-8")
        self.assertIn("Result: SUCCESS", report)
        self.assertIn("no parsing, hashing, disassembly, compression, or sync", report)
        self.assertFalse(any(self.documents.glob("*.tar.gz")))
        self.assertFalse(any(self.documents.glob("*.zip")))

    def test_shell_syntax_and_no_on_device_binary_analysis_commands(self):
        syntax = subprocess.run(["sh", "-n", str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(syntax.returncode, 0, msg=syntax.stderr)
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertIn("# Build: 4.0", source)
        self.assertNotRegex(source, r"(?m)^\s*(?:readelf|objdump|nm|sha256sum|tar|sync)\s")


if __name__ == "__main__":
    unittest.main()
