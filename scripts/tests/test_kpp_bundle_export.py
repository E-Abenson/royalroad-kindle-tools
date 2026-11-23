import os
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "kpm" / "package" / "scriptlets" / "KPP-JavaScript-Bundle-Export.sh"


class BundleExportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / "app" / "KPPMainApp" / "js" / "KPPMainApp.js.hbc"
        self.documents = self.root / "documents"
        self.source.parent.mkdir(parents=True)
        self.documents.mkdir()
        self.destination = self.documents / "KPPMainApp.js.hbc"
        self.report = self.documents / "KPP-JavaScript-Bundle-Export.txt"
        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()
        self.fbink_log = self.root / "fbink-calls.txt"
        fake_fbink = self.bin_dir / "fbink"
        fake_fbink.write_text(
            "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$FBINK_TEST_LOG\"\n",
            encoding="utf-8",
        )
        fake_fbink.chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def write_bundle(self, contents=b"a sample Hermes bundle, not parsed"):
        self.source.write_bytes(contents)

    def run_export(self):
        env = os.environ.copy()
        env["KPP_BUNDLE_EXPORT_TEST_ROOT"] = str(self.root)
        env["FBINK_TEST_LOG"] = str(self.fbink_log)
        env["PATH"] = str(self.bin_dir) + os.pathsep + env.get("PATH", "")
        return subprocess.run(
            ["sh", str(SCRIPT)], env=env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
        )

    def test_single_copy_saves_source_unchanged_and_simple_report(self):
        payload = bytes(range(256)) * 4096
        self.write_bundle(payload)
        result = self.run_export()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.destination.read_bytes(), payload)
        self.assertEqual(self.source.read_bytes(), payload)
        report = self.report.read_text(encoding="utf-8")
        self.assertIn("SUCCESS — COPIED", report)
        self.assertIn("copied once", report)
        self.assertNotIn("SHA256", report)
        self.assertNotIn("Hermes bytecode version", report)

    def test_repeat_run_copies_new_source_without_hashing(self):
        self.write_bundle(b"first bundle")
        self.assertEqual(self.run_export().returncode, 0)
        self.write_bundle(b"replacement bundle")
        result = self.run_export()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.destination.read_bytes(), b"replacement bundle")

    def test_non_hbc_file_is_copied_without_on_device_parsing(self):
        payload = b"not a validated HBC file; analysis happens on the computer"
        self.write_bundle(payload)
        result = self.run_export()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.destination.read_bytes(), payload)

    def test_large_centered_progress_messages_are_sent_to_fbink(self):
        self.write_bundle()
        result = self.run_export()
        self.assertEqual(result.returncode, 0, result.stdout)
        calls = self.fbink_log.read_text(encoding="utf-8")
        self.assertIn("-S 3 -m -M", calls)
        self.assertIn("STEP 1 OF 3", calls)
        self.assertIn("STEP 2 OF 3", calls)
        self.assertIn("COMPLETE", calls)

    def test_missing_source_keeps_previous_documents_copy(self):
        self.destination.write_bytes(b"previous good copy")
        result = self.run_export()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.destination.read_bytes(), b"previous good copy")
        self.assertIn("FAILED", self.report.read_text(encoding="utf-8"))

    def test_script_has_no_extra_processing_or_network_commands(self):
        script = SCRIPT.read_text(encoding="utf-8").lower()
        for forbidden in ("sha256sum", "\nsync", "curl ", "wget ", "hermes parser"):
            self.assertNotIn(forbidden, script)
        self.assertIn('cp "$source" "$tmp_dest"', script)


if __name__ == "__main__":
    unittest.main(verbosity=2)
