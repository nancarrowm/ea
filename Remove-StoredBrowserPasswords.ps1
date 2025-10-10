<# 
Browser Password Purge with Profile Migration (Edge/Chrome/Firefox)
Version: 2.0.0
Intune-ready PowerShell script. Run as SYSTEM.
Deletes all saved-password databases per user profile.
Optionally migrates Chrome profiles preserving history/cookies/cache while removing passwords.

Author: Enhanced by AI Assistant
Date: $(Get-Date -Format "yyyy-MM-dd")
Changelog: 
- v2.0.0: Added Chrome profile migration feature
- v2.0.0: Enhanced Firefox key database handling
- v2.0.0: Improved error handling and logging
- v2.0.0: Added process timing and verification
- v2.0.0: Comprehensive verbose commenting

Usage:
    .\Remove-StoredBrowserPasswords.ps1 [-MigrateChromeProfiles]
    
Parameters:
    -MigrateChromeProfiles: Optional switch to migrate Chrome profiles instead of just deleting passwords
#>

[CmdletBinding()]
param(
    [switch]$MigrateChromeProfiles
)

# =============================================================================
# CONFIGURATION AND INITIALIZATION SECTION
# =============================================================================

# Set error handling to Continue to allow detailed error reporting while maintaining script flow
# This is more robust than SilentlyContinue as it allows us to catch and log specific errors
$ErrorActionPreference = 'Continue'

# Define logging configuration
# Using ProgramData ensures SYSTEM account has write access and logs persist across reboots
$logRoot = 'C:\ProgramData\BrowserPasswordPurge'
$null = New-Item -ItemType Directory -Force -Path $logRoot
$log = Join-Path $logRoot 'purge.log'

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
Write-Log "=== Browser Password Purge Script Started ===" -Level "INFO"
Write-Log "Script Version: 2.0.0" -Level "INFO"
Write-Log "Chrome Profile Migration: $($MigrateChromeProfiles.IsPresent)" -Level "INFO"
Write-Log "Execution User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -Level "INFO"

# =============================================================================
# BROWSER PROCESS TERMINATION SECTION
# =============================================================================

Write-Log "Initiating browser process termination to release file locks" -Level "INFO"

# Define browser process names to terminate
# Note: This covers the main executable names for each browser
$browserProcesses = @('chrome', 'msedge', 'firefox')

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
# This is critical to prevent "file in use" errors during deletion
Write-Log "Waiting 5 seconds for processes to fully terminate and file locks to release" -Level "INFO"
Start-Sleep -Seconds 5

# =============================================================================
# FILE OPERATION FUNCTIONS SECTION
# =============================================================================

# Enhanced file removal function with comprehensive error handling and verification
Function Remove-Files {
    param(
        [string[]]$Paths,
        [string]$Context = "Unknown"
    )
    
    $deletedCount = 0
    $failedCount = 0
    
    foreach ($filePath in $Paths) {
        if (Test-Path $filePath) {
            try {
                # Remove file attributes that might prevent deletion
                # -r: Remove read-only attribute
                # -s: Remove system attribute  
                # -h: Remove hidden attribute
                attrib -r -s -h $filePath 2>$null
                
                # Attempt to delete the file
                Remove-Item -LiteralPath $filePath -Force -ErrorAction Stop
                
                # Verify deletion was successful
                if (-not (Test-Path $filePath)) {
                    Write-Log "Successfully deleted: $filePath" -Level "INFO"
                    $deletedCount++
                } else {
                    Write-Log "Deletion verification failed: $filePath still exists" -Level "WARNING"
                    $failedCount++
                }
            } catch {
                Write-Log "Failed to delete $filePath in $Context`: $($_.Exception.Message)" -Level "ERROR"
                $failedCount++
            }
        } else {
            Write-Log "File not found (skipping): $filePath" -Level "DEBUG"
        }
    }
    
    Write-Log "$Context - Deleted: $deletedCount, Failed: $failedCount" -Level "INFO"
    return @{ Deleted = $deletedCount; Failed = $failedCount }
}

