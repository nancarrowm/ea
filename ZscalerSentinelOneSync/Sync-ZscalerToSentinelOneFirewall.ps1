<#
.SYNOPSIS
    Synchronizes Zscaler IP ranges to SentinelOne Firewall Control policies.

.DESCRIPTION
    This script downloads IP ranges from Zscaler configuration APIs, aggregates them,
    and creates/updates firewall rules in SentinelOne Firewall Control. It supports
    both IPv4 and IPv6 ranges and creates rules for TCP/443 and UDP/443.

    The script maintains a local cache to detect changes and only applies updates
    when new IP ranges are discovered.

.PARAMETER SentinelOneApiUrl
    The base URL for your SentinelOne Management Console API (e.g., https://usea1-partners.sentinelone.net)

.PARAMETER SentinelOneApiToken
    API token for SentinelOne authentication

.PARAMETER ScopeType
    The scope type for firewall rules: 'site', 'group', 'account', or 'tenant'

.PARAMETER ScopeId
    The ID of the scope (site ID, group ID, or account ID). Not required for tenant scope.

.PARAMETER CacheFilePath
    Path to the cache file for tracking IP range changes. Defaults to script directory.

.PARAMETER LogFilePath
    Path to the log file. Defaults to script directory.

.PARAMETER RuleNamePrefix
    Prefix for firewall rule names. Defaults to "Zscaler-AutoManaged"

.PARAMETER DryRun
    If specified, shows what changes would be made without actually applying them.

.PARAMETER Force
    If specified, bypasses cache check and forces full synchronization.

.EXAMPLE
    ./Sync-ZscalerToSentinelOneFirewall.ps1 -SentinelOneApiUrl "https://usea1.sentinelone.net" -SentinelOneApiToken "your-api-token" -ScopeType "site" -ScopeId "123456789"

.EXAMPLE
    ./Sync-ZscalerToSentinelOneFirewall.ps1 -SentinelOneApiUrl "https://usea1.sentinelone.net" -SentinelOneApiToken "your-api-token" -ScopeType "tenant" -DryRun

.NOTES
    Author: Auto-generated
    Requires: PowerShell 7.0+ (for cross-platform compatibility)

    Zscaler API Endpoints:
    - Hub IPs: https://config.zscaler.com/api/zscaler.net/hubs/cidr/json/required
    - Aggregate IPs: https://config.zscaler.com/api/zscaler.net/future/json
    - ZEN IPs: https://config.zscaler.com/api/zscaler.net/cenr/json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SentinelOneApiUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$SentinelOneApiToken,

    [Parameter(Mandatory = $true)]
    [ValidateSet('site', 'group', 'account', 'tenant')]
    [string]$ScopeType,

    [Parameter(Mandatory = $false)]
    [string]$ScopeId,

    [Parameter(Mandatory = $false)]
    [string]$CacheFilePath,

    [Parameter(Mandatory = $false)]
    [string]$LogFilePath,

    [Parameter(Mandatory = $false)]
    [string]$RuleNamePrefix = "Zscaler-AutoManaged",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

#region Configuration
$script:Config = @{
    ZscalerEndpoints = @{
        HubIPs      = "https://config.zscaler.com/api/zscaler.net/hubs/cidr/json/required"
        AggregateIPs = "https://config.zscaler.com/api/zscaler.net/future/json"
        ZenIPs      = "https://config.zscaler.com/api/zscaler.net/cenr/json"
    }
    SentinelOneApiVersion = "v2.1"
    RetryCount = 3
    RetryDelaySeconds = 5
    HttpTimeoutSeconds = 30
}

# Set default paths if not provided
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $CacheFilePath) {
    $CacheFilePath = Join-Path $ScriptDir "zscaler-sentinelone-cache.json"
}
if (-not $LogFilePath) {
    $LogFilePath = Join-Path $ScriptDir "zscaler-sentinelone-sync.log"
}
#endregion

#region Logging Functions
function Write-Log {
    <#
    .SYNOPSIS
        Writes a log message to both console and log file with timestamp and severity.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"

    # Console output with color
    $Color = switch ($Level) {
        'INFO'    { 'White' }
        'WARNING' { 'Yellow' }
        'ERROR'   { 'Red' }
        'DEBUG'   { 'Gray' }
        'SUCCESS' { 'Green' }
        default   { 'White' }
    }

    Write-Host $LogEntry -ForegroundColor $Color

    # File output
    try {
        Add-Content -Path $LogFilePath -Value $LogEntry -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "[$Timestamp] [WARNING] Could not write to log file: $_" -ForegroundColor Yellow
    }
}

