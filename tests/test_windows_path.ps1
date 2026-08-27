$ErrorActionPreference = "Stop"

. "$PSScriptRoot\..\install-windows.ps1" -LibraryOnly

$originalUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$originalProcessPath = $env:Path
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("foad-path-test-" + [guid]::NewGuid())

try {
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    Set-Content -Path (Join-Path $tempDir "claude.cmd") -Encoding Ascii -Value "@echo claude 9.9.9"

    [Environment]::SetEnvironmentVariable("Path", $originalUserPath, "User")
    $env:Path = "$tempDir;$originalProcessPath"

    if (-not (Check-CommandVersion "claude")) {
        throw "Synthetic current-session Claude command should be discoverable."
    }
    if (Check-CommandVersion "claude" -PersistentPathOnly) {
        throw "Claude must not pass the new-shell check before its directory is persisted."
    }
    if (-not (Ensure-CommandOnPersistentPath "claude")) {
        throw "Claude command directory was not persisted."
    }
    if (-not (Check-CommandVersion "claude" -PersistentPathOnly)) {
        throw "Claude did not pass after its directory was persisted."
    }

    Write-Host "Windows persistent PATH regression test: OK"
} finally {
    [Environment]::SetEnvironmentVariable("Path", $originalUserPath, "User")
    $env:Path = $originalProcessPath
    Publish-EnvironmentChange
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
}
