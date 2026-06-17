<#
Build the Windows FOAD Dev Setup EXE.
Run on Windows PowerShell from the repository root:

powershell -NoProfile -ExecutionPolicy Bypass -File .\packaging\windows\build-windows-exe.ps1

Output:
dist\windows\FOAD-Dev-Setup-Windows.exe
#>

$ErrorActionPreference = "Stop"

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
& $isccPath ".\packaging\windows\foad-dev-setup.iss"

Step "Done"
Write-Host "Built: dist\windows\FOAD-Dev-Setup-Windows.exe" -ForegroundColor Green
