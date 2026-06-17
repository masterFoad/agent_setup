# Professional Installers

The one-line scripts are still the simplest fallback. For a more professional classroom distribution, build platform installers from this folder.

## Windows: `.exe`

Recommended: build an Inno Setup bootstrapper.

From a Windows machine:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows\build-windows-exe.ps1
```

Output:

```text
dist\windows\FOAD-Dev-Setup-Windows.exe
```

The EXE embeds and runs `install-windows.ps1` as administrator. It is a bootstrapper, not a normal uninstallable app, because it installs third-party tools managed by WinGet/Anthropic/Google.

For production, sign the EXE with an Authenticode code-signing certificate. Unsigned EXEs may trigger Microsoft Defender SmartScreen warnings.

## macOS: `.dmg`

Recommended first version: build a DMG containing a double-clickable `FOAD Dev Setup.command` launcher.

Why DMG instead of a postinstall `.pkg`? The setup needs to install/configure Homebrew and user-level Claude files as the logged-in user. A `.pkg` postinstall runs as root and is more likely to break Homebrew/user PATH behavior.

From a Mac:

```bash
./packaging/macos/build-mac-dmg.sh
```

Output:

```text
dist/macos/FOAD-Dev-Setup-macOS.dmg
```

For production, sign and notarize the DMG with an Apple Developer ID. Unsigned DMGs or command files may trigger Gatekeeper warnings.

## Recommended release assets

Attach these to a GitHub Release:

```text
FOAD-Dev-Setup-Windows.exe
FOAD-Dev-Setup-macOS.dmg
```

Keep the raw script commands in the README as a fallback for advanced users or troubleshooting.