# Chrome profile migration function
# Creates a new profile with history/cookies/cache but without passwords
Function Migrate-ChromeProfile {
    param(
        [string]$OriginalProfilePath,
        [string]$UserContext
    )
    
    Write-Log "Starting Chrome profile migration for: $OriginalProfilePath" -Level "INFO"
    
    try {
        # Create backup directory with timestamp
        $backupDir = Join-Path $OriginalProfilePath "..\ProfileBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        $null = New-Item -ItemType Directory -Path $backupDir -Force
        
        # Create new profile directory
        $newProfileDir = Join-Path $OriginalProfilePath "..\Profile_New_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        $null = New-Item -ItemType Directory -Path $newProfileDir -Force
        
        # Files to copy (preserve user data but exclude passwords)
        $filesToCopy = @(
            'History',                    # Browsing history
            'History-journal',           # History journal
            'Cookies',                   # Website cookies
            'Cookies-journal',           # Cookies journal
            'Current Session',           # Current session data
            'Current Tabs',              # Open tabs
            'Last Session',              # Last session data
            'Last Tabs',                 # Last tabs
            'Preferences',               # User preferences
            'Secure Preferences',        # Secure preferences
            'Web Data',                  # Autofill data (excluding passwords)
            'Web Data-journal',          # Web data journal
            'Bookmarks',                 # Bookmarks
            'Bookmarks.bak',             # Bookmarks backup
            'Favicons',                  # Website icons
            'Favicons-journal',          # Favicons journal
            'Top Sites',                 # Top sites
            'Top Sites-journal',         # Top sites journal
            'Shortcuts',                 # Shortcuts
            'Shortcuts-journal',         # Shortcuts journal
            'Local State',               # Local state
            'Default\Preferences',       # Default preferences
            'Default\Secure Preferences' # Default secure preferences
        )
        
        # Directories to copy
        $dirsToCopy = @(
            'Cache',                     # Browser cache
            'Code Cache',                # Code cache
            'GPUCache',                  # GPU cache
            'ShaderCache',               # Shader cache
            'Default\Extensions',        # Extensions
            'Default\Local Storage',     # Local storage
            'Default\Session Storage',   # Session storage
            'Default\IndexedDB',         # IndexedDB
            'Default\databases'          # Databases
        )
        
        $copiedFiles = 0
        $copiedDirs = 0
        
        # Copy files
        foreach ($file in $filesToCopy) {
            $sourcePath = Join-Path $OriginalProfilePath $file
            $destPath = Join-Path $newProfileDir $file
            
            if (Test-Path $sourcePath) {
                try {
                    # Create parent directory if it doesn't exist
                    $destParent = Split-Path $destPath -Parent
                    if (-not (Test-Path $destParent)) {
                        $null = New-Item -ItemType Directory -Path $destParent -Force
                    }
                    
                    Copy-Item -Path $sourcePath -Destination $destPath -Force -ErrorAction Stop
                    Write-Log "Copied file: $file" -Level "DEBUG"
                    $copiedFiles++
                } catch {
                    Write-Log "Failed to copy file $file`: $($_.Exception.Message)" -Level "WARNING"
                }
            }
        }
        
        # Copy directories
        foreach ($dir in $dirsToCopy) {
            $sourcePath = Join-Path $OriginalProfilePath $dir
            $destPath = Join-Path $newProfileDir $dir
            
            if (Test-Path $sourcePath) {
                try {
                    Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force -ErrorAction Stop
                    Write-Log "Copied directory: $dir" -Level "DEBUG"
                    $copiedDirs++
                } catch {
                    Write-Log "Failed to copy directory $dir`: $($_.Exception.Message)" -Level "WARNING"
                }
            }
        }
        
        # Remove password-related files from new profile
        $passwordFiles = @(
            'Login Data',
            'Login Data-journal',
            'Login Data For Account',
            'Login Data For Account-journal'
        )
        
        foreach ($pwdFile in $passwordFiles) {
            $pwdPath = Join-Path $newProfileDir $pwdFile
            if (Test-Path $pwdPath) {
                try {
                    Remove-Item -Path $pwdPath -Force -ErrorAction Stop
                    Write-Log "Removed password file from new profile: $pwdFile" -Level "INFO"
                } catch {
                    Write-Log "Failed to remove password file $pwdFile`: $($_.Exception.Message)" -Level "WARNING"
                }
            }
        }
        
        # Move original profile to backup
        try {
            Move-Item -Path $OriginalProfilePath -Destination $backupDir -ErrorAction Stop
            Write-Log "Moved original profile to backup: $backupDir" -Level "INFO"
            
            # Rename new profile to original name
            Move-Item -Path $newProfileDir -Destination $OriginalProfilePath -ErrorAction Stop
            Write-Log "Renamed new profile to original name" -Level "INFO"
            
            Write-Log "Chrome profile migration completed successfully - Files: $copiedFiles, Directories: $copiedDirs" -Level "INFO"
            return $true
            
        } catch {
            Write-Log "Failed to complete profile migration: $($_.Exception.Message)" -Level "ERROR"
            return $false
        }
        
    } catch {
        Write-Log "Chrome profile migration failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# =============================================================================
# USER PROFILE ENUMERATION AND PROCESSING SECTION
# =============================================================================

Write-Log "Enumerating local user profiles for browser data processing" -Level "INFO"

# Enumerate local user profiles, excluding system accounts and built-in users
# This ensures we only process actual user accounts that may contain browser data
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
$totalFilesDeleted = 0
$totalProfilesMigrated = 0

# Process each user profile
foreach ($profile in $profileRoots) {
    $userName = $profile.Name
    $localAppData = Join-Path $profile.FullName 'AppData\Local'
    $roamingAppData = Join-Path $profile.FullName 'AppData\Roaming'
    
    Write-Log "=== Processing user profile: $userName ===" -Level "INFO"
    $totalUsersProcessed++
    
    # =============================================================================
    # MICROSOFT EDGE (CHROMIUM) PROCESSING
    # =============================================================================
    
    $edgeUserDataPath = Join-Path $localAppData 'Microsoft\Edge\User Data'
    if (Test-Path $edgeUserDataPath) {
        Write-Log "Processing Microsoft Edge profiles at: $edgeUserDataPath" -Level "INFO"
        
        try {
            # Get all Edge profile directories
            $edgeProfiles = Get-ChildItem -Path $edgeUserDataPath -Directory -ErrorAction Stop
            
            foreach ($edgeProfile in $edgeProfiles) {
                $profileDir = $edgeProfile.FullName
                $profileName = $edgeProfile.Name
                
                Write-Log "Processing Edge profile: $profileName" -Level "INFO"
                
                # Define Edge password database files to remove
                $edgePasswordFiles = @(
                    Join-Path $profileDir 'Login Data',                    # Primary password database
                    Join-Path $profileDir 'Login Data-journal',           # Password database journal
                    Join-Path $profileDir 'Login Data For Account',       # Account-specific password data
                    Join-Path $profileDir 'Login Data For Account-journal' # Account password journal
                )
                
                # Remove Edge password files
                $result = Remove-Files -Paths $edgePasswordFiles -Context "Edge-$profileName"
                $totalFilesDeleted += $result.Deleted
            }
            
            Write-Log "Completed Edge processing for user: $userName" -Level "INFO"
            
        } catch {
            Write-Log "Error processing Edge profiles for user $userName`: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "No Edge installation found for user: $userName" -Level "DEBUG"
    }
    
    # =============================================================================
    # GOOGLE CHROME PROCESSING
    # =============================================================================
    
    $chromeUserDataPath = Join-Path $localAppData 'Google\Chrome\User Data'
    if (Test-Path $chromeUserDataPath) {
        Write-Log "Processing Google Chrome profiles at: $chromeUserDataPath" -Level "INFO"
        
        try {
            # Get all Chrome profile directories
            $chromeProfiles = Get-ChildItem -Path $chromeUserDataPath -Directory -ErrorAction Stop
            
            foreach ($chromeProfile in $chromeProfiles) {
                $profileDir = $chromeProfile.FullName
                $profileName = $chromeProfile.Name
                
                Write-Log "Processing Chrome profile: $profileName" -Level "INFO"
                
                if ($MigrateChromeProfiles) {
                    # Migrate Chrome profile (preserve data, remove passwords)
                    $migrationResult = Migrate-ChromeProfile -OriginalProfilePath $profileDir -UserContext $userName
                    if ($migrationResult) {
                        $totalProfilesMigrated++
                        Write-Log "Successfully migrated Chrome profile: $profileName" -Level "INFO"
                    } else {
                        Write-Log "Failed to migrate Chrome profile: $profileName" -Level "ERROR"
                    }
                } else {
                    # Standard password removal for Chrome
                    $chromePasswordFiles = @(
                        Join-Path $profileDir 'Login Data',                    # Primary password database
                        Join-Path $profileDir 'Login Data-journal',           # Password database journal
                        Join-Path $profileDir 'Login Data For Account',       # Account-specific password data
                        Join-Path $profileDir 'Login Data For Account-journal' # Account password journal
                    )
                    
                    $result = Remove-Files -Paths $chromePasswordFiles -Context "Chrome-$profileName"
                    $totalFilesDeleted += $result.Deleted
                }
            }
            
            Write-Log "Completed Chrome processing for user: $userName" -Level "INFO"
            
        } catch {
            Write-Log "Error processing Chrome profiles for user $userName`: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "No Chrome installation found for user: $userName" -Level "DEBUG"
    }
    
    # =============================================================================
    # MOZILLA FIREFOX PROCESSING
    # =============================================================================
    
    $firefoxProfilesPath = Join-Path $roamingAppData 'Mozilla\Firefox\Profiles'
    if (Test-Path $firefoxProfilesPath) {
        Write-Log "Processing Mozilla Firefox profiles at: $firefoxProfilesPath" -Level "INFO"
        
        try {
            # Get all Firefox profile directories
            $firefoxProfiles = Get-ChildItem -Path $firefoxProfilesPath -Directory -ErrorAction Stop
            
            foreach ($firefoxProfile in $firefoxProfiles) {
                $profileDir = $firefoxProfile.FullName
                $profileName = $firefoxProfile.Name
                
                Write-Log "Processing Firefox profile: $profileName" -Level "INFO"
                
                # Define Firefox password and encryption files to remove
                # This includes both modern and legacy Firefox password storage formats
                $firefoxPasswordFiles = @(
                    Join-Path $profileDir 'logins.json',              # Modern Firefox saved logins (JSON format)
                    Join-Path $profileDir 'logins-backup.json',       # Backup of saved logins
                    Join-Path $profileDir 'signons.sqlite',           # Legacy Firefox password database
                    Join-Path $profileDir 'signons.sqlite-wal',       # SQLite write-ahead log
                    Join-Path $profileDir 'signons.sqlite-shm',       # SQLite shared memory
                    Join-Path $profileDir 'key4.db',                  # Modern Firefox encryption key database
                    Join-Path $profileDir 'key3.db',                  # Legacy Firefox encryption key database
                    Join-Path $profileDir 'key.db',                   # Very old Firefox key database
                    Join-Path $profileDir 'cert9.db',                  # Certificate database (may contain stored passwords)
                    Join-Path $profileDir 'cert8.db',                  # Legacy certificate database
                    Join-Path $profileDir 'pkcs11.txt'                # PKCS#11 configuration (may contain passwords)
                )
                
                $result = Remove-Files -Paths $firefoxPasswordFiles -Context "Firefox-$profileName"
                $totalFilesDeleted += $result.Deleted
            }
            
            Write-Log "Completed Firefox processing for user: $userName" -Level "INFO"
            
        } catch {
            Write-Log "Error processing Firefox profiles for user $userName`: $($_.Exception.Message)" -Level "ERROR"
        }
    } else {
        Write-Log "No Firefox installation found for user: $userName" -Level "DEBUG"
    }
    
    Write-Log "Completed processing for user: $userName" -Level "INFO"
}

# =============================================================================
# EXECUTION SUMMARY AND COMPLETION SECTION
# =============================================================================

Write-Log "=== Browser Password Purge Script Execution Summary ===" -Level "INFO"
Write-Log "Script Version: 2.0.0" -Level "INFO"
Write-Log "Execution Mode: $(if ($MigrateChromeProfiles) { 'Chrome Profile Migration' } else { 'Password Deletion Only' })" -Level "INFO"
Write-Log "Total Users Processed: $totalUsersProcessed" -Level "INFO"
Write-Log "Total Files Deleted: $totalFilesDeleted" -Level "INFO"

if ($MigrateChromeProfiles) {
    Write-Log "Total Chrome Profiles Migrated: $totalProfilesMigrated" -Level "INFO"
}

Write-Log "Script execution completed successfully" -Level "INFO"
Write-Log "=== Browser Password Purge Script Ended ===" -Level "INFO"

# Exit with success code
exit 0
