param(
    [switch]$AssumeYes,
    [switch]$LibraryOnly
)

<#
FOAD Dev Setup - Windows  (workshop edition, written for absolute beginners)
Installs: Git, Node.js LTS/npm, Google Antigravity IDE, Python 3, Claude Code,
  the GitHub/Supabase/Vercel CLIs, and beginner Claude Code skill files.

  This script NEVER signs anyone in. Service logins are interactive, need an
  account that may not exist yet, and would hang an unattended run - they are a
  separate step the person does themselves afterwards.
Run from PowerShell. Reruns preserve existing workshop files.
Pinned workshop source:
Invoke-WebRequest https://raw.githubusercontent.com/masterFoad/agent_setup/v2.1.4/install-windows.ps1 -OutFile $env:TEMP\foad-install-windows.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File $env:TEMP\foad-install-windows.ps1

Last verified against official sources: 2026-08-27
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
$script:InstallerVersion = "2.1.4"
$script:GuideFileName = "FOAD-terminal-basics-v$($script:InstallerVersion).txt"

# ---------------------------------------------------------------------------
# Output helpers, progress counter, run summary
# ---------------------------------------------------------------------------

$script:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:Summary = [ordered]@{}   # name -> @{ Status = "OK"|"WARN"|"FAIL"; Hint = "..." }
$script:PhaseNum = 0
$script:PhaseTotal = 9

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
            "WARN" { Write-Host ("  [WARN]  " + $key) -ForegroundColor Yellow; $anyBad = $true }
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
        Warn "Re-running is designed to preserve existing workshop files and skip detected packages."
    } else {
        Ok "Everything installed and verified. You are ready for the workshop!"
    }
    Write-Host ""
    if ($script:TranscriptStarted) {
        Write-Host "A full log of this setup was saved to your Desktop: FOAD-setup-log.txt" -ForegroundColor Gray
        Write-Host "If you get stuck, send that file to your instructor." -ForegroundColor Gray
    } else {
        Warn "The setup log could not be created. Copy the visible error output for your instructor."
    }
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
        (Join-Path $HOME "AppData\Local\Microsoft\WinGet\Links"),
        (Join-Path $HOME "AppData\Local\Microsoft\WindowsApps"),
        (Join-Path $HOME "scoop\shims")
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

    $seen = @{}
    $allEntries = @($machinePath, $userPath) + $extraDirs + @($env:Path)
    $uniqueEntries = foreach ($value in $allEntries) {
        foreach ($entry in @($value -split ";")) {
            $trimmed = $entry.Trim()
            if ($trimmed -and -not $seen.ContainsKey($trimmed)) {
                $seen[$trimmed] = $true
                $trimmed
            }
        }
    }
    $env:Path = $uniqueEntries -join ";"
}

