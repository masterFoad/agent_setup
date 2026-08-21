# FOAD Dev Setup

Beginner-oriented Windows and macOS setup for a supervised FOAD workshop.

Version: **2.1.0**

Installs Git, Node.js/npm, Python/pip, Google Antigravity IDE, Claude Code, a starter Claude command/skill, and a terminal guide.

## Before interns start

Confirm that each intern has:

- 10-25 minutes, reliable internet, and several gigabytes of free disk space;
- permission to install software (individual package installers may request administrator approval);
- an eligible Claude subscription, Anthropic Console account, or supported provider;
- a Google account if the workshop requires Antigravity IDE sign-in.

The installers show this checklist and ask for confirmation before making changes. Existing starter files and the Desktop guide are preserved on reruns.

## Recommended distribution

For interns, use a **versioned, signed release** distributed by the instructor. Verify the published SHA-256 checksum before opening it.

- Windows releases should be Authenticode signed.
- macOS releases should be Developer ID signed and notarized.
- Do not tell interns to bypass SmartScreen or Gatekeeper for an artifact they have not independently verified.

The old `v1.0.0` DMG does not contain the current installer and should not be distributed.

Until signed `v2.1.0` binaries are published, use the pinned source scripts below only in a supervised setup session.

## Supervised source installation

These commands pin FOAD's installer to the versioned `v2.1.0` tag and download it before execution. Published tags must never be moved. The scripts still use official package managers and official vendor installers, so review release notes before each workshop.

### Windows

Open PowerShell:

```powershell
$path = Join-Path $env:TEMP "foad-install-windows.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/masterFoad/agent_setup/v2.1.0/install-windows.ps1" -OutFile $path
powershell -NoProfile -ExecutionPolicy Bypass -File $path
```

### macOS

Open Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/masterFoad/agent_setup/v2.1.0/install-mac.sh -o /tmp/foad-install-mac.sh
/bin/bash /tmp/foad-install-mac.sh
```

Never run these commands with `sudo`. Homebrew or individual package installers will request elevation only when needed.

Instructors can compare the downloaded scripts against [`SHA256SUMS`](SHA256SUMS) from the same tag before the session. Signed binary releases must publish checksums generated **after** signing/notarization.

## After installation

1. Close and reopen PowerShell or Terminal.
2. Run `claude` and follow the login instructions.
3. Open Google Antigravity IDE.
4. Read `FOAD-terminal-basics.txt` on the Desktop.

Verify with:

```text
git --version
node --version
npm --version
python --version     # Windows
python3 --version    # macOS
claude --version
```

If setup is incomplete, follow the final summary and rerun it. Existing workshop files are preserved, but the setup is not a general-purpose rollback or uninstaller for third-party packages.

## Troubleshooting

### Windows

- Send `FOAD-setup-log.txt` from the Desktop to the instructor.
- If `claude` is missing only inside Antigravity, choose a **PowerShell** terminal profile rather than WSL/Ubuntu.
- Large WinGet downloads can appear idle; check for a hidden UAC prompt in the taskbar.
- The WinGet registration/Store recovery path needs validation on a clean Windows VM before each workshop.

### macOS

- Copy the complete failing step and its preceding output for the instructor.
- Password prompts display no characters while typing.
- The full setup requires macOS 14 or newer to match Homebrew's supported baseline.

## Building release artifacts

See [`packaging/README.md`](packaging/README.md). Release builders require:

- a clean working tree;
- `HEAD` tagged exactly as `v$(cat VERSION)`;
- matching script/package versions.

Builders emit a `.sha256` file beside each artifact. `FOAD_ALLOW_UNTAGGED_BUILD=1` is available only for local test builds.

## Maintainer policy

- Never move a published version tag or replace an existing release asset.
- Record the source commit and checksums in release notes.
- Test Windows with a standard user plus separate administrator credentials.
- Test macOS on both Apple Silicon and Intel where supported.
- Run the validation workflow and verify failure/recovery paths before distribution.

Current upstream references: [Claude Code setup](https://code.claude.com/docs/en/setup), [Claude Code authentication](https://code.claude.com/docs/en/authentication), [Homebrew installation](https://docs.brew.sh/Installation), [Homebrew support tiers](https://docs.brew.sh/Support-Tiers), [Microsoft WinGet](https://learn.microsoft.com/windows/package-manager/winget/), and [GitHub immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases).
