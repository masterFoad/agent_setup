# FOAD Dev Setup

Beginner-oriented Windows and macOS setup for a supervised FOAD workshop.

Version: **2.1.3**

Installs Git, Node.js/npm, Python/pip, Google Antigravity IDE, Claude Code, a starter Claude command/skill, and a terminal guide.

---

## Contents

- [Before interns start](#before-interns-start)
- [Recommended distribution](#recommended-distribution)
- [Supervised source installation](#supervised-source-installation)
- [macOS — step by step](#macos--step-by-step)
- [Windows — step by step](#windows--step-by-step)
- [After installation](#after-installation)
- [Troubleshooting](#troubleshooting)
- [Building release artifacts](#building-release-artifacts)
- [Maintainer policy](#maintainer-policy)
- [Reference links](#reference-links)

---

## Before interns start

Confirm that each intern has:

- 10-25 minutes, reliable internet, and several gigabytes of free disk space;
- permission to install software (individual package installers may request administrator approval);
- an eligible Claude subscription, Anthropic Console account, or supported provider — see [Claude Code authentication](https://code.claude.com/docs/en/authentication) and [claude.ai plans](https://claude.ai/upgrade);
- a Google account if the workshop requires [Antigravity IDE](https://antigravity.google/) sign-in.

The installers show this checklist and ask for confirmation before making changes. Existing starter files and the Desktop guide are preserved on reruns.

## Recommended distribution

For interns, use a **versioned, signed release** distributed by the instructor. Verify the published SHA-256 checksum before opening it.

- Windows releases should be [Authenticode signed](https://learn.microsoft.com/windows/win32/seccrypto/cryptography-tools).
- macOS releases should be [Developer ID signed and notarized](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
- Do not tell interns to bypass [SmartScreen](https://learn.microsoft.com/windows/security/operating-system-security/virus-and-threat-protection/microsoft-defender-smartscreen/) or [Gatekeeper](https://support.apple.com/en-us/102445) for an artifact they have not independently verified.

The old `v1.0.0` DMG does not contain the current installer and should not be distributed.

Until signed `v2.1.3` binaries are published, use the pinned source scripts below only in a supervised setup session.

## Supervised source installation

These commands pin FOAD's installer to the versioned [`v2.1.3`](https://github.com/masterFoad/agent_setup/releases/tag/v2.1.3) tag and download it before execution. Published tags must never be moved. The scripts still use official package managers and official vendor installers, so review release notes before each workshop.

### Windows

Open PowerShell:

```powershell
$path = Join-Path $env:TEMP "foad-install-windows.ps1"
Invoke-WebRequest "https://raw.githubusercontent.com/masterFoad/agent_setup/v2.1.3/install-windows.ps1" -OutFile $path
powershell -NoProfile -ExecutionPolicy Bypass -File $path
```

The installer now verifies Claude using only the PATH that a genuinely new PowerShell will receive. If an older FOAD setup left `claude.exe` installed but unreachable, rerunning this version repairs the user PATH.

**WSL is not required for this workshop.** If Antigravity offers to install or open WSL, choose **Skip**, **Cancel**, or **Not now**. In Antigravity's terminal menu choose **Select Default Profile → PowerShell**, close the existing terminal, and open a new one.

### macOS

Open Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/masterFoad/agent_setup/v2.1.3/install-mac.sh -o /tmp/foad-install-mac.sh
/bin/bash /tmp/foad-install-mac.sh
```

Never run these commands with `sudo`. Homebrew or individual package installers will request elevation only when needed. Do **not** pipe the macOS script straight into `bash` — the installer refuses that path because Homebrew needs an interactive terminal.

Instructors can compare the downloaded scripts against [`SHA256SUMS`](SHA256SUMS) from the same tag before the session:

```bash
# macOS
shasum -a 256 /tmp/foad-install-mac.sh
```

```powershell
# Windows
Get-FileHash $env:TEMP\foad-install-windows.ps1 -Algorithm SHA256
```

Signed binary releases must publish checksums generated **after** signing/notarization.

---

## macOS — step by step

**Requirements:** macOS 14 (Sonoma) or newer — this matches [Homebrew's support tiers](https://docs.brew.sh/Support-Tiers). Apple Silicon or Intel. Apple's built-in **Terminal** app (Applications → Utilities → Terminal).

Run the [macOS command](#macos) above. The installer then performs these steps in order:

| # | Step | What happens | Reference |
|---|------|--------------|-----------|
| 1 | Consent prompt | Lists time, disk, admin, account and file-change expectations. Press Enter to continue or `q` to cancel. | — |
| 2 | Check your Mac and internet | Verifies macOS (Darwin), refuses to run as `sudo`/root, requires macOS ≥ 14, and confirms GitHub is reachable. | [Homebrew Support Tiers](https://docs.brew.sh/Support-Tiers) |
| 3 | Check Homebrew | Uses an existing `brew`, otherwise runs the official Homebrew installer. First install may ask for your Mac password and install the Xcode Command Line Tools. | [Homebrew Installation](https://docs.brew.sh/Installation) |
| 4 | Save PATH | Appends Homebrew and tool paths (`~/.local/bin`, `~/.claude/bin`, `~/.claude/local`) to `~/.zprofile` / `~/.bash_profile`. | [Homebrew shellenv](https://docs.brew.sh/Installation#post-installation-steps) |
| 5 | Update Homebrew | `brew update`. A failure here is a warning, not a stop. | — |
| 6 | Install Git | `brew install git` | [git-scm.com](https://git-scm.com/) |
| 7 | Install Node.js + npm | `brew install node` | [nodejs.org](https://nodejs.org/) · [npm docs](https://docs.npmjs.com/) |
| 8 | Install Python 3 + pip | `brew install python` | [python.org](https://www.python.org/) |
| 9 | Install Antigravity IDE | `brew install --cask antigravity-ide`. If the cask is unavailable, the [download page](https://antigravity.google/download) opens in your browser. | [Antigravity](https://antigravity.google/) |
| 10 | Install Claude Code | Tries in order: native installer (`curl -fsSL https://claude.ai/install.sh`), then `brew install --cask claude-code`, then `npm install -g @anthropic-ai/claude-code`. | [Claude Code setup](https://code.claude.com/docs/en/setup) |
| 11 | Create starter files | Writes a starter skill to `~/.claude/skills/summarize-changes/` and a starter command to `~/.claude/commands/`. Existing files are kept. | [Skills](https://code.claude.com/docs/en/skills) · [Slash commands](https://code.claude.com/docs/en/slash-commands) |
| 12 | Create the Desktop guide | Writes `~/Desktop/FOAD-terminal-basics.txt` and opens it in TextEdit at the end. | — |
| 13 | Verify | Runs `--version` for `git`, `node`, `npm`, `python3`, `pip3`, `claude`, then prints a ✔/⚠/✘ summary and next steps. | — |

Manual equivalents, if an intern needs to install a single piece by hand:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"   # Homebrew
brew install git node python
brew install --cask antigravity-ide
curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh              # Claude Code
/bin/bash /tmp/claude-install.sh
```

---

## Windows — step by step

**Requirements:** Windows 10 build 17763 (1809) or newer — the minimum for [WinGet](https://learn.microsoft.com/windows/package-manager/winget/) — and **Windows PowerShell** (Start → type `PowerShell`). Do **not** use a WSL/Ubuntu terminal; WSL is not required at any point in this workshop.

Run the [Windows command](#windows) above. The installer then performs these steps in order:

| # | Step | What happens | Reference |
|---|------|--------------|-----------|
| 1 | Start the Desktop log | Transcripts the whole run to `Desktop\FOAD-setup-log.txt` (OneDrive-redirected Desktops supported). | — |
| 2 | Consent prompt | Lists time, disk, UAC, account and file-change expectations, including the WSL note. Press Enter to continue or `Q` to cancel. | — |
| 3 | Check your computer | Verifies the Windows build (≥ 17763) and internet connectivity. | — |
| 4 | Check WinGet | Uses WinGet if present; otherwise attempts registration/Microsoft Store recovery of **App Installer**, then `winget source update`. | [WinGet docs](https://learn.microsoft.com/windows/package-manager/winget/) · [App Installer](https://apps.microsoft.com/detail/9nblggh4nns1) |
| 5 | Install Git | `winget install --id Git.Git --source winget` | [git-scm.com](https://git-scm.com/download/win) |
| 6 | Install Node.js + npm | `winget install --id OpenJS.NodeJS.LTS --source winget` | [nodejs.org](https://nodejs.org/) |
| 7 | Install Antigravity IDE | `winget install --id Google.AntigravityIDE`. This is the **big** download and can look frozen — it is not. Fallback: the [download page](https://antigravity.google/download) opens in your browser. **Note:** `Google.Antigravity` (without `IDE`) is a different app — an agent orchestrator with no editor. Do not install it instead. | [Antigravity](https://antigravity.google/docs/ide/getting-started) |
| 8 | Install Python 3 + pip | First available of `Python.Python.3.14`, `3.13`, `3.12`. Fallback: the [Python for Windows](https://www.python.org/downloads/windows/) page opens — tick **"Add python.exe to PATH"**. | [python.org](https://www.python.org/downloads/windows/) |
| 9 | Install Claude Code | Repairs an existing install first (PATH only), then the native installer (`https://claude.ai/install.ps1`, run in a separate PowerShell process), then the `Anthropic.ClaudeCode` WinGet package. Each path must produce a **valid Anthropic Authenticode signature** and a `claude` that resolves on the persistent user PATH, or it is treated as failed. | [Claude Code setup](https://code.claude.com/docs/en/setup) |
| 10 | Create workshop files | Writes a starter skill to `%USERPROFILE%\.claude\skills\summarize-changes\` and a command to `%USERPROFILE%\.claude\commands\`, plus `Desktop\FOAD-terminal-basics-v2.1.3.txt` (opened in Notepad at the end). | [Skills](https://code.claude.com/docs/en/skills) · [Slash commands](https://code.claude.com/docs/en/slash-commands) |
| 11 | Final check | Re-resolves `git`, `node`, `npm`, `python`/`py`, `pip`, `claude` using **only the persisted machine + user PATH** — i.e. what a genuinely new PowerShell window will see — then prints a summary with a "how to fix" line per failed item. | [Claude Code PATH troubleshooting](https://code.claude.com/docs/en/troubleshoot-install#verify-your-path) |

Windows-specific notes:

- Click **Yes** on any "Do you want to allow this app to make changes?" (UAC) prompt. It sometimes hides behind other windows — check the taskbar.
- The final check deliberately ignores the current session's PATH, so a green summary means the tools really will work in a fresh window. Still open a **new** PowerShell afterwards.
- The `.claude` directories, the versioned Desktop guide, and the setup log are the only files this script creates.

---

## After installation

1. Close and reopen PowerShell or Terminal.
2. Run `claude` and follow the login instructions (or type `/login`). Claude Code requires a **paid** Claude plan (Pro or higher), an Anthropic Console account, or a supported provider — see [authentication](https://code.claude.com/docs/en/authentication).
3. Open Google Antigravity IDE (Start Menu on Windows, Applications on macOS) and sign in with a Google account. On Windows, open **Antigravity IDE**, not the separate app called just "Antigravity".
4. Read the FOAD terminal guide on the Desktop (`FOAD-terminal-basics-v<version>.txt` on Windows, `FOAD-terminal-basics.txt` on macOS).

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
- If `claude` is missing in a normal PowerShell, rerun the current setup; it repairs and verifies the persistent user PATH. If it still fails, send `FOAD-setup-log.txt` to the instructor.
- If `claude` is missing only inside Antigravity, cancel any WSL prompt, choose **Select Default Profile → PowerShell**, close the existing terminal, and create a new terminal. WSL is not required.
- Large WinGet downloads can appear idle; check for a hidden UAC prompt in the taskbar.
- If `winget` is not recognised, install **App Installer** from the [Microsoft Store](https://apps.microsoft.com/detail/9nblggh4nns1) and rerun.
- If `python` opens the Microsoft Store instead of running, reinstall Python with **"Add python.exe to PATH"** ticked, or use `py --version`.
- A "no valid Anthropic signature" warning means the Claude binary on disk is not the official signed one — do not work around it; rerun setup and report it.
- The WinGet registration/Store recovery path needs validation on a clean Windows VM before each workshop.

### macOS

- Copy the complete failing step and its preceding output for the instructor.
- Password prompts display no characters while typing.
- The full setup requires macOS 14 or newer to match [Homebrew's supported baseline](https://docs.brew.sh/Support-Tiers).
- `command not found: brew` in a fresh Terminal → close and reopen Terminal once; the installer writes `eval "$(brew shellenv)"` into `~/.zprofile`.
- Never rerun with `sudo`; the installer stops if it detects root.

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
- Run the [validation workflow](.github/workflows/validate.yml) — including [`tests/test_release_contract.py`](tests/test_release_contract.py) and the Windows PATH check in [`tests/test_windows_path.ps1`](tests/test_windows_path.ps1) — and verify failure/recovery paths before distribution.

## Reference links

| Topic | Link |
|-------|------|
| Claude Code setup | https://code.claude.com/docs/en/setup |
| Claude Code PATH troubleshooting | https://code.claude.com/docs/en/troubleshoot-install#verify-your-path |
| Claude Code authentication | https://code.claude.com/docs/en/authentication |
| Claude plans | https://claude.ai/upgrade |
| Antigravity IDE requirements | https://antigravity.google/docs/ide/getting-started |
| Antigravity IDE download | https://antigravity.google/download |
| Homebrew installation | https://docs.brew.sh/Installation |
| Homebrew support tiers | https://docs.brew.sh/Support-Tiers |
| Microsoft WinGet | https://learn.microsoft.com/windows/package-manager/winget/ |
| App Installer (WinGet) | https://apps.microsoft.com/detail/9nblggh4nns1 |
| Git for Windows | https://git-scm.com/download/win |
| Node.js | https://nodejs.org/ |
| Python for Windows | https://www.python.org/downloads/windows/ |
| GitHub immutable releases | https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases |
