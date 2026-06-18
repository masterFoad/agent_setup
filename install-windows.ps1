<#
FOAD Dev Setup - Windows
Installs: Git, Node.js LTS/npm, Google Antigravity IDE, Claude Code, and beginner Claude Code skill files.
Run from PowerShell. Safe to re-run.
Website command:
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/masterFoad/agent_setup/main/install-windows.ps1 | iex"
#>

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Step([string]$Message) {
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Ok([string]$Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function FailMsg([string]$Message) { Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Write-TextFileIfMissing([string]$Path, [string]$Content) {
    if (Test-Path $Path) {
        Ok "Keeping existing file: $Path"
        return
    }
    Write-Utf8NoBom -Path $Path -Content $Content
}

function Refresh-PathForCurrentSession {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $extra = @(
        (Join-Path $HOME ".local\bin"),
        (Join-Path $HOME ".claude\bin"),
        (Join-Path $HOME ".claude\local"),
        (Join-Path $HOME "AppData\Roaming\npm"),
        (Join-Path $HOME "AppData\Local\Microsoft\WinGet\Packages"),
        (Join-Path $HOME "AppData\Local\Microsoft\WindowsApps")
    ) -join ";"
    $env:Path = "$machinePath;$userPath;$extra;$env:Path"
}

function Test-WingetPackageInstalled([string]$Id) {
    try {
        $output = winget list --id $Id --exact --accept-source-agreements 2>$null | Out-String
        return ($LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($Id))
    } catch {
        return $false
    }
}

function Install-WingetPackage([string]$Id, [string]$Name, [switch]$Required) {
    Step "Installing $Name"

    if (Test-WingetPackageInstalled $Id) {
        Ok "$Name is already installed."
        return $true
    }

    Write-Host "Downloading and installing $Name. This can take several minutes." -ForegroundColor Cyan
    Write-Host "A big app may sit with no percentage while it downloads - that is normal, please wait and do NOT close this window." -ForegroundColor Cyan
    Write-Host "If a 'Do you want to allow this app to make changes?' (UAC) prompt appears, click Yes. Check the taskbar if you do not see it." -ForegroundColor Yellow
    try {
        # --silent installs unattended (no clicking). winget still prints its own
        # download progress to this console. Removing --silent would show each
        # app's installer UI but require the student to click through it.
        winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Ok "$Name installed."
            return $true
        }
        throw "winget exit code $LASTEXITCODE"
    } catch {
        if ($Required) {
            throw "Failed to install $Name with winget id '$Id'. Details: $($_.Exception.Message)"
        }
        Warn "Could not install $Name with winget id '$Id'. Details: $($_.Exception.Message)"
        return $false
    }
}

function Install-FirstAvailableWingetPackage([string[]]$Ids, [string]$Name) {
    foreach ($id in $Ids) {
        if (Install-WingetPackage -Id $id -Name "$Name ($id)" ) {
            return $true
        }
    }
    Warn "$Name was not installed from winget. Opening the official download page as a fallback."
    Start-Process "https://antigravity.google/download" | Out-Null
    return $false
}

function Install-ClaudeCodeNative {
    Step "Installing Claude Code"
    # URL verified against https://code.claude.com/docs/en/setup (official native installer).
    # This does NOT require Administrator. Alternative official path that would be more
    # consistent with the rest of this script: winget install Anthropic.ClaudeCode
    # (WinGet installs do not auto-update; the native installer below does.)
    try {
        Invoke-RestMethod -Uri "https://claude.ai/install.ps1" -UseBasicParsing | Invoke-Expression
        Refresh-PathForCurrentSession
        Ok "Claude Code installer finished."
        return $true
    } catch {
        Warn "Claude Code native installer failed: $($_.Exception.Message)"
        Warn "Trying npm fallback: npm install -g @anthropic-ai/claude-code"
        try {
            npm install -g @anthropic-ai/claude-code
            Refresh-PathForCurrentSession
            Ok "Claude Code installed with npm fallback."
            return $true
        } catch {
            Warn "npm fallback also failed: $($_.Exception.Message)"
            Warn "After setup, install manually from: https://code.claude.com/docs/en/setup"
            return $false
        }
    }
}

function Write-ClaudeStarterFiles {
    Step "Creating Claude Code starter skill and command"

    $skillDir = Join-Path $HOME ".claude\skills\summarize-changes"
    New-Item -ItemType Directory -Force -Path $skillDir | Out-Null

    $skillContent = @'
---
name: summarize-changes
description: Review the current Git working tree and summarize changed files, risks, and suggested tests before committing.
---

# Summarize Changes

Use this skill when the user wants to review current uncommitted Git changes before committing or pushing.

## Instructions

1. Run `git status --short` to see changed files.
2. Run `git diff --stat` to summarize the size of the changes.
3. Run `git diff` to inspect the actual changes when useful.
4. Summarize the work in 2-3 short bullets.
5. List possible bugs, missing tests, risky changes, security concerns, unclear code, and breaking changes.
6. If there are no changes, say the working tree is clean.
'@
    Write-TextFileIfMissing -Path (Join-Path $skillDir "SKILL.md") -Content $skillContent

    $commandDir = Join-Path $HOME ".claude\commands"
    New-Item -ItemType Directory -Force -Path $commandDir | Out-Null

    $commandContent = @'
Review my current Git working tree before I commit.

Please run:
- git status --short
- git diff --stat
- git diff

Then summarize:
1. What changed in 2-3 bullets
2. Main correctness risks
3. Missing tests
4. Any security or breaking-change concerns
5. A short recommended commit message

If there are no changes, say the working tree is clean.
'@
    Write-TextFileIfMissing -Path (Join-Path $commandDir "summarize-changes.md") -Content $commandContent

    Ok "Claude starter files are ready."
}

function Write-TerminalGuide {
    Step "Creating beginner terminal guide"

    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop)) { $desktop = $HOME }
    $guidePath = Join-Path $desktop "FOAD-terminal-basics.txt"

@'
FOAD Terminal Basics - Windows

FIRST CHECKS
Run these after install:

git --version
node --version
npm --version
claude --version

If a command says "not recognized", close PowerShell, open it again, and retry.

BASIC COMMANDS
pwd                     Show current folder
dir                     List files
ls                      List files, PowerShell shortcut
cd folder-name          Move into a folder
cd ..                   Move back one folder
mkdir my-project        Create a folder
echo hello > file.txt   Create a file
clear                   Clear the screen

GIT BASICS
git clone REPO_URL      Download a project
git status              See changed files
git add .               Stage all changes
git commit -m "message" Save a commit

NODE BASICS
npm install             Install project packages
npm run dev             Start many web projects

CLAUDE CODE
claude                  Start Claude Code
/login                  Login or register when inside Claude Code
/help                   Show Claude Code help
/skills                 Show available skills, if supported
/summarize-changes      Run FOAD's starter review command

ANTIGRAVITY IDE
Open Google Antigravity IDE from the Start Menu.

FIRST TEST PROJECT
mkdir foad-test
cd foad-test
git init
echo hello > README.md
claude
'@ | Set-Content -Path $guidePath -Encoding UTF8

    Ok "Wrote guide to: $guidePath"
}

