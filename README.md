# FOAD Dev Setup

Beginner-friendly setup scripts for Windows and macOS.

Installs:

- Git
- Node.js + npm
- Google Antigravity IDE
- Claude Code
- FOAD starter Claude Code skill/command
- A desktop terminal-basics guide

> Important: no script can create a Claude account for the user. After install, run `claude` and login/register when Claude Code asks.
>
> Security note: these one-liners download and execute installer scripts. Keep them on HTTPS, only use a domain you control, and show the script contents on the page for transparency.

## Download the macOS installer (.dmg)

Latest build, attached to the GitHub Release:

- **[FOAD-Dev-Setup-macOS.dmg](https://github.com/masterFoad/agent_setup/releases/latest/download/FOAD-Dev-Setup-macOS.dmg)**

Open the DMG, then double-click **FOAD Dev Setup**. It is **not** signed/notarized yet, so macOS will warn the first time — see [If you hand out the `.dmg` instead](#if-you-hand-out-the-dmg-instead) for the one-time right-click → Open step.

## Professional installer option

For a more professional download page, this repo also includes packaging templates:

- Windows: build `FOAD-Dev-Setup-Windows.exe` with Inno Setup.
- macOS: build `FOAD-Dev-Setup-macOS.dmg` with a double-click setup command.

See [`packaging/README.md`](packaging/README.md).

---

## Put this on your website

These commands use the raw files from this GitHub repo.

### Windows

Tell students to open **PowerShell** and paste:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/masterFoad/agent_setup/main/install-windows.ps1 | iex"
```

While it installs Git and Node.js, Windows may show a **User Account Control (UAC)** dialog asking *"Do you want to allow this app to make changes?"* — click **Yes**. If a tool fails with an "access denied" or permission error, tell students to reopen PowerShell with **Run as Administrator** and paste the command again. (The Claude Code install itself does not need Administrator.)

#### If you hand out the `.exe` instead

When students download `FOAD-Dev-Setup-Windows.exe` from a website, Microsoft Defender **SmartScreen** shows a blue *"Windows protected your PC"* box, because the EXE is not signed with a code-signing certificate. Tell students:

1. Click **More info**.
2. Click **Run anyway**.

This is expected for an unsigned installer and does not mean anything is wrong. To remove the warning entirely, sign the EXE with an Authenticode certificate (see [`packaging/README.md`](packaging/README.md)). For students, the one-line PowerShell command above does not trigger SmartScreen and is the recommended path.

### macOS

Tell students to open **Terminal** and paste:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/masterFoad/agent_setup/main/install-mac.sh)"
```

macOS may ask for the user password while installing Homebrew. That is normal.

#### If you hand out the `.dmg` instead

When students download `FOAD-Dev-Setup-macOS.dmg` from a website, macOS quarantines it. Unless the DMG is signed **and** notarized with an Apple Developer ID, double-clicking `FOAD Dev Setup.command` shows a warning like *"Apple could not verify this app is free of malware."* Tell students:

1. **Right-click** (or Control-click) `FOAD Dev Setup.command` → **Open** → **Open** again.
2. If macOS still refuses, go to  **Apple menu → System Settings → Privacy & Security**, scroll down, and click **Open Anyway**, then reopen the file.

This warning is expected for an unsigned installer and does not mean anything is wrong. To remove it entirely, sign and notarize the DMG (see [`packaging/README.md`](packaging/README.md)). For students, the one-line Terminal command above avoids Gatekeeper completely and is the recommended path.

---

## Local testing before uploading

From this folder:

### Windows PowerShell

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-windows.ps1
```

### macOS Terminal

```bash
chmod +x ./install-mac.sh
./install-mac.sh
```

---

## What users should do after install

1. Close and reopen PowerShell/Terminal.
2. Run:

   ```bash
   claude
   ```

3. Login/register when Claude Code asks. Inside Claude Code they can type:

   ```text
   /login
   ```

4. Open **Google Antigravity IDE**:
   - Windows: Start Menu
   - macOS: Applications
5. Read `FOAD-terminal-basics.txt` on the Desktop.

---

## Verification commands

Users can run:

```bash
git --version
node --version
npm --version
claude --version
```

If one command is missing, close and reopen the terminal, then rerun the setup command. The scripts are designed to be safe to rerun.

---

## Notes for FOAD

- Windows uses WinGet for Git, Node.js LTS, and Google Antigravity IDE.
- macOS uses Homebrew for Git, Node.js, and Google Antigravity IDE.
- The starter Claude files are only created if missing, so reruns do not overwrite student edits.
- Claude Code uses Anthropic's native installer first, then falls back to npm if needed.
- Antigravity IDE install can change if Google changes package IDs. The scripts open the official download page if package-manager install fails.
- Keep these scripts served over HTTPS only.