function Write-LogSection {
    <#
    .SYNOPSIS
        Writes a section header to the log for better readability.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    $Separator = "=" * 60
    Write-Log $Separator -Level INFO
    Write-Log $Title -Level INFO
    Write-Log $Separator -Level INFO
}
#endregion

#region HTTP Helper Functions
function Invoke-WebRequestWithRetry {
    <#
    .SYNOPSIS
        Makes HTTP requests with retry logic and exponential backoff.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $false)]
        [string]$Method = 'GET',

        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = @{},

        [Parameter(Mandatory = $false)]
        [object]$Body,

        [Parameter(Mandatory = $false)]
        [string]$ContentType = 'application/json'
    )

    $RetryCount = $script:Config.RetryCount
    $BaseDelay = $script:Config.RetryDelaySeconds

    for ($i = 1; $i -le $RetryCount; $i++) {
        try {
            Write-Log "HTTP $Method request to $Uri (attempt $i/$RetryCount)" -Level DEBUG

            $RequestParams = @{
                Uri             = $Uri
                Method          = $Method
                Headers         = $Headers
                ContentType     = $ContentType
                TimeoutSec      = $script:Config.HttpTimeoutSeconds
                UseBasicParsing = $true
            }

            if ($Body) {
                if ($Body -is [hashtable] -or $Body -is [PSCustomObject]) {
                    $RequestParams['Body'] = ($Body | ConvertTo-Json -Depth 10 -Compress)
                }
                else {
                    $RequestParams['Body'] = $Body
                }
            }

            $Response = Invoke-RestMethod @RequestParams
            Write-Log "HTTP request successful" -Level DEBUG
            return $Response
        }
        catch {
            $ErrorMsg = $_.Exception.Message
            Write-Log "HTTP request failed (attempt $i/$RetryCount): $ErrorMsg" -Level WARNING

            if ($i -lt $RetryCount) {
                $Delay = $BaseDelay * [Math]::Pow(2, $i - 1)
                Write-Log "Retrying in $Delay seconds..." -Level DEBUG
                Start-Sleep -Seconds $Delay
            }
            else {
                throw "HTTP request failed after $RetryCount attempts: $ErrorMsg"
            }
        }
    }
}
#endregion

