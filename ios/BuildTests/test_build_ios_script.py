"""Exercise iOS build routing and HKW launch ordering without Xcode."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "shared/build_support"))
from build_mock import MOCK


class IOSBuildScriptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="doom ios build ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        (self.root / "ios").mkdir()
        shutil.copy2(Path(__file__).resolve().parents[1] / "build.sh", self.root / "ios/build.sh")
        binary = self.root / "bin"
        binary.mkdir()
        for name in ("xcodegen", "xcodebuild", "xcrun"):
            tool = binary / name
            tool.write_text(MOCK)
            tool.chmod(0o755)
        self.log = self.root / "calls.jsonl"
        self.env = dict(os.environ, PATH=f"{binary}:{os.environ['PATH']}", CALL_LOG=str(self.log))
        self.env.pop("FAIL_COMMAND", None)

    def run_script(self, *args, **env):
        self.log.unlink(missing_ok=True)
        result = subprocess.run(["bash", str(self.root / "ios/build.sh"), *args], cwd="/",
                                env=dict(self.env, **env), capture_output=True, text=True)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, calls

    def test_platforms_configurations_and_no_clean(self):
        sentinel = self.root / ".build/keep"
        sentinel.parent.mkdir()
        sentinel.touch()
        for args, platform, config in [((), "simulator", "Debug"), (("--release",), "simulator", "Release"),
                                       (("--device",), "device", "Debug"), (("--device", "--release"), "device", "Release")]:
            with self.subTest(args=args):
                result, calls = self.run_script(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual([call[0] for call in calls], ["xcodegen", "xcodebuild"])
                build = calls[1]
                self.assertIn(f"OBJROOT={self.root}/.build/ios/{platform}/{config}/Intermediates", build)
                self.assertEqual("CODE_SIGNING_ALLOWED=NO" in build, platform == "simulator")
                self.assertTrue(sentinel.exists())

    def test_hkw_precedes_install_and_launch(self):
        result, calls = self.run_script("--simulator", "sim-id", "--run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[2], ["xcrun", "simctl", "bootstatus", "sim-id", "-b"])
        self.assertEqual(calls[3], ["xcrun", "simctl", "location", "sim-id", "set", "52.51889,13.36528"])
        self.assertEqual(calls[4][1:3], ["simctl", "install"])
        self.assertEqual(calls[5][-1], "com.panjas.dashboard-of-doom")

    def test_invalid_arguments_and_failed_build_do_not_launch(self):
        for args in [("--run",), ("--device", "--run"), ("--simulator",), ("--device", "--simulator", "id"), ("--clean",)]:
            result, calls = self.run_script(*args)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(calls, [])
        result, calls = self.run_script("--simulator", "id", "--run", FAIL_COMMAND="xcodebuild")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([call[0] for call in calls], ["xcodegen", "xcodebuild"])
