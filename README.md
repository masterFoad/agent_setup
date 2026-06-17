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

If it fails because of permissions, tell them to reopen PowerShell with **Run as Administrator** and paste it again.

### macOS

Tell students to open **Terminal** and paste:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/masterFoad/agent_setup/main/install-mac.sh)"
```

macOS may ask for the user password while installing Homebrew. That is normal.

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