#region Zscaler Data Functions
function Get-ZscalerIpRanges {
    <#
    .SYNOPSIS
        Downloads and parses IP ranges from all Zscaler API endpoints.
    .OUTPUTS
        PSCustomObject with IPv4 and IPv6 arrays containing unique CIDR ranges.
    #>
    [CmdletBinding()]
    param()

    Write-LogSection "Fetching Zscaler IP Ranges"

    $AllIPv4Ranges = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $AllIPv6Ranges = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    foreach ($EndpointName in $script:Config.ZscalerEndpoints.Keys) {
        $Url = $script:Config.ZscalerEndpoints[$EndpointName]
        Write-Log "Fetching $EndpointName from: $Url" -Level INFO

        try {
            $Response = Invoke-WebRequestWithRetry -Uri $Url -Method GET
            $ParsedRanges = ConvertFrom-ZscalerResponse -Response $Response -EndpointName $EndpointName

            foreach ($Range in $ParsedRanges.IPv4) {
                [void]$AllIPv4Ranges.Add($Range)
            }
            foreach ($Range in $ParsedRanges.IPv6) {
                [void]$AllIPv6Ranges.Add($Range)
            }

            Write-Log "Retrieved $($ParsedRanges.IPv4.Count) IPv4 and $($ParsedRanges.IPv6.Count) IPv6 ranges from $EndpointName" -Level SUCCESS
        }
        catch {
            Write-Log "Failed to fetch $EndpointName : $_" -Level ERROR
            # Continue with other endpoints even if one fails
        }
    }

    $Result = [PSCustomObject]@{
        IPv4 = @($AllIPv4Ranges | Sort-Object)
        IPv6 = @($AllIPv6Ranges | Sort-Object)
        TotalCount = $AllIPv4Ranges.Count + $AllIPv6Ranges.Count
        FetchedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    Write-Log "Total unique IP ranges: $($Result.IPv4.Count) IPv4, $($Result.IPv6.Count) IPv6" -Level INFO
    return $Result
}

function ConvertFrom-ZscalerResponse {
    <#
    .SYNOPSIS
        Parses Zscaler API response and extracts IP ranges.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Response,

        [Parameter(Mandatory = $true)]
        [string]$EndpointName
    )

    $IPv4Ranges = [System.Collections.Generic.List[string]]::new()
    $IPv6Ranges = [System.Collections.Generic.List[string]]::new()

    # Handle different response formats from different endpoints
    $RawRanges = @()

    # Try to extract IP ranges from various possible response structures
    if ($Response -is [array]) {
        $RawRanges = $Response
    }
    elseif ($Response.hubPrefixes) {
        # Hub IPs endpoint format
        $RawRanges += $Response.hubPrefixes
    }
    elseif ($Response.prefixes) {
        # Aggregate IPs format
        foreach ($Prefix in $Response.prefixes) {
            if ($Prefix.ip_prefix) {
                $RawRanges += $Prefix.ip_prefix
            }
            elseif ($Prefix.ipv6_prefix) {
                $RawRanges += $Prefix.ipv6_prefix
            }
            elseif ($Prefix -is [string]) {
                $RawRanges += $Prefix
            }
        }
    }
    elseif ($Response.data) {
        # CENR endpoint format - more complex nested structure
        $RawRanges = Get-NestedIpRanges -Data $Response.data
    }
    elseif ($Response.ipAddresses) {
        $RawRanges = $Response.ipAddresses
    }
    elseif ($Response.ranges) {
        $RawRanges = $Response.ranges
    }
    elseif ($Response.cidrs) {
        $RawRanges = $Response.cidrs
    }
    elseif ($Response.required) {
        # Hub IPs required format
        $RawRanges = $Response.required
    }
    else {
        # Try to find any array properties that might contain IP ranges
        $Response.PSObject.Properties | ForEach-Object {
            if ($_.Value -is [array]) {
                $RawRanges += $_.Value
            }
        }
    }

    # Process and categorize each range
    foreach ($Range in $RawRanges) {
        $IpRange = $null

        if ($Range -is [string]) {
            $IpRange = $Range.Trim()
        }
        elseif ($Range.cidr) {
            $IpRange = $Range.cidr.Trim()
        }
        elseif ($Range.ip_prefix) {
            $IpRange = $Range.ip_prefix.Trim()
        }
        elseif ($Range.ipv6_prefix) {
            $IpRange = $Range.ipv6_prefix.Trim()
        }
        elseif ($Range.range) {
            $IpRange = $Range.range.Trim()
        }
        elseif ($Range.prefix) {
            $IpRange = $Range.prefix.Trim()
        }

        if ($IpRange -and (Test-ValidCidr -Cidr $IpRange)) {
            if ($IpRange -match ':') {
                # IPv6 address
                $IPv6Ranges.Add($IpRange)
            }
            else {
                # IPv4 address
                $IPv4Ranges.Add($IpRange)
            }
        }
    }

    return [PSCustomObject]@{
        IPv4 = $IPv4Ranges
        IPv6 = $IPv6Ranges
    }
}

function Get-NestedIpRanges {
    <#
    .SYNOPSIS
        Recursively extracts IP ranges from nested Zscaler CENR response data.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Data
    )

    $Ranges = [System.Collections.Generic.List[string]]::new()

    function Extract-Recursive {
        param([object]$Obj)

        if ($null -eq $Obj) { return }

        if ($Obj -is [string]) {
            if (Test-ValidCidr -Cidr $Obj) {
                $Ranges.Add($Obj)
            }
            return
        }

        if ($Obj -is [array]) {
            foreach ($Item in $Obj) {
                Extract-Recursive -Obj $Item
            }
            return
        }

        if ($Obj -is [PSCustomObject] -or $Obj -is [hashtable]) {
            # Check for common IP-related property names
            $IpProperties = @('ip', 'cidr', 'range', 'prefix', 'ip_prefix', 'ipv6_prefix', 'ipAddress', 'address', 'vpnAddress', 'greRange')

            foreach ($PropName in $IpProperties) {
                $Value = $null
                if ($Obj -is [hashtable] -and $Obj.ContainsKey($PropName)) {
                    $Value = $Obj[$PropName]
                }
                elseif ($Obj.PSObject.Properties[$PropName]) {
                    $Value = $Obj.$PropName
                }

                if ($Value -is [string] -and (Test-ValidCidr -Cidr $Value)) {
                    $Ranges.Add($Value)
                }
            }

            # Recurse into all properties
            if ($Obj -is [hashtable]) {
                foreach ($Key in $Obj.Keys) {
                    Extract-Recursive -Obj $Obj[$Key]
                }
            }
            else {
                foreach ($Prop in $Obj.PSObject.Properties) {
                    Extract-Recursive -Obj $Prop.Value
                }
            }
        }
    }

    Extract-Recursive -Obj $Data
    return $Ranges.ToArray()
}

