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
#  MODULE: NETWORK TOOLKIT
# ============================================================
function ConvertTo-Ipv4String {
    param([Parameter(Mandatory)][uint32]$Value)
    $bytes = [byte[]]@(
        [byte](($Value -shr 24) -band 0xFF),
        [byte](($Value -shr 16) -band 0xFF),
        [byte](($Value -shr 8) -band 0xFF),
        [byte]($Value -band 0xFF)
    )
    return ([System.Net.IPAddress]::new($bytes)).ToString()
}

function Invoke-SubnetCalc {
    Show-Banner
    Write-SectionHeader "Subnet / CIDR Calculator"

    $cidr = Read-Host " Enter IP/CIDR (e.g. 192.168.1.10/24)"

    if ($cidr -notmatch '^(?<ip>\d{1,3}(\.\d{1,3}){3})/(?<prefix>\d{1,2})$') {
        Write-Host " Invalid format. Expected IP/CIDR, e.g. 10.0.0.5/24" -ForegroundColor Red
        Wait-ForKey
        return
    }

    $prefix = [int]$Matches['prefix']
    if ($prefix -lt 0 -or $prefix -gt 32) {
        Write-Host " Prefix must be between 0 and 32." -ForegroundColor Red
        Wait-ForKey
        return
    }

    $ip = $null
    if (-not [System.Net.IPAddress]::TryParse($Matches['ip'], [ref]$ip) -or
        $ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        Write-Host " Invalid IPv4 address." -ForegroundColor Red
        Wait-ForKey
        return
    }

    $ipBytes = $ip.GetAddressBytes()
    $ipValue = ([uint32]$ipBytes[0] -shl 24) -bor ([uint32]$ipBytes[1] -shl 16) -bor ([uint32]$ipBytes[2] -shl 8) -bor [uint32]$ipBytes[3]

    $maskValue = if ($prefix -eq 0) { [uint32]0 } else { [uint32]([uint32]::MaxValue -shl (32 - $prefix)) }
    $wildcardValue = (-bnot $maskValue) -band [uint32]::MaxValue
    $networkValue = $ipValue -band $maskValue
    $broadcastValue = $networkValue -bor $wildcardValue

    $totalHosts = [math]::Pow(2, 32 - $prefix)
    switch ($prefix) {
        32 {
            $usableHosts = 1
            $firstUsable = ConvertTo-Ipv4String $networkValue
            $lastUsable  = ConvertTo-Ipv4String $networkValue
        }
        31 {
            $usableHosts = 2
            $firstUsable = ConvertTo-Ipv4String $networkValue
            $lastUsable  = ConvertTo-Ipv4String $broadcastValue
        }
        default {
            $usableHosts = $totalHosts - 2
            $firstUsable = ConvertTo-Ipv4String ($networkValue + 1)
            $lastUsable  = ConvertTo-Ipv4String ($broadcastValue - 1)
        }
    }

    Write-Host ""
    Write-Host "  Network address   : $(ConvertTo-Ipv4String $networkValue)"
    Write-Host "  Broadcast address : $(ConvertTo-Ipv4String $broadcastValue)"
    Write-Host "  Subnet mask       : $(ConvertTo-Ipv4String $maskValue)  (/$prefix)"
    Write-Host "  Wildcard mask     : $(ConvertTo-Ipv4String $wildcardValue)"
    Write-Host "  Usable host range : $firstUsable - $lastUsable"
    Write-Host "  Total addresses   : $totalHosts"
    Write-Host "  Usable hosts      : $usableHosts"

    Wait-ForKey
}

function Invoke-DnsLookup {
    Show-Banner
    Write-SectionHeader "DNS Lookup"

    $target = Read-Host " Enter hostname or IP to resolve"
    if ([string]::IsNullOrWhiteSpace($target)) {
        Write-Host " Nothing entered." -ForegroundColor Red
        Wait-ForKey
        return
    }

    try {
        # Resolve-DnsName ships with the DnsClient module (Win8/Server 2012+, same floor as Get-NetTCPConnection).
        $results = Resolve-DnsName -Name $target -ErrorAction Stop |
            Select-Object Name, Type, TTL, @{
                Name       = 'Data'
                Expression = {
                    if ($_.PSObject.Properties['IPAddress']) { $_.IPAddress }
                    elseif ($_.PSObject.Properties['NameHost']) { $_.NameHost }
                    elseif ($_.PSObject.Properties['Strings']) { $_.Strings -join ' ' }
                    else { '' }
                }
            }

        $results | Format-Table -AutoSize | Out-String | Write-Host
        Write-Host " $(@($results).Count) record(s) found." -ForegroundColor $Script:Accent
    }
    catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }

    Wait-ForKey
}

function Invoke-TraceDiag {
    Show-Banner
    Write-SectionHeader "Latency / Traceroute"

    $target = Read-Host " Enter hostname or IP to test"
    if ([string]::IsNullOrWhiteSpace($target)) {
        Write-Host " Nothing entered." -ForegroundColor Red
        Wait-ForKey
        return
    }

    Write-Host " Testing connectivity and tracing route to $target (this can take a moment)..." -ForegroundColor DarkGray
    Write-Host ""

    try {
        $result = Test-NetConnection -ComputerName $target -TraceRoute -ErrorAction Stop

        Write-Host "  Remote address  : $($result.RemoteAddress)"
        Write-Host "  Ping succeeded   : $($result.PingSucceeded)"
        if ($result.PSObject.Properties['PingReplyDetails'] -and $result.PingReplyDetails) {
            Write-Host "  Round-trip time  : $($result.PingReplyDetails.RoundtripTime) ms"
        }

        Write-Host ""
        Write-Host " Trace route hops:" -ForegroundColor $Script:Accent
        $hop = 0
        foreach ($hopAddress in $result.TraceRoute) {
            $hop++
            Write-Host "  $hop`: $hopAddress"
        }
    }
    catch {
        Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host " (Target may be unreachable, or blocking ICMP.)" -ForegroundColor DarkGray
    }

    Wait-ForKey
}

function Invoke-NetToolkit {
    # Sub-menu follows the same hashtable dispatch pattern as the main menu.
    $NetDispatch = @{
        "1" = { Invoke-SubnetCalc }
        "2" = { Invoke-DnsLookup }
        "3" = { Invoke-TraceDiag }
    }

    while ($true) {
        Show-Banner
        Write-SectionHeader "Network Toolkit"
        Write-Host "  [1] Subnet / CIDR calculator"
        Write-Host "  [2] DNS lookup"
        Write-Host "  [3] Latency / traceroute"
        Write-Host "  [B] Back to main menu"
        Write-Host ""

        $netChoice = (Read-Host " Select an option").Trim().ToUpper()

        if ($netChoice -eq "B") {
            return
        }
        elseif ($NetDispatch.ContainsKey($netChoice)) {
            & $NetDispatch[$netChoice]
        }
        else {
            Write-Host " Invalid option." -ForegroundColor Red
            Start-Sleep -Milliseconds 800
        }
    }
}

# ============================================================
#  MODULE STUBS  (same shape as Invoke-PortsInUse - fill these in)
# ============================================================
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
