<# 
Google Sync Detection and De-authentication Script
Version: 1.1.0
Intune-ready PowerShell script. Run as SYSTEM or Administrator.
Detects Google Sync status in Chrome, de-authenticates users, and prepares for password deletion.

Date: $(Get-Date -Format "yyyy-MM-dd")
Changelog: 
- v1.1.0: Removed Edge de-authentication functionality
- v1.0.0: Initial release with Google Sync detection
- v1.0.0: Chrome sync de-authentication
- v1.0.0: Comprehensive error handling and logging

Usage:
    .\GoogleSyncDeauth.ps1 [-ForceDeauth] [-SkipDetection]
    
Parameters:
    -ForceDeauth: Optional switch to force de-authentication even if sync appears disabled
    -SkipDetection: Optional switch to skip sync detection and proceed directly to de-authentication
#>

[CmdletBinding()]
param(
    [switch]$ForceDeauth,
    [switch]$SkipDetection
)

# =============================================================================
# CONFIGURATION AND INITIALIZATION SECTION
# =============================================================================

# Set error handling to Continue to allow detailed error reporting while maintaining script flow
$ErrorActionPreference = 'Continue'

# Define logging configuration
$logRoot = 'C:\ProgramData\GoogleSyncDeauth'
$null = New-Item -ItemType Directory -Force -Path $logRoot
$log = Join-Path $logRoot 'sync-deauth.log'

# Enhanced logging function with structured output and error level support
Function Write-Log { 
    param(
        [string]$Message,
        [string]$Level = 'INFO'
    )
    
    # Create timestamp with millisecond precision for better debugging
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    
    # Format log entry with level, timestamp, and message
    $logEntry = "[$Level] $timestamp - $Message"
    
    # Write to log file with UTF8 encoding to handle international characters
    $logEntry | Out-File -FilePath $log -Append -Encoding UTF8
    
    # Also output to console for real-time monitoring when running interactively
    Write-Host $logEntry
}

# Initialize script execution logging
Write-Log "=== Google Sync Detection and De-authentication Script Started ===" -Level "INFO"
Write-Log "Script Version: 1.1.0" -Level "INFO"
Write-Log "Force De-authentication: $($ForceDeauth.IsPresent)" -Level "INFO"
Write-Log "Skip Detection: $($SkipDetection.IsPresent)" -Level "INFO"
Write-Log "Execution User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -Level "INFO"

# =============================================================================
# BROWSER PROCESS TERMINATION SECTION
# =============================================================================

Write-Log "Initiating browser process termination to release file locks" -Level "INFO"

# Define browser process names to terminate
$browserProcesses = @('chrome')