function Test-ValidCidr {
    <#
    .SYNOPSIS
        Validates if a string is a valid CIDR notation (IPv4 or IPv6).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Cidr
    )

    if ([string]::IsNullOrWhiteSpace($Cidr)) {
        return $false
    }

    # IPv4 CIDR pattern: x.x.x.x/n
    $IPv4Pattern = '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(\/\d{1,2})?$'

    # IPv6 CIDR pattern: supports various IPv6 formats with optional prefix length
    $IPv6Pattern = '^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}(\/\d{1,3})?$|^([0-9a-fA-F]{0,4}:){1,6}:[0-9a-fA-F]{0,4}(\/\d{1,3})?$|^::([0-9a-fA-F]{0,4}:){0,5}[0-9a-fA-F]{0,4}(\/\d{1,3})?$|^[0-9a-fA-F]{0,4}::([0-9a-fA-F]{0,4}:){0,4}[0-9a-fA-F]{0,4}(\/\d{1,3})?$'

    return ($Cidr -match $IPv4Pattern) -or ($Cidr -match $IPv6Pattern)
}
#endregion

#region Cache Functions
function Get-CachedState {
    <#
    .SYNOPSIS
        Reads the cached state of previously synced IP ranges.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Checking cache file: $CacheFilePath" -Level DEBUG

    if (Test-Path $CacheFilePath) {
        try {
            $CacheContent = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
            Write-Log "Cache loaded successfully. Last sync: $($CacheContent.LastSync)" -Level INFO
            return $CacheContent
        }
        catch {
            Write-Log "Failed to read cache file: $_" -Level WARNING
            return $null
        }
    }
    else {
        Write-Log "No cache file found. Will perform full sync." -Level INFO
        return $null
    }
}

function Save-CacheState {
    <#
    .SYNOPSIS
        Saves the current state to cache file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$IpRanges,

        [Parameter(Mandatory = $true)]
        [array]$SyncedRules
    )

    $CacheState = [PSCustomObject]@{
        LastSync    = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        IPv4Ranges  = $IpRanges.IPv4
        IPv6Ranges  = $IpRanges.IPv6
        TotalCount  = $IpRanges.TotalCount
        SyncedRules = $SyncedRules
        Version     = "1.0"
    }

    try {
        $CacheState | ConvertTo-Json -Depth 10 | Set-Content $CacheFilePath -Force
        Write-Log "Cache saved successfully to: $CacheFilePath" -Level SUCCESS
    }
    catch {
        Write-Log "Failed to save cache: $_" -Level ERROR
    }
}