function Get-PersistentWindowsPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    return (@($machinePath, $userPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ";"
}

function Publish-EnvironmentChange {
    try {
        if (-not ("FOAD.EnvironmentBroadcaster" -as [type])) {
            Add-Type -Namespace FOAD -Name EnvironmentBroadcaster -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(
    System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam,
    uint flags, uint timeout, out System.UIntPtr result);
'@
        }
        $result = [UIntPtr]::Zero
        [void][FOAD.EnvironmentBroadcaster]::SendMessageTimeout(
            [IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result)
    } catch {
        Warn "PATH was saved, but Windows could not notify open apps. Close and reopen them before testing commands."
    }
}

function Add-DirectoryToUserPath([string]$Directory) {
    if ([string]::IsNullOrWhiteSpace($Directory) -or -not (Test-Path -LiteralPath $Directory -PathType Container)) {
        return $false
    }

    $fullDirectory = [System.IO.Path]::GetFullPath($Directory).TrimEnd('\')
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($userPath -split ";" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $alreadyPresent = $entries | Where-Object {
        try { [System.IO.Path]::GetFullPath($_).TrimEnd('\') -ieq $fullDirectory }
        catch { $_.TrimEnd('\') -ieq $fullDirectory }
    }

    if (-not $alreadyPresent) {
        $newUserPath = (@($entries) + $fullDirectory) -join ";"
        [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
        Ok "Saved command folder to your user PATH: $fullDirectory"
        Publish-EnvironmentChange
    }

    return $true
}

function Get-CommandSourcePath($Command) {
    if (-not $Command) { return $null }
    if ($Command.Source) { return $Command.Source }
    return $Command.Path
}

function Resolve-ExternalCommand([string]$Command) {
    # Get-Command -All already returns matches in real resolution order: PATH
    # order across folders, PATHEXT order (.exe before .cmd) within a folder.
    #
    # Do NOT sort this list. Windows PowerShell 5.1's Sort-Object is not stable,
    # so ranking equally (every match is an Application) reshuffled the results
    # and a .cmd shim could be returned ahead of the real claude.exe. That wrong
    # source is what Ensure-CommandOnPersistentPath then wrote to the user PATH.
    # Filter in place instead, which keeps the original order.
    $found = @(Get-Command $Command -All -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)
    if ($found.Count -eq 0) { return $null }

    foreach ($candidate in $found) {
        if ($candidate.CommandType -eq "Application") { return $candidate }
    }
    return $found[0]
}

function Ensure-CommandOnPersistentPath([string]$Command) {
    Refresh-PathForCurrentSession
    $cmd = Resolve-ExternalCommand $Command
    if (-not $cmd) { return $false }

    $source = Get-CommandSourcePath $cmd
    if ([string]::IsNullOrWhiteSpace($source)) { return $false }
    return (Add-DirectoryToUserPath -Directory (Split-Path -Parent $source))
}

function Get-VerifiedSignedClaudePath {
    $candidates = @(
        (Join-Path $HOME ".local\bin\claude.exe"),
        (Join-Path $HOME "AppData\Local\Microsoft\WinGet\Links\claude.exe")
    )
    $candidates += @(Get-Command "claude" -All -CommandType Application -ErrorAction SilentlyContinue |
        ForEach-Object { Get-CommandSourcePath $_ })

    foreach ($source in @($candidates | Select-Object -Unique)) {
        if (-not $source -or -not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
        if ([System.IO.Path]::GetExtension($source) -ine ".exe") { continue }
        $signature = Get-AuthenticodeSignature -FilePath $source
        if ($signature.Status -eq "Valid" -and
            $signature.SignerCertificate.Subject -match "Anthropic") {
            Ok "Claude Code executable signature is valid: $($signature.SignerCertificate.Subject)"
            return $source
        }
    }

    Warn "No Claude Code executable with a valid Anthropic signature was found."
    return $null
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
        winget install --id $Id --exact --source winget --silent --accept-package-agreements --accept-source-agreements
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

function Install-NpmGlobalPackage([string]$Package, [string]$Name, [string]$CommandName) {
    Step "Installing $Name"

    if (Check-CommandVersion $CommandName) {
        Ensure-CommandOnPersistentPath $CommandName | Out-Null
        Ok "$Name is already installed."
        return $true
    }
    if (-not (Resolve-ExternalCommand "npm")) {
        FailMsg "npm is not available, so $Name could not be installed."
        return $false
    }

    try {
        npm install -g $Package
        Refresh-PathForCurrentSession
        if (Check-CommandVersion $CommandName) {
            Ensure-CommandOnPersistentPath $CommandName | Out-Null
            Ok "$Name installed."
            return $true
        }
        throw "npm finished but $CommandName did not answer."
    } catch {
        FailMsg "Could not install $Name`: $($_.Exception.Message)"
        return $false
    }
}

function Install-SupabaseCli {
    # Supabase documents Scoop as the only supported Windows install: there is no
    # winget package and no global npm install. Scoop installs into the user
    # profile, so this needs no administrator approval.
    Step "Installing Supabase CLI"

    if (Check-CommandVersion "supabase") {
        Ensure-CommandOnPersistentPath "supabase" | Out-Null
        Ok "Supabase CLI is already installed."
        return $true
    }

    try {
        if (-not (Resolve-ExternalCommand "scoop")) {
            Step "Installing Scoop (Supabase's Windows installer)"
            Invoke-RestMethod -Uri "https://get.scoop.sh" -UseBasicParsing | Invoke-Expression
            Refresh-PathForCurrentSession
        }
        if (-not (Resolve-ExternalCommand "scoop")) { throw "Scoop is still unavailable." }

        scoop bucket add supabase https://github.com/supabase/scoop-bucket.git 2>&1 | Out-Null
        scoop install supabase
        Refresh-PathForCurrentSession
        if (Check-CommandVersion "supabase") {
            Ensure-CommandOnPersistentPath "supabase" | Out-Null
            Ok "Supabase CLI installed."
            return $true
        }
        throw "Scoop finished but 'supabase' did not answer."
    } catch {
        FailMsg "Could not install the Supabase CLI: $($_.Exception.Message)"
        Warn "Install it later with Scoop, or run it per-project with: npx supabase"
        return $false
    }
}

function Install-ClaudeCodeNative {
    Step "Installing Claude Code"
    # First repair a previous install whose executable exists but whose folder was
    # never persisted to the User PATH (the most common v2.1.1 failure).
    Refresh-PathForCurrentSession
    if ((Check-CommandVersion "claude") -and
        (Ensure-CommandOnPersistentPath "claude") -and
        (Check-CommandVersion "claude" -PersistentPathOnly)) {
        Ok "Existing Claude Code installation is available in new PowerShell windows."
        return $true
    }

    # The official bootstrap now propagates its child installer exit code. Run it
    # in a separate PowerShell process so an upstream `exit` cannot terminate this
    # FOAD setup before it writes a summary and recovery guidance.
    $installerPath = Join-Path $env:TEMP ("foad-claude-install-" + [guid]::NewGuid() + ".ps1")
    try {
        Invoke-WebRequest -Uri "https://claude.ai/install.ps1" -UseBasicParsing -OutFile $installerPath
        $windowsPowerShell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $installerPath stable
        $nativeExitCode = $LASTEXITCODE
        if ($nativeExitCode -ne 0) { throw "official installer exited with code $nativeExitCode" }

        Refresh-PathForCurrentSession
        $signedClaudePath = Get-VerifiedSignedClaudePath
        if ($signedClaudePath -and
            (Add-DirectoryToUserPath (Split-Path -Parent $signedClaudePath)) -and
            (Check-CommandVersion "claude" -PersistentPathOnly)) {
            Ok "Claude Code installed and verified with the native installer."
            return $true
        }
        throw "The native installer finished, but persistent PATH or signature verification failed."
    } catch {
        Warn "Claude Code native installer failed: $($_.Exception.Message)"
    } finally {
        if (Test-Path $installerPath) { Remove-Item -Force $installerPath -ErrorAction SilentlyContinue }
    }

    Warn "Trying plan B: the official WinGet package."
    try {
        $wingetOk = Install-WingetPackage -Id "Anthropic.ClaudeCode" -Name "Claude Code (WinGet)"
        Refresh-PathForCurrentSession
        $signedClaudePath = Get-VerifiedSignedClaudePath
        if ($wingetOk -and $signedClaudePath -and
            (Add-DirectoryToUserPath (Split-Path -Parent $signedClaudePath)) -and
            (Check-CommandVersion "claude" -PersistentPathOnly)) {
            Ok "Claude Code installed and verified with WinGet."
            return $true
        }
        throw "WinGet completed, but persistent PATH or signature verification failed."
    } catch {
        Warn "The WinGet fallback failed: $($_.Exception.Message)"
        Warn "Install manually from https://code.claude.com/docs/en/setup, then rerun FOAD setup."
        return $false
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

    $guidePath = Join-Path (Get-DesktopPath) $script:GuideFileName
    $isNew = -not (Test-Path $guidePath)

    if (-not $isNew) {
        Ok "Keeping existing guide: $guidePath"
        return $null
    }

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
WSL is not required for this workshop. If Antigravity offers to install or
open WSL, choose Cancel, Skip, or Not now.
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

function Check-CommandVersion(
    [string]$Command,
    [string]$VersionArg = "--version",
    [switch]$PersistentPathOnly
) {
    $savedPath = $env:Path
    if ($PersistentPathOnly) {
        $env:Path = Get-PersistentWindowsPath
    } else {
        Refresh-PathForCurrentSession
    }

    $cmd = Resolve-ExternalCommand $Command
    if (-not $cmd) {
        $env:Path = $savedPath
        Warn "$Command is not available through the persistent Windows PATH."
        return $false
    }

    try {
        # Capture ALL output first, then take the first line. Piping a native
        # command directly into 'Select-Object -First 1' stops it early, which
        # kills the process and makes $LASTEXITCODE come back as -1 on success
        # (it prints the right version but falsely warns). Capture, record the
        # exit code immediately, then trim.
        $output = & (Get-CommandSourcePath $cmd) $VersionArg 2>&1
        $code = $LASTEXITCODE
        $result = ($output | Select-Object -First 1)
        if ($code -eq 0 -and $result -match '\d+\.\d+') {
            Ok "$Command works: $result"
            return $true
        }
        Warn "$Command exists but version check returned exit code $code`: $result"
        return $false
    } catch {
        Warn "$Command exists but version check failed: $Command $VersionArg"
        return $false
    } finally {
        $env:Path = $savedPath
    }
}

function Check-PythonVersion([switch]$PersistentPathOnly) {
    # winget Python installs sometimes only expose the "py" launcher until a
    # new shell picks up PATH changes. Accept either python or py.
    if (Check-CommandVersion "python" -PersistentPathOnly:$PersistentPathOnly) { return $true }
    Warn "Trying the 'py' launcher instead of 'python'..."
    if (Check-CommandVersion "py" -PersistentPathOnly:$PersistentPathOnly) {
        Ok "Python is available via 'py'. After restarting PowerShell, plain 'python' should work too."
        return $true
    }
    return $false
}

# ---------------------------------------------------------------------------
# WinGet bootstrap
# ---------------------------------------------------------------------------

function Ensure-Winget {
    # Returns $true if winget is usable in THIS session. If App Installer is
    # present but not registered for this user, use Microsoft's documented
    # registration command. Otherwise open the official Store listing.
    Step "Checking WinGet (the Windows app installer this script uses)"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Ok "WinGet found."
        return $true
    }

    Warn "WinGet is not active. Trying to register Microsoft's App Installer for this account..."

    try {
        Add-AppxPackage -RegisterByFamilyName `
            -MainPackage "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" `
            -ErrorAction Stop

        Refresh-PathForCurrentSession
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Ok "WinGet registered successfully."
            return $true
        }

        Warn "App Installer was registered, but 'winget' is not active in this PowerShell session yet."
        Warn "Close PowerShell, open it again, and paste the setup command once more. Existing workshop files are preserved."
        return $false
    } catch {
        Warn "App Installer registration was unavailable: $($_.Exception.Message)"
        FailMsg "Install or update 'App Installer' from the Microsoft Store (opening now), then rerun setup."
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

$script:HandlingUnexpectedError = $false
trap {
    if ($script:HandlingUnexpectedError) { exit 1 }
    $script:HandlingUnexpectedError = $true
    FailMsg "Unexpected setup error: $($_.Exception.Message)"
    Record "Unexpected setup error" "FAIL" "Copy this error and the preceding output for your instructor, then rerun setup."
    Show-Summary
    Finish 1
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if ($LibraryOnly) { return }

# Log everything to the Desktop so students can send the instructor one file.
$script:LogPath = Join-Path (Get-DesktopPath) "FOAD-setup-log.txt"
$script:TranscriptStarted = $false
try {
    Start-Transcript -Path $script:LogPath -Append | Out-Null
    $script:TranscriptStarted = $true
} catch {
    Warn "Could not start the Desktop setup log: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "        FOAD DEV SETUP - Claude Code Workshop             " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Installer version: $($script:InstallerVersion)" -ForegroundColor Gray
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
Write-Host "same command from the website. Existing workshop files are preserved." -ForegroundColor Yellow

if (-not $AssumeYes) {
    Write-Host ""
    Write-Host "Before continuing:" -ForegroundColor Cyan
    Write-Host "  - Allow 10-25 minutes and several gigabytes of free disk space."
    Write-Host "  - Windows may request administrator approval for individual packages."
    Write-Host "  - Claude Code needs an eligible Claude subscription, Console account, or supported provider."
    Write-Host "  - Antigravity IDE sign-in may require a Google account."
    Write-Host "  - WSL is not required. If Antigravity asks for WSL, skip it and select PowerShell."
    Write-Host "  - This setup creates files under .claude and on your Desktop and saves a setup log."
    $consent = Read-Host "Press ENTER to continue, or type Q to cancel"
    if ($consent -match '^[Qq]$') {
        Write-Host "Setup cancelled. No installation steps were started."
        Finish 0
    }
}

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
try { $gitOk = Install-WingetPackage -Id "Git.Git" -Name "Git" -Required }
catch {
    FailMsg $_.Exception.Message
    Record "Git" "FAIL" "Check internet/UAC access, then rerun the setup."
    Show-Summary
    Finish 1
}
Record "Git" $(if ($gitOk) { "OK" } else { "FAIL" }) "Check the error above and rerun setup; the package installer will request elevation if needed."

Phase "Installing Node.js + npm" "Node.js runs JavaScript on your computer; npm installs JavaScript packages."
try { $nodeOk = Install-WingetPackage -Id "OpenJS.NodeJS.LTS" -Name "Node.js LTS + npm" -Required }
catch {
    FailMsg $_.Exception.Message
    Record "Node.js + npm" "FAIL" "Check internet/UAC access, then rerun the setup."
    Show-Summary
    Finish 1
}
Record "Node.js + npm" $(if ($nodeOk) { "OK" } else { "FAIL" }) "Check the error above and rerun setup; the package installer will request elevation if needed."
Refresh-PathForCurrentSession

Phase "Installing Antigravity IDE" "The code editor we use in the workshop. THIS IS THE BIG ONE - it may look frozen while downloading. It is not. Please wait."
# Google.AntigravityIDE = the full IDE (what we want).
# Google.Antigravity    = a DIFFERENT app since 2026 (agent orchestrator, no editor). Do NOT add it here.
$agOk = Install-FirstAvailableWingetPackage -Ids @("Google.AntigravityIDE") -Name "Google Antigravity IDE" -FallbackUrl "https://antigravity.google/download"
Record "Antigravity IDE" $(if ($agOk) { "OK" } else { "FAIL" }) "The download page opened in your browser - install Antigravity IDE, then rerun this setup."

Phase "Installing Python 3 + pip" "Python runs many scripts and tools that Claude Code will write for you."
# Pin to current minor versions, NEWEST FIRST (3.14 is the current stable line);
# winget IDs are version-specific.
$pyOk = Install-FirstAvailableWingetPackage -Ids @("Python.Python.3.14", "Python.Python.3.13", "Python.Python.3.12") -Name "Python 3 + pip" -FallbackUrl "https://www.python.org/downloads/windows/"
Record "Python 3 + pip" $(if ($pyOk) { "OK" } else { "FAIL" }) "The Python download page opened - install Python and select 'Add python.exe to PATH', then rerun."
Refresh-PathForCurrentSession

Phase "Installing Claude Code" "The AI coding assistant - the star of this workshop."
$ccOk = Install-ClaudeCodeNative
Record "Claude Code" $(if ($ccOk) { "OK" } else { "FAIL" }) "Close PowerShell, reopen it, run the setup command again. Manual install: https://code.claude.com/docs/en/setup"

Phase "Installing service CLIs" "Command-line tools for GitHub, Supabase and Vercel. Signing in comes later, and you do that part yourself."
$ghOk = Install-WingetPackage -Id "GitHub.cli" -Name "GitHub CLI"
Record "GitHub CLI" $(if ($ghOk) { "OK" } else { "FAIL" }) "Rerun setup, or install GitHub CLI from https://cli.github.com"
Refresh-PathForCurrentSession
$sbOk = Install-SupabaseCli
Record "Supabase CLI" $(if ($sbOk) { "OK" } else { "FAIL" }) "Rerun setup, or run it per-project with: npx supabase"
$vcOk = Install-NpmGlobalPackage -Package "vercel" -Name "Vercel CLI" -CommandName "vercel"
Record "Vercel CLI" $(if ($vcOk) { "OK" } else { "FAIL" }) "Rerun setup, or install with: npm install -g vercel"
Refresh-PathForCurrentSession

Phase "Creating workshop files" "A starter Claude skill, a starter command, and a cheat-sheet on your Desktop."
try {
    Write-ClaudeStarterFiles
    Record "Claude starter files" "OK"
} catch {
    FailMsg "Could not create Claude starter files: $($_.Exception.Message)"
    Record "Claude starter files" "FAIL" "Check access to your .claude folder, then rerun setup."
}
try {
    $newGuidePath = Write-TerminalGuide
    Record "Desktop cheat-sheet" "OK"
} catch {
    FailMsg "Could not create the Desktop cheat-sheet: $($_.Exception.Message)"
    Record "Desktop cheat-sheet" "FAIL" "Check access to your Desktop folder, then rerun setup."
    $newGuidePath = $null
}

Phase "Final check" "Testing that every tool actually answers when called."
Record "git works in a new PowerShell"    $(if (Check-CommandVersion "git" -PersistentPathOnly)    { "OK" } else { "FAIL" }) "Open a new PowerShell and try: git --version"
Record "node works in a new PowerShell"   $(if (Check-CommandVersion "node" -PersistentPathOnly)   { "OK" } else { "FAIL" }) "Open a new PowerShell and try: node --version"
Record "npm works in a new PowerShell"    $(if (Check-CommandVersion "npm" -PersistentPathOnly)    { "OK" } else { "FAIL" }) "Open a new PowerShell and try: npm --version"
Record "python works in a new PowerShell" $(if (Check-PythonVersion -PersistentPathOnly)            { "OK" } else { "FAIL" }) "Open a new PowerShell and try: python --version (or: py --version)"
Record "pip works in a new PowerShell"    $(if (Check-CommandVersion "pip" -PersistentPathOnly)    { "OK" } else { "FAIL" }) "Open a new PowerShell and try: pip --version"
Record "claude works in a new PowerShell" $(if (Check-CommandVersion "claude" -PersistentPathOnly) { "OK" } else { "FAIL" }) "Rerun setup. If it still fails, send FOAD-setup-log.txt to the instructor."
Record "gh works in a new PowerShell"       $(if (Check-CommandVersion "gh" -PersistentPathOnly)       { "OK" } else { "FAIL" }) "Open a new PowerShell and try: gh --version"
Record "supabase works in a new PowerShell" $(if (Check-CommandVersion "supabase" -PersistentPathOnly) { "OK" } else { "FAIL" }) "Open a new PowerShell and try: supabase --version"
Record "vercel works in a new PowerShell"   $(if (Check-CommandVersion "vercel" -PersistentPathOnly)   { "OK" } else { "FAIL" }) "Open a new PowerShell and try: vercel --version"

$hasFailure = $script:Summary.Values | Where-Object { $_.Status -eq "FAIL" } | Select-Object -First 1
Show-Summary

if ($hasFailure) {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host " SETUP IS NOT READY YET" -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host "Do not continue to Claude or Antigravity yet." -ForegroundColor White
    Write-Host "Follow the 'how to fix' line in the summary, rerun setup, and send" -ForegroundColor White
    Write-Host "FOAD-setup-log.txt from the Desktop to your instructor if it still fails." -ForegroundColor White
    Finish 1
}

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
Write-Host "   WSL IS NOT REQUIRED. If Antigravity asks about WSL, choose Skip/Cancel." -ForegroundColor Yellow
Write-Host "   In its terminal menu choose: Select Default Profile -> PowerShell." -ForegroundColor Yellow
Write-Host "5. Sign in to your accounts. The setup page lists the commands:" -ForegroundColor White
Write-Host "   gh auth login   |   supabase login   |   vercel login" -ForegroundColor White
Write-Host "6. Read the cheat-sheet on your Desktop: $($script:GuideFileName)" -ForegroundColor White
Write-Host ""

# Open the cheat-sheet automatically the first time so students actually see it.
if ($newGuidePath) {
    Write-Host "Opening your cheat-sheet now..." -ForegroundColor Gray
    try { Start-Process notepad.exe $newGuidePath | Out-Null } catch { }
}

Ok "FOAD setup finished. Review any [WARN] items above before the workshop."
Finish 0
