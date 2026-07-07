<#
FOAD Dev Setup - Windows  (workshop edition, written for absolute beginners)
Installs: Git, Node.js LTS/npm, Google Antigravity IDE, Python 3, Claude Code, and beginner Claude Code skill files.
Run from PowerShell. Safe to re-run.
Website command:
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/masterFoad/agent_setup/main/install-windows.ps1 | iex"

Last verified against official sources: 2026-07-07
- Claude Code native installer:  https://code.claude.com/docs/en/setup  (irm https://claude.ai/install.ps1 | iex)
- Claude Code winget alternative: winget install Anthropic.ClaudeCode  (does NOT auto-update; native installer does)
- Antigravity: Google renamed things in mid-2026. "Google.Antigravity" is now a NEW agent-orchestrator
  app (Codex-like, not an IDE). The classic VS Code-style IDE is "Google.AntigravityIDE". We want the IDE.
- Python: 3.14 is the current stable line; winget IDs Python.Python.3.14 / .3.13 / .3.12 all exist.

Instructor notes:
- A full log of every run is saved to the student's Desktop as FOAD-setup-log.txt.
  If a student has a problem, ask them to send you that file.
- Set the environment variable FOAD_NO_PAUSE=1 to skip the "Press ENTER to close" prompt (for automation).
#>

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ---------------------------------------------------------------------------
# Output helpers, progress counter, run summary
# ---------------------------------------------------------------------------

$script:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:Summary = [ordered]@{}   # name -> @{ Status = "OK"|"WARN"|"FAIL"; Hint = "..." }
$script:PhaseNum = 0
$script:PhaseTotal = 8

function Phase([string]$Title, [string]$PlainExplanation) {
    $script:PhaseNum++
    $t = (Get-Date).ToString("HH:mm:ss")
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " STEP $($script:PhaseNum) of $($script:PhaseTotal)  [$t]  $Title" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    if ($PlainExplanation) { Write-Host " $PlainExplanation" -ForegroundColor Gray }
}

function Step([string]$Message) {
    $t = (Get-Date).ToString("HH:mm:ss")
    Write-Host ""
    Write-Host "--- [$t] $Message ---" -ForegroundColor Cyan
}

function Ok([string]$Message) { Write-Host "[OK] $Message" -ForegroundColor Green }
function Warn([string]$Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function FailMsg([string]$Message) { Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Record([string]$Name, [string]$Status, [string]$Hint = "") {
    # Never downgrade an OK if we record twice on a re-run path.
    if ($script:Summary.Contains($Name) -and $script:Summary[$Name].Status -eq "OK") { return }
    $script:Summary[$Name] = @{ Status = $Status; Hint = $Hint }
}

function Show-Summary {
    $elapsed = [math]::Round($script:Stopwatch.Elapsed.TotalMinutes, 1)
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host " SETUP SUMMARY  (took $elapsed minutes)" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    $anyBad = $false
    foreach ($key in $script:Summary.Keys) {
        $item = $script:Summary[$key]
        switch ($item.Status) {
            "OK"   { Write-Host ("  [ OK ]  " + $key) -ForegroundColor Green }
            "WARN" { Write-Host ("  [FIX ]  " + $key) -ForegroundColor Yellow; $anyBad = $true }
            default { Write-Host ("  [FAIL]  " + $key) -ForegroundColor Red; $anyBad = $true }
        }
        if ($item.Status -ne "OK" -and $item.Hint) {
            Write-Host ("          how to fix: " + $item.Hint) -ForegroundColor Gray
        }
    }
    Write-Host ""
    if ($anyBad) {
        Warn "Some items need a small fix (see 'how to fix' lines above)."
        Warn "The most common fix works for almost everything:"
        Write-Host ""
        Write-Host "    1. Close this PowerShell window." -ForegroundColor White
        Write-Host "    2. Open a NEW PowerShell window." -ForegroundColor White
        Write-Host "    3. Paste the same setup command from the website and press Enter." -ForegroundColor White
        Write-Host ""
        Warn "Re-running is 100% safe. Anything already installed is skipped automatically."
    } else {
        Ok "Everything installed and verified. You are ready for the workshop!"
    }
    Write-Host ""
    Write-Host "A full log of this setup was saved to your Desktop: FOAD-setup-log.txt" -ForegroundColor Gray
    Write-Host "If you get stuck, send that file to your instructor." -ForegroundColor Gray
}

# ---------------------------------------------------------------------------
# File + PATH helpers
# ---------------------------------------------------------------------------

function Get-DesktopPath {
    # Works with normal Desktops AND OneDrive-redirected Desktops.
    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop)) { $desktop = $HOME }
    return $desktop
}

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
    $extraDirs = @(
        (Join-Path $HOME ".local\bin"),
        (Join-Path $HOME ".claude\bin"),
        (Join-Path $HOME ".claude\local"),
        (Join-Path $HOME "AppData\Roaming\npm"),
        (Join-Path $HOME "AppData\Local\Microsoft\WinGet\Packages"),
        (Join-Path $HOME "AppData\Local\Microsoft\WindowsApps")
    )

    # winget's Python often does not add itself to PATH; find per-user installs
    # (e.g. ...\Programs\Python\Python314 and its Scripts dir) and include them.
    $pyRoot = Join-Path $HOME "AppData\Local\Programs\Python"
    if (Test-Path $pyRoot) {
        Get-ChildItem -Path $pyRoot -Directory -Filter "Python3*" -ErrorAction SilentlyContinue | ForEach-Object {
            $extraDirs += $_.FullName
            $extraDirs += (Join-Path $_.FullName "Scripts")
        }
    }

    $extra = ($extraDirs -join ";")
    $env:Path = "$machinePath;$userPath;$extra;$env:Path"
}

