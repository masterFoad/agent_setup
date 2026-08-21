import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def read(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


class ReleaseContractTests(unittest.TestCase):
    def test_version_is_consistent(self):
        version = read("VERSION").strip()
        self.assertRegex(version, r"^\d+\.\d+\.\d+$")
        self.assertIn(f'SCRIPT_VERSION="{version}"', read("install-mac.sh"))
        self.assertIn(f'$script:InstallerVersion = "{version}"', read("install-windows.ps1"))
        self.assertIn(f"/v{version}/install-mac.sh", read("README.md"))
        self.assertIn(f"/v{version}/install-windows.ps1", read("README.md"))

    def test_default_docs_do_not_execute_mutable_source(self):
        docs = read("README.md")
        self.assertNotIn("/main/install-", docs)
        self.assertNotRegex(docs, re.compile(r"\|\s*(iex|bash|sh)\b", re.IGNORECASE))
        self.assertNotIn("releases/latest", docs)

    def test_docs_do_not_reassure_users_to_bypass_os_security(self):
        combined = "\n".join(
            read(path)
            for path in (
                "README.md",
                "packaging/README.md",
                "packaging/macos/READ-ME-FIRST.txt",
                "packaging/macos/make-background.py",
            )
        ).lower()
        for unsafe_phrase in ("it is safe", "does not mean anything is wrong", "100% safe"):
            self.assertNotIn(unsafe_phrase, combined)

    def test_windows_wrapper_is_least_privilege_and_propagates_failure(self):
        iss = read("packaging/windows/foad-dev-setup.iss")
        self.assertIn("PrivilegesRequired=lowest", iss)
        self.assertIn("ResultCode <> 0", iss)
        self.assertIn("-AssumeYes", iss)

    def test_windows_version_check_requires_success_and_version_output(self):
        windows = read("install-windows.ps1")
        self.assertIn("$code -eq 0 -and $result -match", windows)
        self.assertNotIn("$code -eq 0 -or $result -match", windows)

    def test_packaged_consent_contains_same_material_prerequisites(self):
        launcher = read("packaging/macos/FOAD-Dev-Setup.command.template")
        iss = read("packaging/windows/foad-dev-setup.iss")
        for text in (launcher, iss):
            self.assertIn("10-25 minutes", text)
            self.assertIn("several gigabytes", text)
            self.assertIn("eligible", text)
            self.assertIn("Google account", text)
            self.assertIn("Desktop", text)

    def test_mac_profile_writes_propagate_failures(self):
        mac = read("install-mac.sh")
        self.assertIn('append_once "$HOME/.zprofile" "$path_line" || return 1', mac)
        self.assertIn('ensure_tool_path || stop_setup', mac)

    def test_packaged_mac_launcher_always_pauses_and_returns_status(self):
        launcher = read("packaging/macos/FOAD-Dev-Setup.command.template")
        self.assertIn("|| status=$?", launcher)
        self.assertLess(launcher.index("read -r -p"), launcher.index('exit "$status"'))

    def test_reruns_preserve_existing_guides(self):
        mac = read("install-mac.sh")
        windows = read("install-windows.ps1")
        self.assertIn('if [[ -f "$guide" ]]', mac)
        self.assertIn("if (-not $isNew)", windows)


if __name__ == "__main__":
    unittest.main()