function Check-CommandVersion([string]$Command, [string]$VersionArg = "--version") {
    Refresh-PathForCurrentSession
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Warn "$Command is not available yet. Restart PowerShell and try: $Command $VersionArg"
        return $false
    }

    try {
        $result = & $cmd.Source $VersionArg 2>&1 | Select-Object -First 1
        if ($LASTEXITCODE -eq 0) {
            Ok "$Command works: $result"
            return $true
        }
        Warn "$Command exists but version check returned exit code $LASTEXITCODE`: $result"
        return $false
    } catch {
        Warn "$Command exists but version check failed. Restart PowerShell and try: $Command $VersionArg"
        return $false
    }
}

function Ensure-Winget {
    # Returns $true if winget is usable in THIS session. If winget is missing,
    # tries to install App Installer (Microsoft.DesktopAppInstaller) from the
    # official microsoft/winget-cli GitHub release, then falls back to the
    # Microsoft Store. UNTESTED on real Windows from this repo's CI — smoke-test
    # on a Windows box before relying on the auto-bootstrap path.
    Step "Checking WinGet"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Ok "WinGet found."
        return $true
    }

    Warn "WinGet is not installed. Trying to install 'App Installer' automatically..."
    Warn "If this fails, the Microsoft Store will open as a fallback."

    try {
        switch ($env:PROCESSOR_ARCHITECTURE) {
            "AMD64" { $depArch = "x64" }
            "ARM64" { $depArch = "arm64" }
            "x86"   { $depArch = "x86" }
            default { $depArch = "x64" }
        }

        $tmp = Join-Path $env:TEMP "foad-winget"
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null

        $release = Invoke-RestMethod -UseBasicParsing `
            -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" `
            -Headers @{ "User-Agent" = "foad-dev-setup" }

        $bundle = $release.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
        $deps   = $release.assets | Where-Object { $_.name -like "*Dependencies.zip" } | Select-Object -First 1
        if (-not $bundle) { throw "Could not find the App Installer .msixbundle in the latest release." }

        # Install dependencies (VCLibs + UI.Xaml) for this architecture first, if shipped.
        if ($deps) {
            $depsZip = Join-Path $tmp $deps.name
            Invoke-WebRequest -UseBasicParsing -Uri $deps.browser_download_url -OutFile $depsZip
            $depsDir = Join-Path $tmp "deps"
            Expand-Archive -Path $depsZip -DestinationPath $depsDir -Force
            $archDir = Join-Path $depsDir $depArch
            if (Test-Path $archDir) {
                Get-ChildItem -Path $archDir -Filter *.appx -ErrorAction SilentlyContinue | ForEach-Object {
                    try { Add-AppxPackage -Path $_.FullName -ErrorAction Stop }
                    catch { Warn "Dependency $($_.Name) may already be present: $($_.Exception.Message)" }
                }
            }
        }

        $bundlePath = Join-Path $tmp $bundle.name
        Invoke-WebRequest -UseBasicParsing -Uri $bundle.browser_download_url -OutFile $bundlePath
        Add-AppxPackage -Path $bundlePath -ErrorAction Stop

        Refresh-PathForCurrentSession
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Ok "WinGet installed automatically."
            return $true
        }

        # Installed, but the app-execution alias is not live in this session yet.
        Warn "App Installer was installed, but 'winget' is not active in this PowerShell session yet."
        Warn "Close PowerShell, open it again, and paste the setup command once more. It is safe to re-run."
        return $false
    } catch {
        Warn "Automatic WinGet install failed: $($_.Exception.Message)"
        FailMsg "Install 'App Installer' from the Microsoft Store (opening now), then run this script again."
        Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" | Out-Null
        return $false
    }
}