# Terminate browser processes with enhanced error handling
foreach ($processName in $browserProcesses) {
    try {
        # Get all processes matching the name (case-insensitive)
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
        
        if ($processes) {
            # Force terminate all matching processes
            $processes | Stop-Process -Force -ErrorAction Stop
            Write-Log "Successfully terminated $($processes.Count) $processName process(es)" -Level "INFO"
        } else {
            Write-Log "No $processName processes found running" -Level "INFO"
        }
    } catch {
        Write-Log "Failed to terminate $processName processes: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Wait for processes to fully terminate and file locks to be released
Write-Log "Waiting 5 seconds for processes to fully terminate and file locks to release" -Level "INFO"
Start-Sleep -Seconds 5

# =============================================================================
# GOOGLE SYNC DETECTION AND DE-AUTHENTICATION FUNCTIONS
# =============================================================================
Function Get-ChromeSyncStatus {
    param(
        [string]$ChromeProfilePath,
        [string]$UserContext
    )
    
    Write-Log "Detecting Chrome sync status for user: $UserContext" -Level "INFO"
    
    $syncStatus = @{
        IsEnabled = $false
        AccountEmail = $null
        SyncData = @()
        LastSyncTime = $null
        Error = $null
    }
    
    try {
        # Check Chrome preferences file for sync settings
        $preferencesPath = Join-Path $ChromeProfilePath "Default\Preferences"
        
        if (Test-Path $preferencesPath) {
            try {
                # Read and parse Chrome preferences
                $preferencesContent = Get-Content -Path $preferencesPath -Raw -ErrorAction Stop
                $preferences = $preferencesContent | ConvertFrom-Json -ErrorAction Stop
                
                # Check for Google account sign-in
                if ($preferences.account_info -and $preferences.account_info.length -gt 0) {
                    $accountInfo = $preferences.account_info[0]
                    $syncStatus.AccountEmail = $accountInfo.email
                    Write-Log "Found Chrome account: $($syncStatus.AccountEmail)" -Level "INFO"
                }
                
                # Check sync settings
                if ($preferences.profile -and $preferences.profile.sync) {
                    $syncSettings = $preferences.profile.sync
                    
                    # Check if sync is enabled
                    if ($syncSettings.sync_enabled -eq $true) {
                        $syncStatus.IsEnabled = $true
                        Write-Log "Chrome sync is ENABLED for user: $UserContext" -Level "WARNING"
                        
                        # Get sync data types
                        if ($syncSettings.sync_data_types) {
                            $syncStatus.SyncData = $syncSettings.sync_data_types
                            Write-Log "Sync data types: $($syncStatus.SyncData -join ', ')" -Level "INFO"
                        }
                        
                        # Get last sync time
                        if ($syncSettings.last_sync_time) {
                            $syncStatus.LastSyncTime = [DateTimeOffset]::FromUnixTimeSeconds($syncSettings.last_sync_time).DateTime
                            Write-Log "Last sync time: $($syncStatus.LastSyncTime)" -Level "INFO"
                        }
                    } else {
                        Write-Log "Chrome sync is DISABLED for user: $UserContext" -Level "INFO"
                    }
                } else {
                    Write-Log "No sync settings found in Chrome preferences for user: $UserContext" -Level "INFO"
                }
                
            } catch {
                $syncStatus.Error = "Failed to parse Chrome preferences: $($_.Exception.Message)"
                Write-Log "Error parsing Chrome preferences for user $UserContext`: $($_.Exception.Message)" -Level "ERROR"
            }
        } else {
            Write-Log "Chrome preferences file not found for user: $UserContext" -Level "DEBUG"
        }
        
    } catch {
        $syncStatus.Error = "Failed to read Chrome preferences: $($_.Exception.Message)"
        Write-Log "Error reading Chrome preferences for user $UserContext`: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $syncStatus
}


# Function to de-authenticate Chrome user
Function Disable-ChromeSync {
    param(
        [string]$ChromeProfilePath,
        [string]$UserContext
    )
    
    Write-Log "De-authenticating Chrome user: $UserContext" -Level "INFO"
    
    try {
        $preferencesPath = Join-Path $ChromeProfilePath "Default\Preferences"
        
        if (Test-Path $preferencesPath) {
            try {
                # Read current preferences
                $preferencesContent = Get-Content -Path $preferencesPath -Raw -ErrorAction Stop
                $preferences = $preferencesContent | ConvertFrom-Json -ErrorAction Stop
                
                # Disable sync
                if ($preferences.profile -and $preferences.profile.sync) {
                    $preferences.profile.sync.sync_enabled = $false
                    Write-Log "Disabled Chrome sync in preferences" -Level "INFO"
                }
                
                # Clear account info
                if ($preferences.account_info) {
                    $preferences.account_info = @()
                    Write-Log "Cleared Chrome account info" -Level "INFO"
                }
                
                # Clear sign-in data
                if ($preferences.signin) {
                    $preferences.signin.allowed = $false
                    Write-Log "Disabled Chrome sign-in" -Level "INFO"
                }
                
                # Save updated preferences
                $preferences | ConvertTo-Json -Depth 10 | Out-File -FilePath $preferencesPath -Encoding UTF8 -Force
                Write-Log "Updated Chrome preferences file" -Level "INFO"
                
                # Remove Google account tokens
                $tokenFiles = @(
                    "Default\Google Profile Picture.png",
                    "Default\Google Profile Picture (1).png",
                    "Default\Google Profile Picture (2).png",
                    "Default\Google Profile Picture (3).png",
                    "Default\Google Profile Picture (4).png"
                )
                
                foreach ($tokenFile in $tokenFiles) {
                    $tokenPath = Join-Path $ChromeProfilePath $tokenFile
                    if (Test-Path $tokenPath) {
                        try {
                            Remove-Item -Path $tokenPath -Force -ErrorAction Stop
                            Write-Log "Removed Chrome token file: $tokenFile" -Level "INFO"
                        } catch {
                            Write-Log "Failed to remove Chrome token file $tokenFile`: $($_.Exception.Message)" -Level "WARNING"
                        }
                    }
                }
                
                # Remove Google account data
                $googleAccountDir = Join-Path $ChromeProfilePath "Default\Google Account Pictures"
                if (Test-Path $googleAccountDir) {
                    try {
                        Remove-Item -Path $googleAccountDir -Recurse -Force -ErrorAction Stop
                        Write-Log "Removed Chrome Google Account Pictures directory" -Level "INFO"
                    } catch {
                        Write-Log "Failed to remove Chrome Google Account Pictures directory: $($_.Exception.Message)" -Level "WARNING"
                        }
                }
                
                Write-Log "Successfully de-authenticated Chrome user: $UserContext" -Level "INFO"
                return $true
                
            } catch {
                Write-Log "Failed to update Chrome preferences for user $UserContext`: $($_.Exception.Message)" -Level "ERROR"
                return $false
            }
        } else {
            Write-Log "Chrome preferences file not found for user: $UserContext" -Level "WARNING"
            return $false
        }
        
    } catch {
        Write-Log "Failed to de-authenticate Chrome user $UserContext`: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}


# =============================================================================
# USER PROFILE ENUMERATION AND PROCESSING SECTION
# =============================================================================

Write-Log "Enumerating local user profiles for Google Sync detection and de-authentication" -Level "INFO"

# Enumerate local user profiles, excluding system accounts and built-in users
$profileRoots = Get-ChildItem 'C:\Users' -Force | Where-Object {
    $_.PSIsContainer -and $_.Name -notin @(
        'Public',           # Public user profile
        'Default',           # Default user template
        'Default User',      # Legacy default user template
        'All Users',         # Legacy all users profile
        'WDAGUtilityAccount', # Windows Defender Application Guard utility account
        'Administrator',     # Built-in administrator account
        'Guest',             # Built-in guest account
        'krbtgt'             # Kerberos service account
    )
}

Write-Log "Found $($profileRoots.Count) user profiles to process" -Level "INFO"

# Initialize counters for summary reporting
$totalUsersProcessed = 0
$totalChromeSyncDetected = 0
$totalChromeDeauthSuccess = 0
$totalFailedOperations = 0

# Process each user profile
foreach ($profile in $profileRoots) {
    $userName = $profile.Name
    $localAppData = Join-Path $profile.FullName 'AppData\Local'
    
    Write-Log "=== Processing user profile: $userName ===" -Level "INFO"
    $totalUsersProcessed++
    
    # =============================================================================
    # CHROME SYNC DETECTION AND DE-AUTHENTICATION
    # =============================================================================
    
    $chromeUserDataPath = Join-Path $localAppData 'Google\Chrome\User Data'
    if (Test-Path $chromeUserDataPath) {
        Write-Log "Processing Chrome sync for user: $userName" -Level "INFO"
        
        try {
            $chromeDefaultProfile = Join-Path $chromeUserDataPath 'Default'
            
            if (Test-Path $chromeDefaultProfile) {
                # Detect Chrome sync status
                if (-not $SkipDetection) {
                    $chromeSyncStatus = Get-ChromeSyncStatus -ChromeProfilePath $chromeDefaultProfile -UserContext $userName
                    
                    if ($chromeSyncStatus.IsEnabled) {
                        $totalChromeSyncDetected++
                        Write-Log "Chrome sync ENABLED for user: $userName" -Level "WARNING"
                        
                        if ($chromeSyncStatus.AccountEmail) {
                            Write-Log "Chrome account: $($chromeSyncStatus.AccountEmail)" -Level "WARNING"
                        }
                        
                        if ($chromeSyncStatus.SyncData.Count -gt 0) {
                            Write-Log "Chrome sync data types: $($chromeSyncStatus.SyncData -join ', ')" -Level "WARNING"
                        }
                    } else {
                        Write-Log "Chrome sync DISABLED for user: $userName" -Level "INFO"
                    }
                }
                
                # De-authenticate Chrome user
                if ($ForceDeauth -or $SkipDetection -or ($chromeSyncStatus.IsEnabled)) {
                    $deauthResult = Disable-ChromeSync -ChromeProfilePath $chromeDefaultProfile -UserContext $userName
                    
                    if ($deauthResult) {
                        $totalChromeDeauthSuccess++
                        Write-Log "Successfully de-authenticated Chrome for user: $userName" -Level "INFO"
                    } else {
                        Write-Log "Failed to de-authenticate Chrome for user: $userName" -Level "ERROR"
                        $totalFailedOperations++
                    }
                }
            } else {
                Write-Log "Chrome Default profile not found for user: $userName" -Level "DEBUG"
            }
            
        } catch {
            Write-Log "Error processing Chrome sync for user $userName`: $($_.Exception.Message)" -Level "ERROR"
            $totalFailedOperations++
        }
    } else {
        Write-Log "No Chrome installation found for user: $userName" -Level "DEBUG"
    }
    
    Write-Log "Completed processing for user: $userName" -Level "INFO"
}

# =============================================================================
# EXECUTION SUMMARY AND COMPLETION SECTION
# =============================================================================

Write-Log "=== Google Sync Detection and De-authentication Script Execution Summary ===" -Level "INFO"
Write-Log "Script Version: 1.1.0" -Level "INFO"
Write-Log "Force De-authentication: $($ForceDeauth.IsPresent)" -Level "INFO"
Write-Log "Skip Detection: $($SkipDetection.IsPresent)" -Level "INFO"
Write-Log "Total Users Processed: $totalUsersProcessed" -Level "INFO"

if (-not $SkipDetection) {
    Write-Log "Total Chrome Sync Detected: $totalChromeSyncDetected" -Level "INFO"
}

Write-Log "Total Chrome De-authentication Success: $totalChromeDeauthSuccess" -Level "INFO"
Write-Log "Total Failed Operations: $totalFailedOperations" -Level "INFO"

if ($totalChromeSyncDetected -gt 0) {
    Write-Log "WARNING: Chrome sync was detected and de-authenticated. Users will need to re-sign in." -Level "WARNING"
}

Write-Log "Script execution completed successfully" -Level "INFO"
Write-Log "=== Google Sync Detection and De-authentication Script Ended ===" -Level "INFO"

# Exit with success code
exit 0