function Compare-IpRanges {
    <#
    .SYNOPSIS
        Compares current IP ranges with cached ranges to find additions and removals.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CurrentRanges,

        [Parameter(Mandatory = $false)]
        [object]$CachedState
    )

    Write-LogSection "Comparing IP Ranges with Cache"

    if ($null -eq $CachedState) {
        Write-Log "No cached state. All ranges are new." -Level INFO
        return [PSCustomObject]@{
            HasChanges = $true
            NewIPv4    = $CurrentRanges.IPv4
            NewIPv6    = $CurrentRanges.IPv6
            RemovedIPv4 = @()
            RemovedIPv6 = @()
            UnchangedIPv4 = @()
            UnchangedIPv6 = @()
        }
    }

    $CachedIPv4 = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $CachedIPv6 = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

    if ($CachedState.IPv4Ranges) {
        foreach ($Range in $CachedState.IPv4Ranges) {
            [void]$CachedIPv4.Add($Range)
        }
    }
    if ($CachedState.IPv6Ranges) {
        foreach ($Range in $CachedState.IPv6Ranges) {
            [void]$CachedIPv6.Add($Range)
        }
    }

    # Find new ranges (in current but not in cache)
    $NewIPv4 = @($CurrentRanges.IPv4 | Where-Object { -not $CachedIPv4.Contains($_) })
    $NewIPv6 = @($CurrentRanges.IPv6 | Where-Object { -not $CachedIPv6.Contains($_) })

    # Find removed ranges (in cache but not in current)
    $CurrentIPv4Set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $CurrentIPv6Set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($Range in $CurrentRanges.IPv4) { [void]$CurrentIPv4Set.Add($Range) }
    foreach ($Range in $CurrentRanges.IPv6) { [void]$CurrentIPv6Set.Add($Range) }

    $RemovedIPv4 = @($CachedIPv4 | Where-Object { -not $CurrentIPv4Set.Contains($_) })
    $RemovedIPv6 = @($CachedIPv6 | Where-Object { -not $CurrentIPv6Set.Contains($_) })

    # Find unchanged ranges
    $UnchangedIPv4 = @($CurrentRanges.IPv4 | Where-Object { $CachedIPv4.Contains($_) })
    $UnchangedIPv6 = @($CurrentRanges.IPv6 | Where-Object { $CachedIPv6.Contains($_) })

    $HasChanges = ($NewIPv4.Count -gt 0) -or ($NewIPv6.Count -gt 0) -or ($RemovedIPv4.Count -gt 0) -or ($RemovedIPv6.Count -gt 0)

    Write-Log "Comparison results:" -Level INFO
    Write-Log "  New IPv4 ranges: $($NewIPv4.Count)" -Level $(if ($NewIPv4.Count -gt 0) { 'WARNING' } else { 'INFO' })
    Write-Log "  New IPv6 ranges: $($NewIPv6.Count)" -Level $(if ($NewIPv6.Count -gt 0) { 'WARNING' } else { 'INFO' })
    Write-Log "  Removed IPv4 ranges: $($RemovedIPv4.Count)" -Level $(if ($RemovedIPv4.Count -gt 0) { 'WARNING' } else { 'INFO' })
    Write-Log "  Removed IPv6 ranges: $($RemovedIPv6.Count)" -Level $(if ($RemovedIPv6.Count -gt 0) { 'WARNING' } else { 'INFO' })
    Write-Log "  Unchanged IPv4 ranges: $($UnchangedIPv4.Count)" -Level INFO
    Write-Log "  Unchanged IPv6 ranges: $($UnchangedIPv6.Count)" -Level INFO

    if ($NewIPv4.Count -gt 0) {
        Write-Log "New IPv4 ranges:" -Level DEBUG
        foreach ($Range in $NewIPv4) {
            Write-Log "  + $Range" -Level DEBUG
        }
    }

    if ($NewIPv6.Count -gt 0) {
        Write-Log "New IPv6 ranges:" -Level DEBUG
        foreach ($Range in $NewIPv6) {
            Write-Log "  + $Range" -Level DEBUG
        }
    }

    return [PSCustomObject]@{
        HasChanges    = $HasChanges
        NewIPv4       = $NewIPv4
        NewIPv6       = $NewIPv6
        RemovedIPv4   = $RemovedIPv4
        RemovedIPv6   = $RemovedIPv6
        UnchangedIPv4 = $UnchangedIPv4
        UnchangedIPv6 = $UnchangedIPv6
    }
}
#endregion

#region SentinelOne API Functions
function Get-SentinelOneHeaders {
    <#
    .SYNOPSIS
        Returns the headers required for SentinelOne API requests.
    #>
    return @{
        'Authorization' = "ApiToken $SentinelOneApiToken"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
    }
}

function Get-SentinelOneApiBaseUrl {
    <#
    .SYNOPSIS
        Constructs the base API URL for SentinelOne.
    #>
    $BaseUrl = $SentinelOneApiUrl.TrimEnd('/')
    return "$BaseUrl/web/api/$($script:Config.SentinelOneApiVersion)"
}

function Get-ExistingSentinelOneFirewallRules {
    <#
    .SYNOPSIS
        Retrieves existing firewall rules from SentinelOne that match our naming convention.
    #>
    [CmdletBinding()]
    param()

    Write-Log "Fetching existing SentinelOne firewall rules..." -Level INFO

    $BaseUrl = Get-SentinelOneApiBaseUrl
    $Headers = Get-SentinelOneHeaders

    # Build query parameters based on scope
    $QueryParams = @{
        'limit' = 1000
    }

    switch ($ScopeType) {
        'site'    { $QueryParams['siteIds'] = $ScopeId }
        'group'   { $QueryParams['groupIds'] = $ScopeId }
        'account' { $QueryParams['accountIds'] = $ScopeId }
        'tenant'  { $QueryParams['tenant'] = 'true' }
    }

    $QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&'
    $Url = "$BaseUrl/firewall-control?$QueryString"

    try {
        $Response = Invoke-WebRequestWithRetry -Uri $Url -Method GET -Headers $Headers
        $ExistingRules = @()

        if ($Response.data) {
            $ExistingRules = @($Response.data | Where-Object { $_.name -like "$RuleNamePrefix*" })
        }

        Write-Log "Found $($ExistingRules.Count) existing rules matching prefix '$RuleNamePrefix'" -Level INFO
        return $ExistingRules
    }
    catch {
        Write-Log "Failed to fetch existing firewall rules: $_" -Level ERROR
        throw
    }
}

