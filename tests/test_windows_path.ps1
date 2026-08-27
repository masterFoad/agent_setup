$ErrorActionPreference = "Stop"

. "$PSScriptRoot\..\install-windows.ps1" -LibraryOnly

$originalUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$originalProcessPath = $env:Path

# Never probe with the real command name. A Claude Code install that already
# sits on the persistent PATH would satisfy every assertion below on its own,
# so the test would pass without exercising any of the code under test (and the
# "must fail before persist" assertion would fail for an unrelated reason).
$probe = "foad-path-probe-" + [guid]::NewGuid().ToString("N")

# GetTempPath can hand back a short (8.3) or differently-cased path, while
# Add-DirectoryToUserPath persists the fully expanded form. Compare normalized.
function Normalize-Dir([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    try { return [System.IO.Path]::GetFullPath($Path).TrimEnd('\') }
    catch { return $Path.TrimEnd('\') }
}

$firstDir = Join-Path ([System.IO.Path]::GetTempPath()) ("foad-path-test-first-" + [guid]::NewGuid())
$secondDir = Join-Path ([System.IO.Path]::GetTempPath()) ("foad-path-test-second-" + [guid]::NewGuid())

try {
    New-Item -ItemType Directory -Path $firstDir | Out-Null
    New-Item -ItemType Directory -Path $secondDir | Out-Null
    Set-Content -Path (Join-Path $firstDir "$probe.cmd") -Encoding Ascii -Value "@echo $probe 9.9.9"
    Set-Content -Path (Join-Path $secondDir "$probe.cmd") -Encoding Ascii -Value "@echo $probe 1.1.1"

    [Environment]::SetEnvironmentVariable("Path", $originalUserPath, "User")
    $env:Path = "$firstDir;$secondDir;$originalProcessPath"

    # Both matches are Applications, so they rank equally. Sorting them here (as
    # Resolve-ExternalCommand used to) reorders them under Windows PowerShell
    # 5.1's unstable Sort-Object, which is how a shim could beat the real binary.
    $resolved = Resolve-ExternalCommand $probe
    if (-not $resolved) {
        throw "Synthetic probe command should be discoverable in the current session."
    }
    $resolvedDir = Normalize-Dir (Split-Path -Parent (Get-CommandSourcePath $resolved))
    if ($resolvedDir -ine (Normalize-Dir $firstDir)) {
        throw "Resolve-ExternalCommand must keep PATH order; expected '$firstDir' but got '$resolvedDir'."
    }

    if (-not (Check-CommandVersion $probe)) {
        throw "Synthetic current-session probe command should be discoverable."
    }
    if (Check-CommandVersion $probe -PersistentPathOnly) {
        throw "Probe must not pass the new-shell check before its directory is persisted."
    }
    if (-not (Ensure-CommandOnPersistentPath $probe)) {
        throw "Probe command directory was not persisted."
    }

    # The persisted directory must be the one PATH order actually selects.
    $persistedUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $persistedEntries = @($persistedUserPath -split ";" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { Normalize-Dir $_ })
    if ($persistedEntries -inotcontains (Normalize-Dir $firstDir)) {
        throw "Expected '$firstDir' to be persisted to the user PATH, got: $persistedUserPath"
    }
    if ($persistedEntries -icontains (Normalize-Dir $secondDir)) {
        throw "The shadowed directory '$secondDir' must not be persisted to the user PATH."
    }

    if (-not (Check-CommandVersion $probe -PersistentPathOnly)) {
        throw "Probe did not pass after its directory was persisted."
    }

    Write-Host "Windows persistent PATH regression test: OK"
} finally {
    [Environment]::SetEnvironmentVariable("Path", $originalUserPath, "User")
    $env:Path = $originalProcessPath
    Publish-EnvironmentChange
    if (Test-Path $firstDir) { Remove-Item -Recurse -Force $firstDir }
    if (Test-Path $secondDir) { Remove-Item -Recurse -Force $secondDir }
}
