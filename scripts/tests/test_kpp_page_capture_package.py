import gzip
import struct
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "kpm" / "package"
BINARY_GZ = PACKAGE / "files" / "kpp-page-capture.gz"
LAUNCHER = PACKAGE / "scriptlets" / "KPP-Page-Text-Capture.sh"
INSTALL = PACKAGE / "install.sh"
UNINSTALL = PACKAGE / "uninstall.sh"
VERSION_REPORT = PACKAGE / "scriptlets" / "RoyalRoadTools-Version-Info.sh"
SOURCE = ROOT / "scripts" / "native" / "kpp_page_capture.c"
BUILD = ROOT / "scripts" / "native" / "build_kpp_page_capture.sh"
README = PACKAGE / "README.md"


class KPPPageCapturePackageTests(unittest.TestCase):
    def test_helper_is_arm32_hard_float_and_uses_kindles_webkit_extension(self):
        data = gzip.decompress(BINARY_GZ.read_bytes())
        self.assertGreater(len(data), 1024)
        self.assertEqual(data[:4], b"\x7fELF")
        self.assertEqual(data[4], 1, "must be ELF32")
        self.assertEqual(data[5], 1, "must be little-endian")
        machine = struct.unpack_from("<H", data, 18)[0]
        flags = struct.unpack_from("<I", data, 36)[0]
        self.assertEqual(machine, 40, "must be ARM")
        self.assertTrue(flags & 0x400, "must use the ARM hard-float ABI")
        for item in (
            b"gtk_offscreen_window_new",
            b"webkit_web_view_load_uri",
            b"webkit_web_view_execute_script_return_str",
            b"/lib/ld-linux-armhf.so.3",
        ):
            self.assertIn(item, data)

    def test_launcher_is_read_only_and_restricts_the_host(self):
        text = LAUNCHER.read_text(encoding="utf-8")
        result = subprocess.run(["sh", "-n", str(LAUNCHER)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("lipc-get-prop com.lab126.kppbrowser getLastOpenPage", text)
        self.assertIn("https://www.royalroad.com/*", text)
        self.assertIn(".royalroadtools/kpp-page-capture", text)
        self.assertIn("umask 077", text)
        self.assertNotIn("lipc-set-prop", text)
        self.assertNotIn("invokeAction", text)
        self.assertNotIn("bookmarklet", text.lower())

    def test_native_source_uses_offscreen_webkit_and_does_not_attach_to_kpp(self):
        text = SOURCE.read_text(encoding="utf-8")
        self.assertIn("gtk_offscreen_window_new", text)
        self.assertIn("webkit_web_view_execute_script_return_str", text)
        self.assertIn("document.querySelector", text)
        self.assertIn("innerText", text)
        self.assertNotIn("ptrace", text)
        self.assertNotIn("/proc/", text)
        self.assertNotIn("lipc-set-prop", text)

    def test_install_and_uninstall_manage_only_private_helper_and_launcher(self):
        install = INSTALL.read_text(encoding="utf-8")
        uninstall = UNINSTALL.read_text(encoding="utf-8")
        self.assertIn("KPP-Page-Text-Capture.sh", install)
        self.assertIn("files/kpp-page-capture.gz", install)
        self.assertIn("gzip -dc", install)
        self.assertIn(".royalroadtools/kpp-page-capture", uninstall)
        self.assertIn("KPP-Page-Text-Capture.sh", uninstall)
        self.assertNotIn("RoyalRoad-Page-Capture-", uninstall)

    def test_version_report_and_documentation_disclose_experimental_component(self):
        version = VERSION_REPORT.read_text(encoding="utf-8")
        readme = README.read_text(encoding="utf-8")
        self.assertIn("KPP-Page-Text-Capture.sh", version)
        self.assertIn("kpp-page-capture", version)
        self.assertIn("does not automatically share KPP's cookies", readme)
        self.assertIn("not yet been runtime-tested", readme)
        self.assertIn("not a bookmarklet", readme.lower())

    def test_reproducible_build_script_syntax(self):
        result = subprocess.run(["sh", "-n", str(BUILD)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        self.assertIn("armv7-unknown-linux-gnueabihf", BUILD.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