function New-SentinelOneFirewallRule {
    <#
    .SYNOPSIS
        Creates a new firewall rule in SentinelOne.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$RemoteHost,

        [Parameter(Mandatory = $true)]
        [ValidateSet('TCP', 'UDP')]
        [string]$Protocol,

        [Parameter(Mandatory = $true)]
        [int]$RemotePort,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Allow', 'Block')]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$Description = "",

        [Parameter(Mandatory = $true)]
        [ValidateSet('IPv4', 'IPv6')]
        [string]$IpVersion
    )

    $BaseUrl = Get-SentinelOneApiBaseUrl
    $Headers = Get-SentinelOneHeaders

    # Determine OS types (Windows, macOS, Linux)
    $OsTypes = @("windows", "macos", "linux")

    # Build the rule payload
    $RuleData = @{
        data = @{
            name          = $Name
            description   = $Description
            action        = $Action.ToLower()
            direction     = "out"
            protocol      = $Protocol.ToLower()
            remoteHost    = $RemoteHost
            remotePort    = @{
                from = $RemotePort
                to   = $RemotePort
            }
            osTypes       = $OsTypes
            status        = "Enabled"
        }
        filter = @{}
    }

    # Add scope to filter
    switch ($ScopeType) {
        'site'    { $RuleData.filter['siteIds'] = @($ScopeId) }
        'group'   { $RuleData.filter['groupIds'] = @($ScopeId) }
        'account' { $RuleData.filter['accountIds'] = @($ScopeId) }
        'tenant'  { $RuleData.filter['tenant'] = $true }
    }

    $Url = "$BaseUrl/firewall-control"

    if ($DryRun) {
        Write-Log "[DRY RUN] Would create rule: $Name ($Protocol/$RemotePort -> $RemoteHost)" -Level WARNING
        return @{
            id   = "dry-run-$([guid]::NewGuid().ToString().Substring(0,8))"
            name = $Name
            dryRun = $true
        }
    }

    try {
        Write-Log "Creating firewall rule: $Name" -Level DEBUG
        $Response = Invoke-WebRequestWithRetry -Uri $Url -Method POST -Headers $Headers -Body $RuleData

        if ($Response.data) {
            Write-Log "Successfully created rule: $Name (ID: $($Response.data.id))" -Level SUCCESS
            return $Response.data
        }
        else {
            Write-Log "Rule created but no data returned: $Name" -Level WARNING
            return @{ name = $Name }
        }
    }
    catch {
        Write-Log "Failed to create firewall rule '$Name': $_" -Level ERROR
        throw
    }
}

function Remove-SentinelOneFirewallRule {
    <#
    .SYNOPSIS
        Removes a firewall rule from SentinelOne.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuleId,

        [Parameter(Mandatory = $false)]
        [string]$RuleName = ""
    )

    $BaseUrl = Get-SentinelOneApiBaseUrl
    $Headers = Get-SentinelOneHeaders

    $DeleteBody = @{
        filter = @{
            ids = @($RuleId)
        }
    }

    $Url = "$BaseUrl/firewall-control"

    if ($DryRun) {
        Write-Log "[DRY RUN] Would delete rule: $RuleName (ID: $RuleId)" -Level WARNING
        return $true
    }

    try {
        Write-Log "Deleting firewall rule: $RuleName (ID: $RuleId)" -Level DEBUG
        $Response = Invoke-WebRequestWithRetry -Uri $Url -Method DELETE -Headers $Headers -Body $DeleteBody
        Write-Log "Successfully deleted rule: $RuleName" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to delete firewall rule '$RuleName' (ID: $RuleId): $_" -Level ERROR
        return $false
    }
}

