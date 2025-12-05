<#
.SYNOPSIS
    Comprehensive System Information Collector with Parallel Execution
.DESCRIPTION
    Collects detailed system information including user, network, host, firewall,
    installed apps, services, event logs, updates, uptime, resources, and DNS.
    Outputs a formatted HTML report.
.PARAMETER OutputPath
    Path for the HTML report. Defaults to SystemInfo_<ComputerName>_<Date>.html
.EXAMPLE
    .\Get-SystemInfoReport.ps1
    .\Get-SystemInfoReport.ps1 -OutputPath "C:\Reports\MyReport.html"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath
)

# Set default output path if not provided
if (-not $OutputPath) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = "SystemInfo_$($env:COMPUTERNAME)_$timestamp.html"
}

Write-Host "System Information Report Generator" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Collecting data in parallel..." -ForegroundColor Yellow

# Initialize result storage
$results = @{}

# Define data collection script blocks for parallel execution
$scriptBlocks = @{
    'UserInfo' = {
        try {
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $loggedOnUsers = Get-WmiObject -Class Win32_ComputerSystem | Select-Object -ExpandProperty UserName
            $lastLogon = Get-WmiObject -Class Win32_NetworkLoginProfile |
                Where-Object { $_.Name -notlike "*SYSTEM*" } |
                Select-Object Name, @{N='LastLogon';E={[Management.ManagementDateTimeConverter]::ToDateTime($_.LastLogon)}}

            @{
                CurrentUser = $currentUser
                LoggedOnUser = $loggedOnUsers
                RecentLogons = $lastLogon
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }

    'HostInfo' = {
        try {
            $cs = Get-WmiObject -Class Win32_ComputerSystem
            $os = Get-WmiObject -Class Win32_OperatingSystem
            $bios = Get-WmiObject -Class Win32_BIOS

            @{
                ComputerName = $cs.Name
                Domain = $cs.Domain
                Manufacturer = $cs.Manufacturer
                Model = $cs.Model
                TotalPhysicalMemory = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
                OS = $os.Caption
                OSVersion = $os.Version
                OSArchitecture = $os.OSArchitecture
                InstallDate = [Management.ManagementDateTimeConverter]::ToDateTime($os.InstallDate)
                BIOSVersion = $bios.SMBIOSBIOSVersion
                SerialNumber = $bios.SerialNumber
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }

    'UptimeResources' = {
        try {
            $os = Get-WmiObject -Class Win32_OperatingSystem
            $lastBootTime = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
            $uptime = (Get-Date) - $lastBootTime

            $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
            $cpuLoad = (Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue

            $mem = Get-WmiObject -Class Win32_OperatingSystem
            $memUsed = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / 1MB, 2)
            $memTotal = [math]::Round($mem.TotalVisibleMemorySize / 1MB, 2)
            $memPercent = [math]::Round(($memUsed / $memTotal) * 100, 2)

            $disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
                @{
                    Drive = $_.DeviceID
                    Size = [math]::Round($_.Size / 1GB, 2)
                    FreeSpace = [math]::Round($_.FreeSpace / 1GB, 2)
                    PercentFree = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
                }
            }

            @{
                LastBootTime = $lastBootTime
                UptimeDays = $uptime.Days
                UptimeHours = $uptime.Hours
                UptimeMinutes = $uptime.Minutes
                CPUName = $cpu.Name
                CPUCores = $cpu.NumberOfCores
                CPULogicalProcessors = $cpu.NumberOfLogicalProcessors
                CPULoad = [math]::Round($cpuLoad, 2)
                MemoryUsedGB = $memUsed
                MemoryTotalGB = $memTotal
                MemoryPercent = $memPercent
                Disks = $disks
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }

    'NetworkInfo' = {
        try {
            $adapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
                $adapter = $_
                $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue
                $gateway = Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty NextHop -First 1

                @{
                    Name = $adapter.Name
                    Description = $adapter.InterfaceDescription
                    Status = $adapter.Status
                    MACAddress = $adapter.MacAddress
                    LinkSpeed = $adapter.LinkSpeed
                    IPv4Address = ($ipConfig | Where-Object { $_.AddressFamily -eq 'IPv4' }).IPAddress
                    IPv6Address = ($ipConfig | Where-Object { $_.AddressFamily -eq 'IPv6' }).IPAddress
                    DefaultGateway = $gateway
                }
            }

            $publicIP = try {
                (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5)
            } catch {
                "Unable to retrieve"
            }

            @{
                Adapters = $adapters
                PublicIP = $publicIP
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }

    'DNSInfo' = {
        try {
            $dnsServers = Get-DnsClientServerAddress -AddressFamily IPv4 |
                Where-Object { $_.ServerAddresses.Count -gt 0 } |
                Select-Object InterfaceAlias, ServerAddresses

            $dnsCache = Get-DnsClientCache |
                Select-Object Entry, Name, Type, TimeToLive, Data

            @{
                DNSServers = $dnsServers
                DNSCache = $dnsCache
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }

    'FirewallInfo' = {
        try {
            $firewallProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction

            $firewallRules = Get-NetFirewallRule |
                Where-Object { $_.Enabled -eq $true } |
                Select-Object DisplayName, Direction, Action, Profile, Enabled

            @{
                Profiles = $firewallProfiles
                ActiveRules = $firewallRules
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }

    'InstalledApps' = {
        try {
            $apps = @()

            # Get apps from both 32-bit and 64-bit registry
            $regPaths = @(
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            )

            foreach ($path in $regPaths) {
                $apps += Get-ItemProperty $path -ErrorAction SilentlyContinue |
                    Where-Object { $_.DisplayName } |
                    Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation
            }

            # Also get modern apps
            $modernApps = Get-AppxPackage |
                Select-Object Name, Version, Publisher, InstallLocation

            @{
                TraditionalApps = ($apps | Sort-Object DisplayName -Unique)
                ModernApps = $modernApps
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }

    'Services' = {
        try {
            $runningServices = Get-Service | Where-Object { $_.Status -eq 'Running' } |
                Select-Object Name, DisplayName, Status, StartType

            $stoppedCritical = Get-Service | Where-Object {
                $_.Status -eq 'Stopped' -and $_.StartType -eq 'Automatic'
            } | Select-Object Name, DisplayName, Status, StartType

            @{
                Running = $runningServices
                StoppedAutomatic = $stoppedCritical
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }

    'EventLogs' = {
        try {
            $systemErrors = Get-EventLog -LogName System -EntryType Error -Newest 100 -ErrorAction SilentlyContinue |
                Select-Object TimeGenerated, Source, EventID, Message

            $applicationErrors = Get-EventLog -LogName Application -EntryType Error -Newest 100 -ErrorAction SilentlyContinue |
                Select-Object TimeGenerated, Source, EventID, Message

            $securityAudits = Get-EventLog -LogName Security -Newest 100 -ErrorAction SilentlyContinue |
                Select-Object TimeGenerated, Source, EventID, Message

            @{
                SystemErrors = $systemErrors
                ApplicationErrors = $applicationErrors
                SecurityAudits = $securityAudits
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }

    'WindowsUpdate' = {
        try {
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()

            $pendingUpdates = $updateSearcher.Search("IsInstalled=0").Updates
            $installedUpdates = $updateSearcher.Search("IsInstalled=1").Updates

            $hotfixes = Get-HotFix |
                Select-Object Description, HotFixID, InstalledBy, InstalledOn

            @{
                PendingCount = $pendingUpdates.Count
                PendingUpdates = ($pendingUpdates | ForEach-Object { $_.Title })
                RecentHotfixes = $hotfixes
                LastSearchSuccessDate = $updateSearcher.GetTotalHistoryCount()
            }
        } catch {
            @{ Error = $_.Exception.Message }
        }
    }
}

# Execute all script blocks in parallel using runspaces
$runspacePool = [runspacefactory]::CreateRunspacePool(1, 10)
$runspacePool.Open()

$jobs = @()
foreach ($key in $scriptBlocks.Keys) {
    Write-Host "Starting collection: $key" -ForegroundColor Gray

    $powershell = [powershell]::Create().AddScript($scriptBlocks[$key])
    $powershell.RunspacePool = $runspacePool

    $jobs += [PSCustomObject]@{
        Name = $key
        PowerShell = $powershell
        Handle = $powershell.BeginInvoke()
    }
}

# Wait for all jobs to complete and collect results
foreach ($job in $jobs) {
    $results[$job.Name] = $job.PowerShell.EndInvoke($job.Handle)
    $job.PowerShell.Dispose()
    Write-Host "Completed collection: $($job.Name)" -ForegroundColor Green
}

$runspacePool.Close()
$runspacePool.Dispose()

Write-Host "`nGenerating HTML report..." -ForegroundColor Yellow

# Generate HTML Report
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Information Report - $($env:COMPUTERNAME)</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            line-height: 1.6;
        }

        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }

        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }

        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }

        .content {
            padding: 30px;
        }

        .section {
            margin-bottom: 30px;
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            border-left: 4px solid #667eea;
        }

        .section h2 {
            color: #667eea;
            margin-bottom: 15px;
            font-size: 1.8em;
            display: flex;
            align-items: center;
        }

        .section h2::before {
            content: '▶';
            margin-right: 10px;
            font-size: 0.7em;
        }

        .section h3 {
            color: #764ba2;
            margin: 15px 0 10px 0;
            font-size: 1.3em;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
            background: white;
            border-radius: 5px;
            overflow: hidden;
        }

        th {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 12px;
            text-align: left;
            font-weight: 600;
        }

        td {
            padding: 10px 12px;
            border-bottom: 1px solid #e0e0e0;
        }

        tr:nth-child(even) {
            background: #f8f9fa;
        }

        tr:hover {
            background: #e3f2fd;
        }

        .key-value {
            display: grid;
            grid-template-columns: 200px 1fr;
            gap: 10px;
            margin: 8px 0;
        }

        .key {
            font-weight: 600;
            color: #555;
        }

        .value {
            color: #333;
        }

        .status-good {
            color: #28a745;
            font-weight: 600;
        }

        .status-warning {
            color: #ffc107;
            font-weight: 600;
        }

        .status-bad {
            color: #dc3545;
            font-weight: 600;
        }

        .metric-card {
            display: inline-block;
            background: white;
            padding: 15px 20px;
            margin: 10px 10px 10px 0;
            border-radius: 8px;
            border: 2px solid #667eea;
            min-width: 200px;
        }

        .metric-label {
            font-size: 0.9em;
            color: #666;
            margin-bottom: 5px;
        }

        .metric-value {
            font-size: 1.8em;
            font-weight: bold;
            color: #667eea;
        }

        .footer {
            text-align: center;
            padding: 20px;
            background: #f8f9fa;
            color: #666;
            font-size: 0.9em;
        }

        .error {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 10px;
            margin: 10px 0;
            border-radius: 4px;
        }

        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }

        .collapsible {
            cursor: pointer;
            padding: 10px;
            background: #667eea;
            color: white;
            border: none;
            text-align: left;
            outline: none;
            font-size: 1.1em;
            font-weight: 600;
            border-radius: 5px;
            margin: 10px 0;
            width: 100%;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .collapsible:hover {
            background: #5568d3;
        }

        .collapsible:after {
            content: '\25BC';
            font-size: 0.8em;
        }

        .collapsible.collapsed:after {
            content: '\25B6';
        }

        .collapsible-content {
            max-height: 500px;
            overflow: auto;
            transition: max-height 0.3s ease-out;
            background: white;
            border-radius: 5px;
            margin-bottom: 15px;
        }

        .collapsible-content.collapsed {
            max-height: 0;
            overflow: hidden;
        }

        .item-count {
            background: rgba(255,255,255,0.2);
            padding: 3px 10px;
            border-radius: 15px;
            font-size: 0.9em;
            margin-left: 10px;
        }
    </style>
    <script>
        function toggleCollapsible(button) {
            button.classList.toggle('collapsed');
            var content = button.nextElementSibling;
            content.classList.toggle('collapsed');
        }

        window.onload = function() {
            // Auto-collapse large tables
            var collapsibles = document.getElementsByClassName('collapsible');
            for (var i = 0; i < collapsibles.length; i++) {
                if (collapsibles[i].hasAttribute('data-auto-collapse')) {
                    collapsibles[i].classList.add('collapsed');
                    collapsibles[i].nextElementSibling.classList.add('collapsed');
                }
            }
        };
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>System Information Report</h1>
            <p>Computer: <strong>$($env:COMPUTERNAME)</strong> | Generated: <strong>$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</strong></p>
        </div>

        <div class="content">
"@

# User Information Section
$html += @"
            <div class="section">
                <h2>User Information</h2>
"@
if ($results.UserInfo.Error) {
    $html += "<div class='error'>Error: $($results.UserInfo.Error)</div>"
} else {
    $html += @"
                <div class="key-value">
                    <div class="key">Current User:</div>
                    <div class="value">$($results.UserInfo.CurrentUser)</div>
                </div>
                <div class="key-value">
                    <div class="key">Logged On User:</div>
                    <div class="value">$($results.UserInfo.LoggedOnUser)</div>
                </div>
"@
    if ($results.UserInfo.RecentLogons) {
        $html += "<h3>Recent Logons</h3><table><tr><th>User</th><th>Last Logon</th></tr>"
        foreach ($logon in $results.UserInfo.RecentLogons) {
            $html += "<tr><td>$($logon.Name)</td><td>$($logon.LastLogon)</td></tr>"
        }
        $html += "</table>"
    }
}
$html += "</div>"

# Host Information Section
$html += @"
            <div class="section">
                <h2>Host Information</h2>
"@
if ($results.HostInfo.Error) {
    $html += "<div class='error'>Error: $($results.HostInfo.Error)</div>"
} else {
    $html += @"
                <div class="key-value">
                    <div class="key">Computer Name:</div>
                    <div class="value"><strong>$($results.HostInfo.ComputerName)</strong></div>
                </div>
                <div class="key-value">
                    <div class="key">Domain:</div>
                    <div class="value">$($results.HostInfo.Domain)</div>
                </div>
                <div class="key-value">
                    <div class="key">Manufacturer:</div>
                    <div class="value">$($results.HostInfo.Manufacturer)</div>
                </div>
                <div class="key-value">
                    <div class="key">Model:</div>
                    <div class="value">$($results.HostInfo.Model)</div>
                </div>
                <div class="key-value">
                    <div class="key">Serial Number:</div>
                    <div class="value">$($results.HostInfo.SerialNumber)</div>
                </div>
                <div class="key-value">
                    <div class="key">Operating System:</div>
                    <div class="value">$($results.HostInfo.OS)</div>
                </div>
                <div class="key-value">
                    <div class="key">OS Version:</div>
                    <div class="value">$($results.HostInfo.OSVersion) ($($results.HostInfo.OSArchitecture))</div>
                </div>
                <div class="key-value">
                    <div class="key">Install Date:</div>
                    <div class="value">$($results.HostInfo.InstallDate)</div>
                </div>
                <div class="key-value">
                    <div class="key">BIOS Version:</div>
                    <div class="value">$($results.HostInfo.BIOSVersion)</div>
                </div>
                <div class="key-value">
                    <div class="key">Total Physical Memory:</div>
                    <div class="value">$($results.HostInfo.TotalPhysicalMemory) GB</div>
                </div>
"@
}
$html += "</div>"

# Uptime & Resources Section
$html += @"
            <div class="section">
                <h2>System Resources & Uptime</h2>
"@
if ($results.UptimeResources.Error) {
    $html += "<div class='error'>Error: $($results.UptimeResources.Error)</div>"
} else {
    $html += @"
                <div class="metric-card">
                    <div class="metric-label">Uptime</div>
                    <div class="metric-value">$($results.UptimeResources.UptimeDays)d $($results.UptimeResources.UptimeHours)h $($results.UptimeResources.UptimeMinutes)m</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">CPU Load</div>
                    <div class="metric-value">$($results.UptimeResources.CPULoad)%</div>
                </div>
                <div class="metric-card">
                    <div class="metric-label">Memory Usage</div>
                    <div class="metric-value">$($results.UptimeResources.MemoryPercent)%</div>
                </div>

                <h3>CPU Information</h3>
                <div class="key-value">
                    <div class="key">Processor:</div>
                    <div class="value">$($results.UptimeResources.CPUName)</div>
                </div>
                <div class="key-value">
                    <div class="key">Cores / Logical Processors:</div>
                    <div class="value">$($results.UptimeResources.CPUCores) / $($results.UptimeResources.CPULogicalProcessors)</div>
                </div>

                <h3>Memory Information</h3>
                <div class="key-value">
                    <div class="key">Used / Total:</div>
                    <div class="value">$($results.UptimeResources.MemoryUsedGB) GB / $($results.UptimeResources.MemoryTotalGB) GB</div>
                </div>

                <h3>Disk Information</h3>
                <table>
                    <tr><th>Drive</th><th>Total Size (GB)</th><th>Free Space (GB)</th><th>Free (%)</th></tr>
"@
    foreach ($disk in $results.UptimeResources.Disks) {
        $percentClass = if ($disk.PercentFree -lt 10) { 'status-bad' } elseif ($disk.PercentFree -lt 20) { 'status-warning' } else { 'status-good' }
        $html += "<tr><td>$($disk.Drive)</td><td>$($disk.Size)</td><td>$($disk.FreeSpace)</td><td class='$percentClass'>$($disk.PercentFree)%</td></tr>"
    }
    $html += "</table>"
}
$html += "</div>"

# Network Information Section
$html += @"
            <div class="section">
                <h2>Network Information</h2>
"@
if ($results.NetworkInfo.Error) {
    $html += "<div class='error'>Error: $($results.NetworkInfo.Error)</div>"
} else {
    $html += @"
                <div class="key-value">
                    <div class="key">Public IP Address:</div>
                    <div class="value"><strong>$($results.NetworkInfo.PublicIP)</strong></div>
                </div>

                <h3>Network Adapters</h3>
                <table>
                    <tr><th>Name</th><th>Status</th><th>IPv4 Address</th><th>MAC Address</th><th>Link Speed</th><th>Gateway</th></tr>
"@
    foreach ($adapter in $results.NetworkInfo.Adapters) {
        $html += @"
                    <tr>
                        <td>$($adapter.Name)</td>
                        <td class='status-good'>$($adapter.Status)</td>
                        <td>$($adapter.IPv4Address)</td>
                        <td>$($adapter.MACAddress)</td>
                        <td>$($adapter.LinkSpeed)</td>
                        <td>$($adapter.DefaultGateway)</td>
                    </tr>
"@
    }
    $html += "</table>"
}
$html += "</div>"

# DNS Information Section
$html += @"
            <div class="section">
                <h2>DNS Information</h2>
"@
if ($results.DNSInfo.Error) {
    $html += "<div class='error'>Error: $($results.DNSInfo.Error)</div>"
} else {
    $html += "<h3>DNS Servers</h3><table><tr><th>Interface</th><th>DNS Servers</th></tr>"
    foreach ($dns in $results.DNSInfo.DNSServers) {
        $servers = $dns.ServerAddresses -join ", "
        $html += "<tr><td>$($dns.InterfaceAlias)</td><td>$servers</td></tr>"
    }
    $html += "</table>"

    if ($results.DNSInfo.DNSCache) {
        $cacheCount = ($results.DNSInfo.DNSCache | Measure-Object).Count
        $html += "<button class='collapsible' data-auto-collapse onclick='toggleCollapsible(this)'>DNS Cache <span class='item-count'>$cacheCount entries</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>Name</th><th>Type</th><th>TTL</th><th>Data</th></tr>"
        foreach ($cache in $results.DNSInfo.DNSCache) {
            $html += "<tr><td>$($cache.Name)</td><td>$($cache.Type)</td><td>$($cache.TimeToLive)</td><td>$($cache.Data)</td></tr>"
        }
        $html += "</table></div>"
    }
}
$html += "</div>"

# Firewall Information Section
$html += @"
            <div class="section">
                <h2>Firewall Information</h2>
"@
if ($results.FirewallInfo.Error) {
    $html += "<div class='error'>Error: $($results.FirewallInfo.Error)</div>"
} else {
    $html += "<h3>Firewall Profiles</h3><table><tr><th>Profile</th><th>Enabled</th><th>Inbound Action</th><th>Outbound Action</th></tr>"
    foreach ($profile in $results.FirewallInfo.Profiles) {
        $enabledClass = if ($profile.Enabled) { 'status-good' } else { 'status-bad' }
        $html += "<tr><td>$($profile.Name)</td><td class='$enabledClass'>$($profile.Enabled)</td><td>$($profile.DefaultInboundAction)</td><td>$($profile.DefaultOutboundAction)</td></tr>"
    }
    $html += "</table>"

    if ($results.FirewallInfo.ActiveRules) {
        $rulesCount = ($results.FirewallInfo.ActiveRules | Measure-Object).Count
        $html += "<button class='collapsible' data-auto-collapse onclick='toggleCollapsible(this)'>Active Firewall Rules <span class='item-count'>$rulesCount rules</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>Name</th><th>Direction</th><th>Action</th><th>Profile</th></tr>"
        foreach ($rule in $results.FirewallInfo.ActiveRules) {
            $html += "<tr><td>$($rule.DisplayName)</td><td>$($rule.Direction)</td><td>$($rule.Action)</td><td>$($rule.Profile)</td></tr>"
        }
        $html += "</table></div>"
    }
}
$html += "</div>"

# Installed Applications Section
$html += @"
            <div class="section">
                <h2>Installed Applications</h2>
"@
if ($results.InstalledApps.Error) {
    $html += "<div class='error'>Error: $($results.InstalledApps.Error)</div>"
} else {
    if ($results.InstalledApps.TraditionalApps) {
        $tradAppCount = ($results.InstalledApps.TraditionalApps | Measure-Object).Count
        $html += "<button class='collapsible' data-auto-collapse onclick='toggleCollapsible(this)'>Traditional Applications <span class='item-count'>$tradAppCount apps</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>Name</th><th>Version</th><th>Publisher</th><th>Install Date</th><th>Install Location</th></tr>"
        foreach ($app in $results.InstalledApps.TraditionalApps) {
            $html += "<tr><td>$($app.DisplayName)</td><td>$($app.DisplayVersion)</td><td>$($app.Publisher)</td><td>$($app.InstallDate)</td><td>$($app.InstallLocation)</td></tr>"
        }
        $html += "</table></div>"
    }

    if ($results.InstalledApps.ModernApps) {
        $modernAppCount = ($results.InstalledApps.ModernApps | Measure-Object).Count
        $html += "<button class='collapsible' data-auto-collapse onclick='toggleCollapsible(this)'>Modern Apps <span class='item-count'>$modernAppCount apps</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>Name</th><th>Version</th><th>Publisher</th><th>Install Location</th></tr>"
        foreach ($app in $results.InstalledApps.ModernApps) {
            $html += "<tr><td>$($app.Name)</td><td>$($app.Version)</td><td>$($app.Publisher)</td><td>$($app.InstallLocation)</td></tr>"
        }
        $html += "</table></div>"
    }
}
$html += "</div>"

# Services Section
$html += @"
            <div class="section">
                <h2>Windows Services</h2>
"@
if ($results.Services.Error) {
    $html += "<div class='error'>Error: $($results.Services.Error)</div>"
} else {
    $html += @"
                <div class="key-value">
                    <div class="key">Running Services:</div>
                    <div class="value status-good"><strong>$($results.Services.Running.Count)</strong></div>
                </div>
                <div class="key-value">
                    <div class="key">Stopped Automatic Services:</div>
                    <div class="value status-warning"><strong>$($results.Services.StoppedAutomatic.Count)</strong></div>
                </div>
"@

    if ($results.Services.Running -and $results.Services.Running.Count -gt 0) {
        $runningCount = ($results.Services.Running | Measure-Object).Count
        $html += "<button class='collapsible' data-auto-collapse onclick='toggleCollapsible(this)'>Running Services <span class='item-count'>$runningCount services</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>Name</th><th>Display Name</th><th>Status</th><th>Start Type</th></tr>"
        foreach ($service in $results.Services.Running) {
            $html += "<tr><td>$($service.Name)</td><td>$($service.DisplayName)</td><td class='status-good'>$($service.Status)</td><td>$($service.StartType)</td></tr>"
        }
        $html += "</table></div>"
    }

    if ($results.Services.StoppedAutomatic -and $results.Services.StoppedAutomatic.Count -gt 0) {
        $stoppedCount = ($results.Services.StoppedAutomatic | Measure-Object).Count
        $html += "<button class='collapsible' onclick='toggleCollapsible(this)'>Stopped Automatic Services <span class='item-count'>$stoppedCount services</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>Name</th><th>Display Name</th><th>Status</th><th>Start Type</th></tr>"
        foreach ($service in $results.Services.StoppedAutomatic) {
            $html += "<tr><td>$($service.Name)</td><td>$($service.DisplayName)</td><td class='status-warning'>$($service.Status)</td><td>$($service.StartType)</td></tr>"
        }
        $html += "</table></div>"
    }
}
$html += "</div>"

# Event Logs Section
$html += @"
            <div class="section">
                <h2>Event Viewer Logs</h2>
"@
if ($results.EventLogs.Error) {
    $html += "<div class='error'>Error: $($results.EventLogs.Error)</div>"
} else {
    if ($results.EventLogs.SystemErrors) {
        $sysErrorCount = ($results.EventLogs.SystemErrors | Measure-Object).Count
        $html += "<button class='collapsible' data-auto-collapse onclick='toggleCollapsible(this)'>System Errors <span class='item-count'>$sysErrorCount events</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>Time</th><th>Source</th><th>Event ID</th><th>Message</th></tr>"
        foreach ($event in $results.EventLogs.SystemErrors) {
            $msg = $event.Message -replace "`r`n", " " -replace "`n", " "
            if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) + "..." }
            $html += "<tr><td>$($event.TimeGenerated)</td><td>$($event.Source)</td><td>$($event.EventID)</td><td>$msg</td></tr>"
        }
        $html += "</table></div>"
    }

    if ($results.EventLogs.ApplicationErrors) {
        $appErrorCount = ($results.EventLogs.ApplicationErrors | Measure-Object).Count
        $html += "<button class='collapsible' data-auto-collapse onclick='toggleCollapsible(this)'>Application Errors <span class='item-count'>$appErrorCount events</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>Time</th><th>Source</th><th>Event ID</th><th>Message</th></tr>"
        foreach ($event in $results.EventLogs.ApplicationErrors) {
            $msg = $event.Message -replace "`r`n", " " -replace "`n", " "
            if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) + "..." }
            $html += "<tr><td>$($event.TimeGenerated)</td><td>$($event.Source)</td><td>$($event.EventID)</td><td>$msg</td></tr>"
        }
        $html += "</table></div>"
    }

    if ($results.EventLogs.SecurityAudits) {
        $secAuditCount = ($results.EventLogs.SecurityAudits | Measure-Object).Count
        $html += "<button class='collapsible' data-auto-collapse onclick='toggleCollapsible(this)'>Security Audits <span class='item-count'>$secAuditCount events</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>Time</th><th>Source</th><th>Event ID</th><th>Message</th></tr>"
        foreach ($event in $results.EventLogs.SecurityAudits) {
            $msg = $event.Message -replace "`r`n", " " -replace "`n", " "
            if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) + "..." }
            $html += "<tr><td>$($event.TimeGenerated)</td><td>$($event.Source)</td><td>$($event.EventID)</td><td>$msg</td></tr>"
        }
        $html += "</table></div>"
    }
}
$html += "</div>"

# Windows Update Section
$html += @"
            <div class="section">
                <h2>Windows Update Status</h2>
"@
if ($results.WindowsUpdate.Error) {
    $html += "<div class='error'>Error: $($results.WindowsUpdate.Error)</div>"
} else {
    $pendingClass = if ($results.WindowsUpdate.PendingCount -gt 0) { 'status-warning' } else { 'status-good' }
    $html += @"
                <div class="key-value">
                    <div class="key">Pending Updates:</div>
                    <div class="value $pendingClass"><strong>$($results.WindowsUpdate.PendingCount)</strong></div>
                </div>
"@

    if ($results.WindowsUpdate.PendingUpdates -and $results.WindowsUpdate.PendingCount -gt 0) {
        $html += "<button class='collapsible' onclick='toggleCollapsible(this)'>Pending Updates <span class='item-count'>$($results.WindowsUpdate.PendingCount) updates</span></button>"
        $html += "<div class='collapsible-content'><ul>"
        foreach ($update in $results.WindowsUpdate.PendingUpdates) {
            $html += "<li>$update</li>"
        }
        $html += "</ul></div>"
    }

    if ($results.WindowsUpdate.RecentHotfixes) {
        $hotfixCount = ($results.WindowsUpdate.RecentHotfixes | Measure-Object).Count
        $html += "<button class='collapsible' data-auto-collapse onclick='toggleCollapsible(this)'>Installed Hotfixes <span class='item-count'>$hotfixCount hotfixes</span></button>"
        $html += "<div class='collapsible-content'><table><tr><th>HotFix ID</th><th>Description</th><th>Installed By</th><th>Installed On</th></tr>"
        foreach ($hotfix in $results.WindowsUpdate.RecentHotfixes) {
            $html += "<tr><td>$($hotfix.HotFixID)</td><td>$($hotfix.Description)</td><td>$($hotfix.InstalledBy)</td><td>$($hotfix.InstalledOn)</td></tr>"
        }
        $html += "</table></div>"
    }
}
$html += "</div>"

# Footer
$html += @"
        </div>

        <div class="footer">
            <p>Report generated by PowerShell System Information Collector</p>
            <p>Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") | Computer: $($env:COMPUTERNAME)</p>
        </div>
    </div>
</body>
</html>
"@

# Save HTML report
try {
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "`n[SUCCESS] Report generated successfully!" -ForegroundColor Green
    Write-Host "[INFO] Location: $OutputPath" -ForegroundColor Cyan
    Write-Host "`nOpening report in default browser..." -ForegroundColor Yellow
    Start-Process $OutputPath
} catch {
    Write-Host "`n[ERROR] Error saving report: $($_.Exception.Message)" -ForegroundColor Red
}
