import hashlib
import os
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / "kpm" / "package" / "scriptlets" / "KPP-JavaScript-Bundle-Export.sh"
MAGIC = bytes.fromhex("c61fbc03c103191f")


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

    def tearDown(self):
        self.temp.cleanup()

    def write_bundle(self, version=84, extra=b"sample bundle"):
        self.source.write_bytes(MAGIC + struct.pack("<I", version) + extra)

    def run_export(self):
        env = os.environ.copy()
        env["KPP_BUNDLE_EXPORT_TEST_ROOT"] = str(self.root)
        return subprocess.run(
            ["sh", str(SCRIPT)], env=env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
        )

    def test_verified_copy_and_repeat(self):
        self.write_bundle(84)
        original = self.source.read_bytes()
        result = self.run_export()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.destination.read_bytes(), original)
        self.assertEqual(self.source.read_bytes(), original)
        digest = hashlib.sha256(original).hexdigest()
        report = self.report.read_text(encoding="utf-8")
        self.assertIn("SHA256: " + digest, report)
        self.assertIn("Hermes bytecode version (header field): 84", report)
        self.assertIn("SHA256 VERIFIED", report)
        result = self.run_export()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("ALREADY CURRENT", self.report.read_text(encoding="utf-8"))

    def test_new_source_replaces_old_copy_only_after_verification(self):
        self.write_bundle(84)
        self.assertEqual(self.run_export().returncode, 0)
        self.write_bundle(85, b"newer app bundle")
        result = self.run_export()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.destination.read_bytes(), self.source.read_bytes())
        self.assertIn("Hermes bytecode version (header field): 85",
                      self.report.read_text(encoding="utf-8"))

    def test_wrong_magic_does_not_replace_existing_copy(self):
        self.write_bundle(84)
        self.assertEqual(self.run_export().returncode, 0)
        previous = self.destination.read_bytes()
        self.source.write_bytes(b"not-an-HBC-file" + b"x" * 20)
        result = self.run_export()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.destination.read_bytes(), previous)
        self.assertIn("EXPECTED HERMES MAGIC", self.report.read_text(encoding="utf-8"))

    def test_size_limit_rejects_without_copy(self):
        self.source.write_bytes(MAGIC + struct.pack("<I", 84))
        with self.source.open("r+b") as stream:
            stream.truncate(50 * 1024 * 1024 + 1)
        result = self.run_export()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.destination.exists())
        self.assertIn("50 MB safety limit", self.report.read_text(encoding="utf-8"))

    def test_script_has_no_network_or_device_action_commands(self):
        script = SCRIPT.read_text(encoding="utf-8").lower()
        for forbidden in ("curl ", "wget ", "lipc-set-prop", "lipc-send-event",
                          "invokeaction", "executejavascript", "innertext"):
            self.assertNotIn(forbidden, script)


if __name__ == "__main__":
    unittest.main()
