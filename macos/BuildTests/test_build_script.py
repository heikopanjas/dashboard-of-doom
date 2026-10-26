"""Exercise build.sh routing and failure handling without Xcode or uploads."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "build.sh"
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "shared/build_support"))
from build_mock import MOCK



class BuildScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="doom build test ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / "macos").mkdir()
        shutil.copy2(SCRIPT, self.root / "macos/build.sh")
        (self.root / "macos/exportOptions.plist").touch()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("xcodegen", "xcodebuild", "xcrun", "ditto", "plutil", "spctl"):
            tool = self.bin / name
            tool.write_text(MOCK)
            tool.chmod(0o755)
        self.log = self.root / "calls.jsonl"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        CALL_LOG=str(self.log))
        for key in ("FAIL_COMMAND", "NOTARY_STATUS", "NOTARIZE_PROFILE"):
            self.env.pop(key, None)

    def run_script(self, *args, **env):
        self.log.unlink(missing_ok=True)
        result = subprocess.run(["bash", str(self.root / "macos/build.sh"), *args],
                                cwd="/", env=dict(self.env, **env),
                                capture_output=True, text=True)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, calls

    def test_build_modes_and_paths(self):
        for args, config in [((), "Debug"), (("--release",), "Release"),
                             (("--clean", "--release"), "Release")]:
            with self.subTest(args=args):
                result, calls = self.run_script(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual([c[0] for c in calls], ["xcodegen", "xcodebuild"])
                build = calls[1]
                self.assertEqual(build[build.index("-configuration") + 1], config)
                self.assertEqual(build[-1], "build")
                self.assertIn(f"SYMROOT={self.root}/.build/Products", build)
                self.assertIn(f"OBJROOT={self.root}/.build/Intermediates", build)
                self.assertIn("-disableAutomaticPackageResolution", build)

    def test_clean_only_preserves_sources_and_lockfile(self):
        for name in (".build", "Build", "build"):
            path = self.root / name
            path.mkdir(exist_ok=True)
            (path / "artifact").touch()
        lock = self.root / "DashboardOfDoom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        lock.parent.mkdir(parents=True)
        lock.write_text("locked")
        source = self.root / "source.swift"
        source.write_text("source")
        result, calls = self.run_script("--clean")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])
        self.assertTrue(all(not (self.root / p).exists() for p in (".build", "Build", "build")))
        self.assertEqual(lock.read_text(), "locked")
        self.assertEqual(source.read_text(), "source")

    def test_help_and_invalid_arguments_have_no_side_effects(self):
        for args, code in [(("--help",), 0), (("--unknown",), 2),
                           (("--clean", "--unknown"), 2)]:
            result, calls = self.run_script(*args)
            self.assertEqual(result.returncode, code)
            self.assertEqual(calls, [])

    def test_notarization_orders_archive_export_submit_staple_and_zip(self):
        result, calls = self.run_script("--clean", "--release", "--notarize",
                                        NOTARIZE_PROFILE="custom profile")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([c[0] for c in calls],
                         ["xcodegen", "xcodebuild", "xcodebuild", "ditto",
                          "xcrun", "plutil", "xcrun", "xcrun", "spctl", "ditto"])
        self.assertEqual(calls[1][-1], "archive")
        self.assertIn("Release", calls[1])
        # Direct build-setting overrides flatten Xcode's archive layout and
        # cause archive finalization to fail with a missing BuildProductsPath.
        self.assertFalse(any(arg.startswith(("SYMROOT=", "OBJROOT="))
                             for arg in calls[1]))
        self.assertIn("-IDECustomBuildLocationType=Absolute", calls[1])
        self.assertIn(f"-IDECustomBuildProductsPath={self.root}/.build/Products", calls[1])
        self.assertIn(f"-IDECustomBuildIntermediatesPath={self.root}/.build/Intermediates", calls[1])
        self.assertEqual(calls[2][1], "-exportArchive")
        self.assertIn("custom profile", calls[4])
        self.assertIn("--wait", calls[4])
        self.assertEqual(calls[6][1:3], ["stapler", "staple"])
        self.assertEqual(calls[7][1:3], ["stapler", "validate"])
        self.assertEqual(calls[3], calls[-1])

    def test_rejected_notarization_does_not_staple(self):
        result, calls = self.run_script("--notarize", NOTARY_STATUS="Invalid")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(c[1:2] == ["stapler"] for c in calls))
        self.assertTrue((self.root / ".build/notarization-result.plist").exists())

    def test_failures_stop_the_pipeline(self):
        for command in ("xcodegen", "xcodebuild", "xcodebuild -exportArchive",
                        "xcrun notarytool submit", "xcrun stapler staple",
                        "xcrun stapler validate", "spctl"):
            with self.subTest(command=command):
                result, calls = self.run_script("--notarize", FAIL_COMMAND=command)
                self.assertNotEqual(result.returncode, 0)
                self.assertTrue(" ".join(calls[-1]).startswith(command))
                self.assertNotIn("Notarization complete", result.stdout)


if __name__ == "__main__":
    unittest.main()
