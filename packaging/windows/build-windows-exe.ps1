<#
Build the Windows FOAD Dev Setup EXE.
Run on Windows PowerShell from the repository root:

powershell -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows\build-windows-exe.ps1

Output:
dist\windows\FOAD-Dev-Setup-Windows.exe
#>

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$version = (Get-Content (Join-Path $root "VERSION") -Raw).Trim()

if (-not $env:FOAD_ALLOW_UNTAGGED_BUILD) {
    $dirty = git -C $root status --porcelain
    if ($dirty) { throw "Release builds require a clean Git working tree." }
    $tag = git -C $root describe --exact-match --tags HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or $tag -ne "v$version") {
        throw "Release builds require HEAD to be tagged v$version. Set FOAD_ALLOW_UNTAGGED_BUILD=1 only for local test builds."
    }
}

function Step($msg) {
    Write-Host ""
    Write-Host "=== $msg ===" -ForegroundColor Cyan
}

Step "Checking Inno Setup compiler"
$isccCommand = Get-Command iscc.exe -ErrorAction SilentlyContinue
$isccPath = if ($isccCommand) { $isccCommand.Source } else { $null }

if (-not $isccPath) {
    Step "Installing Inno Setup with WinGet"
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "WinGet is required to install Inno Setup automatically. Install Inno Setup manually from https://jrsoftware.org/isinfo.php and rerun."
    }
    winget install --id JRSoftware.InnoSetup --exact --silent --accept-package-agreements --accept-source-agreements

    $possible = @(
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
    )
    foreach ($path in $possible) {
        if (Test-Path $path) { $isccPath = $path; break }
    }
}

if (-not $isccPath) {
    throw "Could not find iscc.exe. Open a new PowerShell after installing Inno Setup, or add Inno Setup to PATH."
}

Step "Building EXE"
& $isccPath "/DMyAppVersion=$version" ".\packaging\windows\foad-dev-setup.iss"
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE" }

$artifact = Join-Path $root "dist\windows\FOAD-Dev-Setup-Windows.exe"
$checksum = (Get-FileHash -Algorithm SHA256 $artifact).Hash.ToLowerInvariant()
"$checksum  FOAD-Dev-Setup-Windows.exe" | Set-Content "$artifact.sha256" -Encoding ascii

Step "Done"
Write-Host "Built: dist\windows\FOAD-Dev-Setup-Windows.exe" -ForegroundColor Green
Write-Host "Checksum: dist\windows\FOAD-Dev-Setup-Windows.exe.sha256" -ForegroundColor Green
Write-Host "Production: Authenticode-sign the EXE, then regenerate this checksum before publishing." -ForegroundColor Yellow