# ---------------------------------------------------------------------------
# Pre-flight checks (fail early with friendly messages, not cryptic errors)
# ---------------------------------------------------------------------------

function Test-WindowsVersionOk {
    # winget needs Windows 10 1809 (build 17763) or later.
    $build = [System.Environment]::OSVersion.Version.Build
    if ($build -lt 17763) {
        FailMsg "Your Windows version is too old for this setup (needs Windows 10 version 1809 or newer)."
        FailMsg "Please update Windows first (Settings > Windows Update), then run this again."
        return $false
    }
    return $true
}

function Test-InternetOk {
    # Quick TCP check to port 443. ICMP ping is often blocked on campus/office
    # Wi-Fi, so do a real HTTPS-port connection test instead. Non-fatal: if it
    # fails we warn but continue, in case only this one host is unreachable.
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $task = $client.ConnectAsync("github.com", 443)
        $connected = $task.Wait(5000) -and $client.Connected
        $client.Close()
        if ($connected) { return $true }
    } catch { }
    Warn "Could not reach the internet (github.com). Are you connected to Wi-Fi?"
    Warn "If you are on hotel/campus Wi-Fi, open a browser first and accept the network's login page."
    Warn "Continuing anyway, but downloads will likely fail until the connection works."
    return $false
}

# ---------------------------------------------------------------------------
# WinGet install helpers
# ---------------------------------------------------------------------------

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
        Ok "$Name is already installed. Skipping."
        return $true
    }

    Write-Host "Downloading and installing $Name. This can take several minutes." -ForegroundColor Cyan
    Write-Host "A big app may sit with NO progress while it downloads - that is normal. Please wait and do NOT close this window." -ForegroundColor Cyan
    Write-Host "If a 'Do you want to allow this app to make changes?' (UAC) box pops up, click YES. If you do not see it, check the taskbar - it may be hiding there." -ForegroundColor Yellow
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

function Install-FirstAvailableWingetPackage([string[]]$Ids, [string]$Name, [string]$FallbackUrl) {
    foreach ($id in $Ids) {
        if (Install-WingetPackage -Id $id -Name "$Name ($id)" ) {
            return $true
        }
    }
    if ($FallbackUrl) {
        Warn "$Name was not installed from winget. Opening the official download page as a fallback."
        Warn "Please download and run the installer from that page yourself."
        Start-Process $FallbackUrl | Out-Null
    } else {
        Warn "$Name was not installed from winget."
    }
    return $false
}

# ---------------------------------------------------------------------------
# Claude Code
# ---------------------------------------------------------------------------

