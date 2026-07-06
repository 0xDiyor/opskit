<#
.SYNOPSIS
    opskit - IT diagnostics toolkit for the terminal (PowerShell 5.1-safe)
.NOTES
    Author: 0xDiyor
    Target: Windows PowerShell 5.1 (stock, zero dependencies)
    Design: functions do the work, the menu is just a wrapper.
    Pattern to remember: MENU -> DISPATCH -> FUNCTION -> PAUSE -> MENU
#>

# ============================================================
#  CONFIG
# ============================================================
$Script:Version = "0.1.0"
$Script:Accent  = "Green"     # 16-color safe. No ANSI/hex in 5.1 conhost.

# ============================================================
#  UI HELPERS
# ============================================================
function Show-Banner {
    Clear-Host
    # ASCII-only banner: avoids Unicode codepage issues in conhost.
    $banner = @"
  ___  ____  ____  _  _  ____  ____
 / __)(  _ \/ ___)( )/ )(_  _)(_  _)
( (_) ))___/\___ \ )  (  _)(_   )(
 \___/(__)  (____/(_)\_)(____) (__)
"@
    Write-Host $banner -ForegroundColor $Script:Accent
    Write-Host " opskit v$($Script:Version) - IT diagnostics toolkit" -ForegroundColor DarkGray
    Write-Host " ------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Write-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host " == $Title ==" -ForegroundColor $Script:Accent
    Write-Host ""
}

function Wait-ForKey {
    Write-Host ""
    Write-Host " Press any key to return to menu..." -ForegroundColor DarkGray
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    catch {
        # RawUI.ReadKey isn't implemented in some hosts (e.g. the ISE).
        $null = Read-Host
    }
}

# ============================================================
#  MODULE: PORTS  (fully working - use as the template)
# ============================================================
function Invoke-PortsInUse {
    Show-Banner
    Write-SectionHeader "Ports In Use"

    Write-Host " Gathering listening ports and owning processes..." -ForegroundColor DarkGray

    try {
        # Get-NetTCPConnection exists in 5.1. Join PID -> process name.
        $conns = Get-NetTCPConnection -State Listen -ErrorAction Stop |
            Sort-Object LocalPort |
            ForEach-Object {
                $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
                [PSCustomObject]@{
                    Port    = $_.LocalPort
                    Address = $_.LocalAddress
                    PID     = $_.OwningProcess
                    Process = if ($proc) { $proc.ProcessName } else { "unknown" }
                }
            }

        # Format-Table -AutoSize gives clean columns for free.
        $conns | Format-Table -AutoSize | Out-String | Write-Host

        Write-Host " $(@($conns).Count) listening ports found." -ForegroundColor $Script:Accent
    }
    catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host " (Some queries require an elevated prompt.)" -ForegroundColor DarkGray
    }

    Wait-ForKey
}

# ============================================================
#  MODULE STUBS  (same shape as Invoke-PortsInUse - fill these in)
# ============================================================
function Invoke-NetToolkit {
    Show-Banner
    Write-SectionHeader "Network Toolkit"
    # TODO: submenu -> subnet calc | DNS lookup (Resolve-DnsName) | slow-path diag (Test-NetConnection -TraceRoute)
    Write-Host " Not implemented yet." -ForegroundColor Yellow
    Wait-ForKey
}

function Invoke-HealthSnapshot {
    Show-Banner
    Write-SectionHeader "System Health Snapshot"
    # TODO: Get-CimInstance Win32_OperatingSystem / Win32_Processor / Win32_LogicalDisk
    #       + uptime + top 5 processes by CPU/RAM. Add -Export flag for ticket notes.
    Write-Host " Not implemented yet." -ForegroundColor Yellow
    Wait-ForKey
}

function Invoke-CertChecker {
    Show-Banner
    Write-SectionHeader "Certificate Checker"
    # TODO: [Net.Sockets.TcpClient] + SslStream to pull remote cert, check NotAfter vs warn threshold.
    #       Local store: Get-ChildItem Cert:\LocalMachine\My
    Write-Host " Not implemented yet." -ForegroundColor Yellow
    Wait-ForKey
}

# ============================================================
#  MENU (dispatch table pattern - add a line here per new module)
# ============================================================
function Show-Menu {
    Show-Banner
    Write-Host "  [1] Network toolkit   (subnet / DNS / slow-path)"
    Write-Host "  [2] Ports in use"
    Write-Host "  [3] System health snapshot"
    Write-Host "  [4] Certificate checker"
    Write-Host "  [Q] Quit"
    Write-Host ""
}

# Main loop: the pattern to remember is a hashtable dispatch,
# not a giant if/elseif chain. New feature = one function + one entry.
$Dispatch = @{
    "1" = { Invoke-NetToolkit }
    "2" = { Invoke-PortsInUse }
    "3" = { Invoke-HealthSnapshot }
    "4" = { Invoke-CertChecker }
}

while ($true) {
    Show-Menu
    $choice = (Read-Host " Select an option").Trim().ToUpper()

    if ($choice -eq "Q") {
        Write-Host ""
        Write-Host " Later. - opskit" -ForegroundColor $Script:Accent
        break
    }
    elseif ($Dispatch.ContainsKey($choice)) {
        & $Dispatch[$choice]
    }
    else {
        Write-Host " Invalid option." -ForegroundColor Red
        Start-Sleep -Milliseconds 800
    }
}
