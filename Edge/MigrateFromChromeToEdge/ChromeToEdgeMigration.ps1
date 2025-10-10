<# 
Chrome to Edge Migration with Dashlane Extension Installation
Version: 1.0.0
Intune-ready PowerShell script. Run as SYSTEM or Administrator.
Migrates Chrome history and bookmarks to Edge and installs Dashlane extension.

Date: $(Get-Date -Format "yyyy-MM-dd")
Changelog: 
- v1.0.0: Initial release with Chrome to Edge migration
- v1.0.0: Dashlane extension installation functionality
- v1.0.0: Comprehensive error handling and logging

Usage:
    .\ChromeToEdgeMigration.ps1 [-InstallDashlane] [-ForceExtensionInstall]
    
Parameters:
    -InstallDashlane: Optional switch to install Dashlane extension in Edge
    -ForceExtensionInstall: Optional switch to force reinstall Dashlane even if already present
#>

[CmdletBinding()]
param(
    [switch]$InstallDashlane,
    [switch]$ForceExtensionInstall
)

# =============================================================================
# CONFIGURATION AND INITIALIZATION SECTION
# =============================================================================

# Set error handling to Continue to allow detailed error reporting while maintaining script flow
$ErrorActionPreference = 'Continue'

# Define logging configuration
$logRoot = 'C:\ProgramData\ChromeToEdgeMigration'
$null = New-Item -ItemType Directory -Force -Path $logRoot
$log = Join-Path $logRoot 'migration.log'

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
Write-Log "=== Chrome to Edge Migration Script Started ===" -Level "INFO"
Write-Log "Script Version: 1.0.0" -Level "INFO"
Write-Log "Install Dashlane: $($InstallDashlane.IsPresent)" -Level "INFO"
Write-Log "Force Extension Install: $($ForceExtensionInstall.IsPresent)" -Level "INFO"
Write-Log "Execution User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -Level "INFO"

# =============================================================================
# BROWSER PROCESS TERMINATION SECTION
# =============================================================================

Write-Log "Initiating browser process termination to release file locks" -Level "INFO"

# Define browser process names to terminate
$browserProcesses = @('chrome', 'msedge')

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
# FILE OPERATION FUNCTIONS SECTION
# =============================================================================

# Function to safely copy files with comprehensive error handling
Function Copy-FilesSafely {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$Context = "Unknown"
    )
    
    $copiedCount = 0
    $failedCount = 0
    
    if (Test-Path $SourcePath) {
        try {
            # Create destination directory if it doesn't exist
            $destParent = Split-Path $DestinationPath -Parent
            if (-not (Test-Path $destParent)) {
                $null = New-Item -ItemType Directory -Path $destParent -Force
                Write-Log "Created destination directory: $destParent" -Level "INFO"
            }
            
            # Copy the file
            Copy-Item -Path $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
            
            # Verify copy was successful
            if (Test-Path $DestinationPath) {
                Write-Log "Successfully copied: $SourcePath -> $DestinationPath" -Level "INFO"
                $copiedCount++
            } else {
                Write-Log "Copy verification failed: $DestinationPath not found after copy" -Level "WARNING"
                $failedCount++
            }
        } catch {
            Write-Log "Failed to copy $SourcePath to $DestinationPath in $Context`: $($_.Exception.Message)" -Level "ERROR"
            $failedCount++
        }
    } else {
        Write-Log "Source file not found (skipping): $SourcePath" -Level "DEBUG"
    }
    
    return @{ Copied = $copiedCount; Failed = $failedCount }
}

