#Requires -Version 5.1
<#
.SYNOPSIS
    CI smoke test: drives the opskit menu end-to-end via redirected stdin
    and asserts each module produced its expected output.
.NOTES
    Windows-only modules (ports, health, local certs) only produce real
    results on a Windows host; run this on a windows-latest CI runner.
#>

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '..\opskit.ps1'

# Prefer Windows PowerShell 5.1 (the compatibility floor) when available.
$shell = if (Get-Command powershell.exe -ErrorAction SilentlyContinue) { 'powershell.exe' } else { 'pwsh' }

# One line per Read-Host prompt; blank lines answer the Wait-ForKey pause.
$inputSequence = @(
    '1'                  # main menu    -> network toolkit
    '1'                  # net toolkit  -> subnet calculator
    '192.168.1.10/24'
    ''                   # return to net toolkit menu
    '2'                  # net toolkit  -> DNS lookup
    'github.com'
    ''
    'B'                  # back to main menu
    '2'                  # main menu    -> ports in use
    ''
    '3'                  # main menu    -> health snapshot
    'N'                  # skip ticket-note export
    ''
    '4'                  # main menu    -> cert checker
    '2'                  # cert checker -> local store scan
    ''
    'B'
    'Q'                  # quit
) -join [Environment]::NewLine

Write-Output "Running smoke test with $shell..."
$output = $inputSequence | & $shell -NoProfile -ExecutionPolicy Bypass -File $scriptPath | Out-String
$exitCode = $LASTEXITCODE

# Each check passes if ANY of its markers appears in the output.
$checks = [ordered]@{
    'subnet calculator ran'   = @('Usable hosts      : 254')
    'dns lookup ran'          = @('record(s) found')
    'ports module ran'        = @('listening ports found')
    'health snapshot ran'     = @('Top 5 processes by CPU time')
    'local cert store ran'    = @('certificate(s) total', 'No certificates found in LocalMachine')
    'menu exited cleanly'     = @('Later. - opskit')
}

$failed = $false
foreach ($check in $checks.GetEnumerator()) {
    $hit = $check.Value | Where-Object { $output -like "*$_*" } | Select-Object -First 1
    if ($hit) {
        Write-Output "PASS: $($check.Key)"
    }
    else {
        Write-Output "FAIL: $($check.Key) (expected output containing one of: $($check.Value -join ' | '))"
        $failed = $true
    }
}

if ($output -match ' ERROR:') {
    Write-Output "FAIL: output contains an unexpected module error"
    $failed = $true
}

if ($exitCode -ne 0) {
    Write-Output "FAIL: opskit exited with code $exitCode"
    $failed = $true
}

if ($failed) {
    Write-Output ""
    Write-Output "===== full opskit output ====="
    Write-Output $output
    exit 1
}

Write-Output ""
Write-Output "Smoke test passed."