function Sync-FirewallRules {
    <#
    .SYNOPSIS
        Synchronizes firewall rules based on IP range changes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$CurrentRanges,

        [Parameter(Mandatory = $true)]
        [object]$ChangeSet
    )

    Write-LogSection "Synchronizing SentinelOne Firewall Rules"

    $SyncedRules = @()
    $ErrorCount = 0

    # Get existing rules to avoid duplicates and for removal
    $ExistingRules = @{}
    try {
        $Rules = Get-ExistingSentinelOneFirewallRules
        foreach ($Rule in $Rules) {
            $ExistingRules[$Rule.name] = $Rule
        }
    }
    catch {
        Write-Log "Could not fetch existing rules, proceeding with caution: $_" -Level WARNING
    }

    # Create rules for new IP ranges
    $AllNewRanges = @()

    foreach ($Range in $ChangeSet.NewIPv4) {
        $AllNewRanges += @{
            Range     = $Range
            IpVersion = 'IPv4'
        }
    }

    foreach ($Range in $ChangeSet.NewIPv6) {
        $AllNewRanges += @{
            Range     = $Range
            IpVersion = 'IPv6'
        }
    }

    if ($AllNewRanges.Count -eq 0 -and $ChangeSet.RemovedIPv4.Count -eq 0 -and $ChangeSet.RemovedIPv6.Count -eq 0) {
        Write-Log "No changes to apply." -Level SUCCESS
        return @()
    }

    Write-Log "Processing $($AllNewRanges.Count) new IP ranges..." -Level INFO

    $Protocols = @('TCP', 'UDP')
    $Port = 443

    $TotalOperations = $AllNewRanges.Count * $Protocols.Count
    $CurrentOperation = 0

    foreach ($RangeInfo in $AllNewRanges) {
        $Range = $RangeInfo.Range
        $IpVersion = $RangeInfo.IpVersion

        foreach ($Protocol in $Protocols) {
            $CurrentOperation++
            $Progress = [math]::Round(($CurrentOperation / $TotalOperations) * 100, 1)

            # Generate rule name (sanitize CIDR for name)
            $SanitizedRange = $Range -replace '[/:]', '-'
            $RuleName = "$RuleNamePrefix-$IpVersion-$Protocol-$Port-$SanitizedRange"

            # Truncate if too long (SentinelOne has name limits)
            if ($RuleName.Length -gt 100) {
                $Hash = [System.BitConverter]::ToString([System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Range))).Replace('-','').Substring(0,8)
                $RuleName = "$RuleNamePrefix-$IpVersion-$Protocol-$Port-$Hash"
            }

            # Skip if rule already exists
            if ($ExistingRules.ContainsKey($RuleName)) {
                Write-Log "Rule already exists, skipping: $RuleName" -Level DEBUG
                $SyncedRules += @{
                    Name   = $RuleName
                    Range  = $Range
                    Status = 'Existing'
                }
                continue
            }

            Write-Log "[$Progress%] Creating rule for $Range ($Protocol/$Port)..." -Level INFO

            try {
                $Description = "Auto-managed Zscaler $IpVersion rule for $Range - Created $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

                $Rule = New-SentinelOneFirewallRule `
                    -Name $RuleName `
                    -RemoteHost $Range `
                    -Protocol $Protocol `
                    -RemotePort $Port `
                    -Action 'Allow' `
                    -Description $Description `
                    -IpVersion $IpVersion

                $SyncedRules += @{
                    Name   = $RuleName
                    Id     = $Rule.id
                    Range  = $Range
                    Protocol = $Protocol
                    Status = 'Created'
                }
            }
            catch {
                Write-Log "Failed to create rule for $Range : $_" -Level ERROR
                $ErrorCount++
                $SyncedRules += @{
                    Name   = $RuleName
                    Range  = $Range
                    Protocol = $Protocol
                    Status = 'Failed'
                    Error  = $_.ToString()
                }
            }
        }
    }

    # Handle removed IP ranges - delete corresponding rules
    $AllRemovedRanges = @()
    foreach ($Range in $ChangeSet.RemovedIPv4) {
        $AllRemovedRanges += @{ Range = $Range; IpVersion = 'IPv4' }
    }
    foreach ($Range in $ChangeSet.RemovedIPv6) {
        $AllRemovedRanges += @{ Range = $Range; IpVersion = 'IPv6' }
    }

    if ($AllRemovedRanges.Count -gt 0) {
        Write-Log "Processing $($AllRemovedRanges.Count) removed IP ranges..." -Level INFO

        foreach ($RangeInfo in $AllRemovedRanges) {
            $Range = $RangeInfo.Range
            $IpVersion = $RangeInfo.IpVersion

            foreach ($Protocol in $Protocols) {
                $SanitizedRange = $Range -replace '[/:]', '-'
                $RuleName = "$RuleNamePrefix-$IpVersion-$Protocol-$Port-$SanitizedRange"

                if ($RuleName.Length -gt 100) {
                    $Hash = [System.BitConverter]::ToString([System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Range))).Replace('-','').Substring(0,8)
                    $RuleName = "$RuleNamePrefix-$IpVersion-$Protocol-$Port-$Hash"
                }

                if ($ExistingRules.ContainsKey($RuleName)) {
                    $RuleId = $ExistingRules[$RuleName].id
                    $Result = Remove-SentinelOneFirewallRule -RuleId $RuleId -RuleName $RuleName

                    $SyncedRules += @{
                        Name   = $RuleName
                        Range  = $Range
                        Protocol = $Protocol
                        Status = if ($Result) { 'Deleted' } else { 'DeleteFailed' }
                    }
                }
            }
        }
    }

    # Summary
    Write-LogSection "Sync Summary"
    $Created = @($SyncedRules | Where-Object { $_.Status -eq 'Created' }).Count
    $Existing = @($SyncedRules | Where-Object { $_.Status -eq 'Existing' }).Count
    $Deleted = @($SyncedRules | Where-Object { $_.Status -eq 'Deleted' }).Count
    $Failed = @($SyncedRules | Where-Object { $_.Status -like '*Failed*' }).Count

    Write-Log "Rules created: $Created" -Level $(if ($Created -gt 0) { 'SUCCESS' } else { 'INFO' })
    Write-Log "Rules already existing: $Existing" -Level INFO
    Write-Log "Rules deleted: $Deleted" -Level $(if ($Deleted -gt 0) { 'WARNING' } else { 'INFO' })
    Write-Log "Rules failed: $Failed" -Level $(if ($Failed -gt 0) { 'ERROR' } else { 'INFO' })

    return $SyncedRules
}
#endregion

#region Main Execution
function Main {
    <#
    .SYNOPSIS
        Main execution function.
    #>

    $StartTime = Get-Date

    Write-LogSection "Zscaler to SentinelOne Firewall Sync"
    Write-Log "Script started at: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Level INFO
    Write-Log "PowerShell Version: $($PSVersionTable.PSVersion)" -Level DEBUG
    Write-Log "Operating System: $([System.Environment]::OSVersion.Platform)" -Level DEBUG
    Write-Log "Dry Run Mode: $DryRun" -Level $(if ($DryRun) { 'WARNING' } else { 'INFO' })
    Write-Log "Force Mode: $Force" -Level $(if ($Force) { 'WARNING' } else { 'INFO' })
    Write-Log "Scope: $ScopeType $(if ($ScopeId) { "($ScopeId)" } else { '' })" -Level INFO
    Write-Log "Rule Name Prefix: $RuleNamePrefix" -Level INFO

    # Validate parameters
    if ($ScopeType -ne 'tenant' -and [string]::IsNullOrWhiteSpace($ScopeId)) {
        Write-Log "ScopeId is required when ScopeType is not 'tenant'" -Level ERROR
        throw "ScopeId parameter is required for scope type '$ScopeType'"
    }

    try {
        # Step 1: Fetch current Zscaler IP ranges
        $CurrentRanges = Get-ZscalerIpRanges

        if ($CurrentRanges.TotalCount -eq 0) {
            Write-Log "No IP ranges retrieved from Zscaler APIs. Aborting." -Level ERROR
            throw "Failed to retrieve any IP ranges from Zscaler"
        }

        # Step 2: Load cached state and compare
        $CachedState = $null
        if (-not $Force) {
            $CachedState = Get-CachedState
        }
        else {
            Write-Log "Force mode enabled, bypassing cache check." -Level WARNING
        }

        $ChangeSet = Compare-IpRanges -CurrentRanges $CurrentRanges -CachedState $CachedState

        # Step 3: Apply changes if needed
        if (-not $ChangeSet.HasChanges) {
            Write-Log "No changes detected. Nothing to sync." -Level SUCCESS
            return
        }

        Write-Log "Changes detected. Proceeding with synchronization..." -Level WARNING

        $SyncedRules = Sync-FirewallRules -CurrentRanges $CurrentRanges -ChangeSet $ChangeSet

        # Step 4: Update cache (unless dry run)
        if (-not $DryRun) {
            Save-CacheState -IpRanges $CurrentRanges -SyncedRules $SyncedRules
        }
        else {
            Write-Log "[DRY RUN] Skipping cache update" -Level WARNING
        }

        # Final summary
        $EndTime = Get-Date
        $Duration = $EndTime - $StartTime

        Write-LogSection "Execution Complete"
        Write-Log "Script completed at: $($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -Level INFO
        Write-Log "Total duration: $($Duration.TotalSeconds.ToString('0.00')) seconds" -Level INFO
        Write-Log "Log file: $LogFilePath" -Level INFO
        Write-Log "Cache file: $CacheFilePath" -Level INFO
    }
    catch {
        Write-Log "Script execution failed: $_" -Level ERROR
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level ERROR
        throw
    }
}

# Execute main function
Main
#endregion