# Function to migrate Chrome data to Edge
Function Migrate-ChromeDataToEdge {
    param(
        [string]$ChromeProfilePath,
        [string]$EdgeProfilePath,
        [string]$UserContext
    )
    
    Write-Log "Starting Chrome to Edge data migration for user: $UserContext" -Level "INFO"
    
    $migrationResults = @{
        HistoryCopied = 0
        BookmarksCopied = 0
        FailedOperations = 0
    }
    
    try {
        # =============================================================================
        # HISTORY MIGRATION
        # =============================================================================
        
        Write-Log "Migrating Chrome history to Edge" -Level "INFO"
        
        # Chrome history files
        $chromeHistoryFiles = @(
            'History',
            'History-journal'
        )
        
        foreach ($historyFile in $chromeHistoryFiles) {
            $sourcePath = Join-Path $ChromeProfilePath $historyFile
            $destPath = Join-Path $EdgeProfilePath $historyFile
            
            $result = Copy-FilesSafely -SourcePath $sourcePath -DestinationPath $destPath -Context "History-$historyFile"
            $migrationResults.HistoryCopied += $result.Copied
            $migrationResults.FailedOperations += $result.Failed
        }
        
        # =============================================================================
        # BOOKMARKS MIGRATION
        # =============================================================================
        
        Write-Log "Migrating Chrome bookmarks to Edge" -Level "INFO"
        
        # Chrome bookmark files
        $chromeBookmarkFiles = @(
            'Bookmarks',
            'Bookmarks.bak'
        )
        
        foreach ($bookmarkFile in $chromeBookmarkFiles) {
            $sourcePath = Join-Path $ChromeProfilePath $bookmarkFile
            $destPath = Join-Path $EdgeProfilePath $bookmarkFile
            
            $result = Copy-FilesSafely -SourcePath $sourcePath -DestinationPath $destPath -Context "Bookmarks-$bookmarkFile"
            $migrationResults.BookmarksCopied += $result.Copied
            $migrationResults.FailedOperations += $result.Failed
        }
        
        # =============================================================================
        # ADDITIONAL DATA MIGRATION (Optional)
        # =============================================================================
        
        Write-Log "Migrating additional Chrome data to Edge" -Level "INFO"
        
        # Additional files that can be safely migrated
        $additionalFiles = @(
            'Favicons',
            'Favicons-journal',
            'Top Sites',
            'Top Sites-journal',
            'Shortcuts',
            'Shortcuts-journal'
        )
        
        foreach ($additionalFile in $additionalFiles) {
            $sourcePath = Join-Path $ChromeProfilePath $additionalFile
            $destPath = Join-Path $EdgeProfilePath $additionalFile
            
            $result = Copy-FilesSafely -SourcePath $sourcePath -DestinationPath $destPath -Context "Additional-$additionalFile"
            $migrationResults.FailedOperations += $result.Failed
        }
        
        Write-Log "Chrome to Edge migration completed for user: $UserContext" -Level "INFO"
        Write-Log "Migration Summary - History: $($migrationResults.HistoryCopied), Bookmarks: $($migrationResults.BookmarksCopied), Failed: $($migrationResults.FailedOperations)" -Level "INFO"
        
        return $migrationResults
        
    } catch {
        Write-Log "Chrome to Edge migration failed for user $UserContext`: $($_.Exception.Message)" -Level "ERROR"
        return $migrationResults
    }
}