Step "FOAD Dev Setup for Windows"
Write-Host "This installs Git, Node.js/npm, Antigravity IDE, Claude Code, and FOAD starter Claude files."
Write-Host "Windows may pop up a 'Do you want to allow this app to make changes?' (UAC) dialog while" -ForegroundColor Yellow
Write-Host "installing Git and Node.js. Click YES each time." -ForegroundColor Yellow
Write-Host "If a tool fails with an 'access denied' / permission error, close PowerShell, reopen it with" -ForegroundColor Yellow
Write-Host "'Run as Administrator', and paste the command again. It is safe to re-run." -ForegroundColor Yellow

if (-not (Ensure-Winget)) { exit 1 }

try { winget source update | Out-Null } catch { Warn "winget source update failed, continuing anyway." }

Install-WingetPackage -Id "Git.Git" -Name "Git" -Required | Out-Null
Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS + npm" -Required | Out-Null
Refresh-PathForCurrentSession

Write-Host ""
Write-Host "NOTE: Google Antigravity IDE is a full IDE and by far the largest download here." -ForegroundColor Cyan
Write-Host "It can take 10+ minutes on a slow connection and may show NO progress while downloading." -ForegroundColor Cyan
Write-Host "This is expected. Only treat it as stuck if there is no disk/network activity for a long time." -ForegroundColor Cyan
Install-FirstAvailableWingetPackage -Ids @("Google.AntigravityIDE") -Name "Google Antigravity IDE" | Out-Null
Install-ClaudeCodeNative | Out-Null
Write-ClaudeStarterFiles
Write-TerminalGuide

Step "Verifying installs"
Check-CommandVersion "git" | Out-Null
Check-CommandVersion "node" | Out-Null
Check-CommandVersion "npm" | Out-Null
Check-CommandVersion "claude" | Out-Null

Step "Next steps"
Write-Host "1. Close and reopen PowerShell."
Write-Host "2. Run: claude"
Write-Host "3. Inside Claude Code, login/register if asked. You can also type: /login"
Write-Host "4. Open Google Antigravity IDE from the Start Menu."
Write-Host "5. Read the desktop file: FOAD-terminal-basics.txt"
Write-Host ""
Ok "FOAD setup finished. If one check warned, restart PowerShell and rerun this script. It is safe to re-run."