function Install-ClaudeCodeNative {
    Step "Installing Claude Code"
    # URL verified against https://code.claude.com/docs/en/setup (official native installer).
    # This does NOT require Administrator. Alternative official path that would be more
    # consistent with the rest of this script: winget install Anthropic.ClaudeCode
    # (WinGet installs do not auto-update; the native installer below does.)
    #
    # KNOWN UPSTREAM QUIRK (anthropics/claude-code #26880): install.ps1 can print
    # "Installation complete!" even when the underlying install failed, because it
    # does not check the child process exit code. That is why this script does NOT
    # trust the installer's own success message - the real test is the
    # Check-CommandVersion "claude" step in the verification phase below.
    try {
        Invoke-RestMethod -Uri "https://claude.ai/install.ps1" -UseBasicParsing | Invoke-Expression
        Refresh-PathForCurrentSession
        Ok "Claude Code installer finished. (We double-check it for real in the final verification step.)"
        return $true
    } catch {
        Warn "Claude Code native installer failed: $($_.Exception.Message)"
        Warn "Trying plan B: npm install -g @anthropic-ai/claude-code"
        try {
            npm install -g @anthropic-ai/claude-code
            Refresh-PathForCurrentSession
            Ok "Claude Code installed with the npm fallback."
            return $true
        } catch {
            Warn "The npm fallback also failed: $($_.Exception.Message)"
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
    # Returns the guide path if the file was newly created, otherwise $null.
    Step "Creating beginner terminal guide"

    $guidePath = Join-Path (Get-DesktopPath) "FOAD-terminal-basics.txt"
    $isNew = -not (Test-Path $guidePath)

@'
FOAD Terminal Basics - Windows

FIRST CHECKS
Run these after install:

git --version
node --version
npm --version
python --version
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

PYTHON BASICS
python --version        Check Python is installed (or: py --version)
pip install requests    Install a Python package
python script.py        Run a Python script
If "python" opens the Microsoft Store, close PowerShell and reopen it, or use
the "py" command instead.

CLAUDE CODE
claude                  Start Claude Code
/login                  Login or register when inside Claude Code
/help                   Show Claude Code help
/doctor                 Check that Claude Code is installed and set up correctly
/skills                 Show available skills, if supported
/summarize-changes      Run FOAD's starter review command
NOTE: Claude Code needs a paid Claude plan (Pro or higher) or a Console/API
account. The free claude.ai plan does not include Claude Code.

ANTIGRAVITY IDE
Open "Antigravity IDE" from the Start Menu.

NAMING WARNING: Google renamed things in 2026. There are now TWO different
apps: "Antigravity" (an AI agent manager, NOT an editor) and "Antigravity IDE"
(the full code editor - the one we use in FOAD). If you see a chat-only agent
screen with no file editor, you opened the wrong one. Look for "Antigravity
IDE" in the Start Menu.

IMPORTANT - terminal inside Antigravity IDE:
Claude Code was installed for normal Windows, so it runs in PowerShell.
In Antigravity IDE, open a terminal and pick the "PowerShell" profile (NOT
"WSL" or "Ubuntu"). If the terminal opens WSL/Linux, "claude" will say
"command not found" and Windows may ask to install WSL - that is the wrong
shell.
To switch: click the small dropdown arrow next to the + in the terminal panel
and choose PowerShell (or Command Prompt / Git Bash). Then run:  claude

FIRST TEST PROJECT
mkdir foad-test
cd foad-test
git init
echo hello > README.md
claude
'@ | Set-Content -Path $guidePath -Encoding UTF8

    Ok "Wrote guide to: $guidePath"
    if ($isNew) { return $guidePath }
    return $null
}

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

function Check-CommandVersion([string]$Command, [string]$VersionArg = "--version") {
    Refresh-PathForCurrentSession
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Warn "$Command is not available yet. Restart PowerShell and try: $Command $VersionArg"
        return $false
    }

    try {
        # Capture ALL output first, then take the first line. Piping a native
        # command directly into 'Select-Object -First 1' stops it early, which
        # kills the process and makes $LASTEXITCODE come back as -1 on success
        # (it prints the right version but falsely warns). Capture, record the
        # exit code immediately, then trim.
        $output = & $cmd.Source $VersionArg 2>&1
        $code = $LASTEXITCODE
        $result = ($output | Select-Object -First 1)
        if ($code -eq 0 -or $result -match '\d+\.\d+') {
            Ok "$Command works: $result"
            return $true
        }
        Warn "$Command exists but version check returned exit code $code`: $result"
        return $false
    } catch {
        Warn "$Command exists but version check failed. Restart PowerShell and try: $Command $VersionArg"
        return $false
    }
}

function Check-PythonVersion {
    # winget Python installs sometimes only expose the "py" launcher until a
    # new shell picks up PATH changes. Accept either python or py.
    if (Check-CommandVersion "python") { return $true }
    Warn "Trying the 'py' launcher instead of 'python'..."
    if (Check-CommandVersion "py") {
        Ok "Python is available via 'py'. After restarting PowerShell, plain 'python' should work too."
        return $true
    }
    return $false
}

# ---------------------------------------------------------------------------
# WinGet bootstrap
# ---------------------------------------------------------------------------

function Ensure-Winget {
    # Returns $true if winget is usable in THIS session. If winget is missing,
    # tries to install App Installer (Microsoft.DesktopAppInstaller) from the
    # official microsoft/winget-cli GitHub release, then falls back to the
    # Microsoft Store. UNTESTED on real Windows from this repo's CI — smoke-test
    # on a Windows box before relying on the auto-bootstrap path.
    Step "Checking WinGet (the Windows app installer this script uses)"
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

        # Install dependencies (VCLibs, UI.Xaml, WindowsAppRuntime) for this
        # architecture first, if shipped. The dependencies zip can contain both
        # .appx and .msix files, so accept both extensions.
        if ($deps) {
            $depsZip = Join-Path $tmp $deps.name
            Invoke-WebRequest -UseBasicParsing -Uri $deps.browser_download_url -OutFile $depsZip
            $depsDir = Join-Path $tmp "deps"
            Expand-Archive -Path $depsZip -DestinationPath $depsDir -Force
            $archDir = Join-Path $depsDir $depArch
            if (Test-Path $archDir) {
                Get-ChildItem -Path $archDir -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension -in ".appx", ".msix" } |
                    ForEach-Object {
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

# ---------------------------------------------------------------------------
# End-of-run helpers
# ---------------------------------------------------------------------------

function Pause-BeforeClose {
    # If a student launched this by double-click / right-click "Run with
    # PowerShell", the window would vanish instantly at the end and they would
    # see nothing. Hold it open unless we're in automation.
    if ($env:FOAD_NO_PAUSE) { return }
    if ($Host.Name -ne "ConsoleHost") { return }
    Write-Host ""
    try { Read-Host "Press ENTER to close this window" | Out-Null } catch { }
}

function Finish([int]$ExitCode) {
    try { Stop-Transcript | Out-Null } catch { }
    Pause-BeforeClose
    exit $ExitCode
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Log everything to the Desktop so students can send the instructor one file.
$script:LogPath = Join-Path (Get-DesktopPath) "FOAD-setup-log.txt"
try { Start-Transcript -Path $script:LogPath -Append | Out-Null } catch { }

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "        FOAD DEV SETUP - Claude Code Workshop             " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will install everything you need:" -ForegroundColor White
Write-Host "  - Git              (saves versions of your code)"
Write-Host "  - Node.js + npm    (runs JavaScript projects)"
Write-Host "  - Antigravity IDE  (the code editor we use)"
Write-Host "  - Python 3 + pip   (runs Python scripts)"
Write-Host "  - Claude Code      (your AI coding assistant)"
Write-Host ""
Write-Host "You do NOT need to understand any of the text that scrolls by." -ForegroundColor Green
Write-Host "Just do these two things:" -ForegroundColor Green
Write-Host "  1. WAIT. This takes 5-20 minutes. Do NOT close this window, even if" -ForegroundColor White
Write-Host "     nothing seems to happen for a few minutes - big downloads are silent." -ForegroundColor White
Write-Host "  2. If Windows asks 'Do you want to allow this app to make changes?'," -ForegroundColor White
Write-Host "     click YES. (The box sometimes hides in the taskbar - check there.)" -ForegroundColor White
Write-Host ""
Write-Host "If anything goes wrong: close PowerShell, open it again, and paste the" -ForegroundColor Yellow
Write-Host "same command from the website. Re-running is always safe." -ForegroundColor Yellow

Phase "Checking your computer" "Making sure Windows and your internet connection are ready."
if (-not (Test-WindowsVersionOk)) { Record "Windows version" "FAIL" "Update Windows, then run this setup again."; Show-Summary; Finish 1 }
Ok "Windows version is fine."
Test-InternetOk | Out-Null

if (-not (Ensure-Winget)) {
    Record "WinGet" "FAIL" "Install 'App Installer' from the Microsoft Store, then run this setup again."
    Show-Summary
    Finish 1
}
Record "WinGet" "OK"

try { winget source update | Out-Null } catch { Warn "winget source update failed, continuing anyway." }

Phase "Installing Git" "Git tracks changes in your code, like unlimited undo with history."
$gitOk = Install-WingetPackage -Id "Git.Git" -Name "Git" -Required
Record "Git" $(if ($gitOk) { "OK" } else { "FAIL" }) "Reopen PowerShell as Administrator and run the setup command again."

Phase "Installing Node.js + npm" "Node.js runs JavaScript on your computer; npm installs JavaScript packages."
$nodeOk = Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS + npm" -Required
Record "Node.js + npm" $(if ($nodeOk) { "OK" } else { "FAIL" }) "Reopen PowerShell as Administrator and run the setup command again."
Refresh-PathForCurrentSession

Phase "Installing Antigravity IDE" "The code editor we use in the workshop. THIS IS THE BIG ONE - it may look frozen while downloading. It is not. Please wait."
# Google.AntigravityIDE = the full IDE (what we want).
# Google.Antigravity    = a DIFFERENT app since 2026 (agent orchestrator, no editor). Do NOT add it here.
$agOk = Install-FirstAvailableWingetPackage -Ids @("Google.AntigravityIDE") -Name "Google Antigravity IDE" -FallbackUrl "https://antigravity.google/download"
Record "Antigravity IDE" $(if ($agOk) { "OK" } else { "WARN" }) "The download page opened in your browser - scroll to 'Antigravity IDE', download it, and run the installer."

Phase "Installing Python 3 + pip" "Python runs many scripts and tools that Claude Code will write for you."
# Pin to current minor versions, NEWEST FIRST (3.14 is the current stable line);
# winget IDs are version-specific.
$pyOk = Install-FirstAvailableWingetPackage -Ids @("Python.Python.3.14", "Python.Python.3.13", "Python.Python.3.12") -Name "Python 3 + pip" -FallbackUrl "https://www.python.org/downloads/windows/"
Record "Python 3 + pip" $(if ($pyOk) { "OK" } else { "WARN" }) "The Python download page opened - download the latest Windows installer and run it (tick 'Add python.exe to PATH')."
Refresh-PathForCurrentSession

Phase "Installing Claude Code" "The AI coding assistant - the star of this workshop."
$ccOk = Install-ClaudeCodeNative
Record "Claude Code" $(if ($ccOk) { "OK" } else { "WARN" }) "Close PowerShell, reopen it, run the setup command again. Manual install: https://code.claude.com/docs/en/setup"

Phase "Creating workshop files" "A starter Claude skill, a starter command, and a cheat-sheet on your Desktop."
Write-ClaudeStarterFiles
Record "Claude starter files" "OK"
$newGuidePath = Write-TerminalGuide
Record "Desktop cheat-sheet" "OK"

Phase "Final check" "Testing that every tool actually answers when called."
Record "git works"    $(if (Check-CommandVersion "git")    { "OK" } else { "WARN" }) "Close PowerShell, open a new one, type: git --version"
Record "node works"   $(if (Check-CommandVersion "node")   { "OK" } else { "WARN" }) "Close PowerShell, open a new one, type: node --version"
Record "npm works"    $(if (Check-CommandVersion "npm")    { "OK" } else { "WARN" }) "Close PowerShell, open a new one, type: npm --version"
Record "python works" $(if (Check-PythonVersion)           { "OK" } else { "WARN" }) "Close PowerShell, open a new one, type: python --version (or: py --version)"
Record "pip works"    $(if (Check-CommandVersion "pip")    { "OK" } else { "WARN" }) "Close PowerShell, open a new one, type: pip --version"
Record "claude works" $(if (Check-CommandVersion "claude") { "OK" } else { "WARN" }) "Close PowerShell, open a new one, type: claude --version. If still missing, run the setup command again."

Show-Summary

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " WHAT TO DO NEXT" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "1. Close this PowerShell window and open a NEW one." -ForegroundColor White
Write-Host "2. Type:  claude   and press Enter." -ForegroundColor White
Write-Host "3. Log in when asked (or type /login)." -ForegroundColor White
Write-Host "   IMPORTANT: Claude Code needs a Claude account with a PAID plan" -ForegroundColor Yellow
Write-Host "   (Pro or higher) - the free plan does not include it. Create or" -ForegroundColor Yellow
Write-Host "   upgrade your account at https://claude.ai BEFORE the workshop." -ForegroundColor Yellow
Write-Host "4. Open 'Antigravity IDE' from the Start Menu." -ForegroundColor White
Write-Host "   (NOT the app called just 'Antigravity' - that is a different app!)" -ForegroundColor White
Write-Host "5. Read the cheat-sheet on your Desktop: FOAD-terminal-basics.txt" -ForegroundColor White
Write-Host ""

# Open the cheat-sheet automatically the first time so students actually see it.
if ($newGuidePath) {
    Write-Host "Opening your cheat-sheet now..." -ForegroundColor Gray
    try { Start-Process notepad.exe $newGuidePath | Out-Null } catch { }
}

Ok "FOAD setup finished. If anything shows [FIX] above, follow its 'how to fix' line - usually just restart PowerShell and re-run. Re-running is always safe."
Finish 0