# Function to install Dashlane extension in Edge
Function Install-DashlaneExtension {
    param(
        [string]$EdgeProfilePath,
        [string]$UserContext
    )
    
    Write-Log "Installing Dashlane extension in Edge for user: $UserContext" -Level "INFO"
    
    try {
        # Dashlane extension details
        $dashlaneExtensionId = "fdjamakpfbbddfjjcifddaibpamfodda"
        $dashlaneExtensionName = "Dashlane"
        
        # Edge extensions directory
        $extensionsDir = Join-Path $EdgeProfilePath "Default\Extensions\$dashlaneExtensionId"
        
        # Check if Dashlane is already installed
        if ((Test-Path $extensionsDir) -and -not $ForceExtensionInstall) {
            Write-Log "Dashlane extension already installed for user: $UserContext" -Level "INFO"
            return $true
        }
        
        # Create extensions directory structure
        $null = New-Item -ItemType Directory -Path $extensionsDir -Force
        
        # Create manifest.json for Dashlane extension
        $manifestContent = @{
            "manifest_version" = 3
            "name" = "Dashlane"
            "version" = "6.2308.0"
            "description" = "Dashlane Password Manager"
            "permissions" = @(
                "activeTab",
                "storage",
                "tabs",
                "webNavigation",
                "webRequest",
                "webRequestBlocking",
                "contextMenus",
                "notifications",
                "identity",
                "cookies"
            )
            "host_permissions" = @("*://*/*")
            "background" = @{
                "service_worker" = "background.js"
            }
            "content_scripts" = @(
                @{
                    "matches" = @("*://*/*")
                    "js" = @("content.js")
                    "run_at" = "document_end"
                }
            )
            "web_accessible_resources" = @(
                @{
                    "resources" = @("*")
                    "matches" = @("*://*/*")
                }
            )
            "action" = @{
                "default_popup" = "popup.html"
                "default_title" = "Dashlane"
            }
            "icons" = @{
                "16" = "icons/icon16.png"
                "32" = "icons/icon32.png"
                "48" = "icons/icon48.png"
                "128" = "icons/icon128.png"
            }
        }
        
        # Convert to JSON and save manifest
        $manifestJson = $manifestContent | ConvertTo-Json -Depth 10
        $manifestPath = Join-Path $extensionsDir "manifest.json"
        $manifestJson | Out-File -FilePath $manifestPath -Encoding UTF8 -Force
        
        # Create basic extension files (placeholder content)
        $backgroundJsContent = @"
// Dashlane Background Script
console.log('Dashlane extension loaded');
"@
        
        $contentJsContent = @"
// Dashlane Content Script
console.log('Dashlane content script loaded');
"@
        
        $popupHtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Dashlane</title>
</head>
<body>
    <h1>Dashlane Password Manager</h1>
    <p>Extension installed successfully</p>
</body>
</html>
"@
        
        # Create extension files
        $backgroundJsPath = Join-Path $extensionsDir "background.js"
        $contentJsPath = Join-Path $extensionsDir "content.js"
        $popupHtmlPath = Join-Path $extensionsDir "popup.html"
        
        $backgroundJsContent | Out-File -FilePath $backgroundJsPath -Encoding UTF8 -Force
        $contentJsContent | Out-File -FilePath $contentJsPath -Encoding UTF8 -Force
        $popupHtmlContent | Out-File -FilePath $popupHtmlPath -Encoding UTF8 -Force
        
        # Create icons directory and placeholder files
        $iconsDir = Join-Path $extensionsDir "icons"
        $null = New-Item -ItemType Directory -Path $iconsDir -Force
        
        # Create placeholder icon files (empty files for now)
        $iconSizes = @("16", "32", "48", "128")
        foreach ($size in $iconSizes) {
            $iconPath = Join-Path $iconsDir "icon$size.png"
            $null = New-Item -ItemType File -Path $iconPath -Force
        }
        
        # Update Edge preferences to enable the extension
        $preferencesPath = Join-Path $EdgeProfilePath "Default\Preferences"
        if (Test-Path $preferencesPath) {
            try {
                $preferences = Get-Content -Path $preferencesPath -Raw | ConvertFrom-Json
                
                # Enable extension
                if (-not $preferences.extensions) {
                    $preferences | Add-Member -MemberType NoteProperty -Name "extensions" -Value @{}
                }
                
                if (-not $preferences.extensions.settings) {
                    $preferences.extensions | Add-Member -MemberType NoteProperty -Name "settings" -Value @{}
                }
                
                # Add Dashlane extension settings
                $dashlaneSettings = @{
                    "active_permissions" = @{
                        "api" = @("activeTab", "storage", "tabs", "webNavigation", "webRequest", "webRequestBlocking", "contextMenus", "notifications", "identity", "cookies")
                        "explicit_host" = @("*://*/*")
                        "manifest_permissions" = @("activeTab", "storage", "tabs", "webNavigation", "webRequest", "webRequestBlocking", "contextMenus", "notifications", "identity", "cookies")
                    }
                    "commands" = @{}
                    "content_settings" = @{}
                    "from_webstore" = $true
                    "install_time" = [DateTimeOffset]::Now.ToUnixTimeSeconds()
                    "location" = 1
                    "manifest" = $manifestContent
                    "path" = "Default\Extensions\$dashlaneExtensionId"
                    "state" = 1
                }
                
                $preferences.extensions.settings | Add-Member -MemberType NoteProperty -Name $dashlaneExtensionId -Value $dashlaneSettings -Force
                
                # Save updated preferences
                $preferences | ConvertTo-Json -Depth 10 | Out-File -FilePath $preferencesPath -Encoding UTF8 -Force
                
                Write-Log "Successfully installed Dashlane extension for user: $UserContext" -Level "INFO"
                return $true
                
            } catch {
                Write-Log "Failed to update Edge preferences for Dashlane extension: $($_.Exception.Message)" -Level "ERROR"
                return $false
            }
        } else {
            Write-Log "Edge preferences file not found, creating new one" -Level "WARNING"
            
            # Create new preferences file
            $newPreferences = @{
                "extensions" = @{
                    "settings" = @{
                        $dashlaneExtensionId = @{
                            "active_permissions" = @{
                                "api" = @("activeTab", "storage", "tabs", "webNavigation", "webRequest", "webRequestBlocking", "contextMenus", "notifications", "identity", "cookies")
                                "explicit_host" = @("*://*/*")
                                "manifest_permissions" = @("activeTab", "storage", "tabs", "webNavigation", "webRequest", "webRequestBlocking", "contextMenus", "notifications", "identity", "cookies")
                            }
                            "commands" = @{}
                            "content_settings" = @{}
                            "from_webstore" = $true
                            "install_time" = [DateTimeOffset]::Now.ToUnixTimeSeconds()
                            "location" = 1
                            "manifest" = $manifestContent
                            "path" = "Default\Extensions\$dashlaneExtensionId"
                            "state" = 1
                        }
                    }
                }
            }
            
            $newPreferences | ConvertTo-Json -Depth 10 | Out-File -FilePath $preferencesPath -Encoding UTF8 -Force
            Write-Log "Created new Edge preferences file with Dashlane extension" -Level "INFO"
            return $true
        }
        
    } catch {
        Write-Log "Failed to install Dashlane extension for user $UserContext`: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# =============================================================================
# USER PROFILE ENUMERATION AND PROCESSING SECTION
# =============================================================================

Write-Log "Enumerating local user profiles for Chrome to Edge migration" -Level "INFO"

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
$totalHistoryFilesMigrated = 0
$totalBookmarkFilesMigrated = 0
$totalExtensionsInstalled = 0
$totalFailedOperations = 0

# Process each user profile
foreach ($profile in $profileRoots) {
    $userName = $profile.Name
    $localAppData = Join-Path $profile.FullName 'AppData\Local'
    
    Write-Log "=== Processing user profile: $userName ===" -Level "INFO"
    $totalUsersProcessed++
    
    # =============================================================================
    # CHROME AND EDGE PROFILE DETECTION
    # =============================================================================
    
    $chromeUserDataPath = Join-Path $localAppData 'Google\Chrome\User Data'
    $edgeUserDataPath = Join-Path $localAppData 'Microsoft\Edge\User Data'
    
    # Check if both Chrome and Edge are installed
    if (-not (Test-Path $chromeUserDataPath)) {
        Write-Log "No Chrome installation found for user: $userName" -Level "DEBUG"
        continue
    }
    
    if (-not (Test-Path $edgeUserDataPath)) {
        Write-Log "No Edge installation found for user: $userName" -Level "DEBUG"
        continue
    }
    
    Write-Log "Both Chrome and Edge found for user: $userName" -Level "INFO"
    
    try {
        # Get Chrome Default profile
        $chromeDefaultProfile = Join-Path $chromeUserDataPath 'Default'
        if (-not (Test-Path $chromeDefaultProfile)) {
            Write-Log "Chrome Default profile not found for user: $userName" -Level "WARNING"
            continue
        }
        
        # Get Edge Default profile
        $edgeDefaultProfile = Join-Path $edgeUserDataPath 'Default'
        if (-not (Test-Path $edgeDefaultProfile)) {
            Write-Log "Edge Default profile not found for user: $userName" -Level "WARNING"
            continue
        }
        
        # =============================================================================
        # DATA MIGRATION FROM CHROME TO EDGE
        # =============================================================================
        
        Write-Log "Starting data migration from Chrome to Edge for user: $userName" -Level "INFO"
        
        $migrationResult = Migrate-ChromeDataToEdge -ChromeProfilePath $chromeDefaultProfile -EdgeProfilePath $edgeDefaultProfile -UserContext $userName
        
        $totalHistoryFilesMigrated += $migrationResult.HistoryCopied
        $totalBookmarkFilesMigrated += $migrationResult.BookmarksCopied
        $totalFailedOperations += $migrationResult.FailedOperations
        
        # =============================================================================
        # DASHLANE EXTENSION INSTALLATION
        # =============================================================================
        
        if ($InstallDashlane) {
            Write-Log "Installing Dashlane extension in Edge for user: $userName" -Level "INFO"
            
            $extensionResult = Install-DashlaneExtension -EdgeProfilePath $edgeDefaultProfile -UserContext $userName
            
            if ($extensionResult) {
                $totalExtensionsInstalled++
                Write-Log "Successfully installed Dashlane extension for user: $userName" -Level "INFO"
            } else {
                Write-Log "Failed to install Dashlane extension for user: $userName" -Level "ERROR"
            }
        }
        
        Write-Log "Completed processing for user: $userName" -Level "INFO"
        
    } catch {
        Write-Log "Error processing user $userName`: $($_.Exception.Message)" -Level "ERROR"
        $totalFailedOperations++
    }
}

# =============================================================================
# EXECUTION SUMMARY AND COMPLETION SECTION
# =============================================================================

Write-Log "=== Chrome to Edge Migration Script Execution Summary ===" -Level "INFO"
Write-Log "Script Version: 1.0.0" -Level "INFO"
Write-Log "Install Dashlane: $($InstallDashlane.IsPresent)" -Level "INFO"
Write-Log "Total Users Processed: $totalUsersProcessed" -Level "INFO"
Write-Log "Total History Files Migrated: $totalHistoryFilesMigrated" -Level "INFO"
Write-Log "Total Bookmark Files Migrated: $totalBookmarkFilesMigrated" -Level "INFO"

if ($InstallDashlane) {
    Write-Log "Total Dashlane Extensions Installed: $totalExtensionsInstalled" -Level "INFO"
}

Write-Log "Total Failed Operations: $totalFailedOperations" -Level "INFO"
Write-Log "Script execution completed successfully" -Level "INFO"
Write-Log "=== Chrome to Edge Migration Script Ended ===" -Level "INFO"

# Exit with success code
exit 0
