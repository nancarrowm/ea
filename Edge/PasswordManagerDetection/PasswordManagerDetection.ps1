<# 
Password Manager Detection and Dashlane Migration Assessment Script
Version: 1.0.0
Intune-ready PowerShell script. Run as SYSTEM or Administrator.
Detects password manager applications and browser extensions, assesses Dashlane migration compatibility.

Date: $(Get-Date -Format "yyyy-MM-dd")
Changelog: 
- v1.0.0: Initial release with password manager detection
- v1.0.0: Browser extension detection functionality
- v1.0.0: Dashlane migration compatibility assessment
- v1.0.0: Comprehensive error handling and logging

Usage:
    .\PasswordManagerDetection.ps1 [-DetailedReport] [-ExportResults]
    
Parameters:
    -DetailedReport: Optional switch to generate detailed migration assessment report
    -ExportResults: Optional switch to export results to CSV file
#>

[CmdletBinding()]
param(
    [switch]$DetailedReport,
    [switch]$ExportResults
)

# =============================================================================
# CONFIGURATION AND INITIALIZATION SECTION
# =============================================================================

# Set error handling to Continue to allow detailed error reporting while maintaining script flow
$ErrorActionPreference = 'Continue'

# Define logging configuration
$logRoot = 'C:\ProgramData\PasswordManagerDetection'
$null = New-Item -ItemType Directory -Force -Path $logRoot
$log = Join-Path $logRoot 'detection.log'

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
Write-Log "=== Password Manager Detection and Dashlane Migration Assessment Script Started ===" -Level "INFO"
Write-Log "Script Version: 1.0.0" -Level "INFO"
Write-Log "Detailed Report: $($DetailedReport.IsPresent)" -Level "INFO"
Write-Log "Export Results: $($ExportResults.IsPresent)" -Level "INFO"
Write-Log "Execution User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -Level "INFO"

# =============================================================================
# PASSWORD MANAGER DETECTION CONFIGURATION
# =============================================================================

# Define common password manager applications with their detection criteria
$passwordManagers = @{
    '1Password' = @{
        Name = '1Password'
        ProcessNames = @('1Password', '1Password 7', '1Password 8')
        InstallPaths = @(
            'C:\Program Files\1Password',
            'C:\Program Files (x86)\1Password',
            'C:\Users\*\AppData\Local\1Password',
            'C:\Users\*\AppData\Roaming\1Password'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*1Password*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*1Password*'
        )
        MigrationCompatibility = 'High'
        MigrationNotes = 'Direct import from 1Password CSV export. Supports most data types including passwords, notes, and custom fields.'
    }
    'LastPass' = @{
        Name = 'LastPass'
        ProcessNames = @('LastPass', 'LastPassApp', 'LP')
        InstallPaths = @(
            'C:\Program Files\LastPass',
            'C:\Program Files (x86)\LastPass',
            'C:\Users\*\AppData\Local\LastPass',
            'C:\Users\*\AppData\Roaming\LastPass'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*LastPass*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*LastPass*'
        )
        MigrationCompatibility = 'High'
        MigrationNotes = 'Direct import from LastPass CSV export. Supports passwords, notes, and form data.'
    }
    'Bitwarden' = @{
        Name = 'Bitwarden'
        ProcessNames = @('Bitwarden', 'Bitwarden Desktop')
        InstallPaths = @(
            'C:\Program Files\Bitwarden',
            'C:\Program Files (x86)\Bitwarden',
            'C:\Users\*\AppData\Local\Bitwarden',
            'C:\Users\*\AppData\Roaming\Bitwarden'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*Bitwarden*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*Bitwarden*'
        )
        MigrationCompatibility = 'High'
        MigrationNotes = 'Direct import from Bitwarden JSON export. Supports all data types including passwords, notes, and attachments.'
    }
    'KeePass' = @{
        Name = 'KeePass'
        ProcessNames = @('KeePass', 'KeePass2', 'KeePassXC')
        InstallPaths = @(
            'C:\Program Files\KeePass',
            'C:\Program Files (x86)\KeePass',
            'C:\Program Files\KeePassXC',
            'C:\Program Files (x86)\KeePassXC'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*KeePass*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*KeePass*'
        )
        MigrationCompatibility = 'Medium'
        MigrationNotes = 'Import via CSV export from KeePass. Some advanced features may not transfer directly.'
    }
    'RoboForm' = @{
        Name = 'RoboForm'
        ProcessNames = @('RoboForm', 'RoboFormTaskBar')
        InstallPaths = @(
            'C:\Program Files\Siber Systems\RoboForm',
            'C:\Program Files (x86)\Siber Systems\RoboForm'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*RoboForm*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*RoboForm*'
        )
        MigrationCompatibility = 'Medium'
        MigrationNotes = 'Import via CSV export. Form data and some advanced features may require manual configuration.'
    }
    'Dashlane' = @{
        Name = 'Dashlane'
        ProcessNames = @('Dashlane', 'DashlaneAgent')
        InstallPaths = @(
            'C:\Program Files\Dashlane',
            'C:\Program Files (x86)\Dashlane',
            'C:\Users\*\AppData\Local\Dashlane',
            'C:\Users\*\AppData\Roaming\Dashlane'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*Dashlane*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*Dashlane*'
        )
        MigrationCompatibility = 'N/A'
        MigrationNotes = 'Already using Dashlane - no migration needed.'
    }
    'NordPass' = @{
        Name = 'NordPass'
        ProcessNames = @('NordPass', 'NordPassApp')
        InstallPaths = @(
            'C:\Program Files\NordPass',
            'C:\Program Files (x86)\NordPass',
            'C:\Users\*\AppData\Local\NordPass',
            'C:\Users\*\AppData\Roaming\NordPass'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*NordPass*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*NordPass*'
        )
        MigrationCompatibility = 'High'
        MigrationNotes = 'Direct import from NordPass CSV export. Supports passwords and notes.'
    }
    'Enpass' = @{
        Name = 'Enpass'
        ProcessNames = @('Enpass', 'EnpassApp')
        InstallPaths = @(
            'C:\Program Files\Enpass',
            'C:\Program Files (x86)\Enpass',
            'C:\Users\*\AppData\Local\Enpass',
            'C:\Users\*\AppData\Roaming\Enpass'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*Enpass*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*Enpass*'
        )
        MigrationCompatibility = 'Medium'
        MigrationNotes = 'Import via CSV export. Some advanced features may not transfer directly.'
    }
    'Keeper' = @{
        Name = 'Keeper'
        ProcessNames = @('Keeper', 'KeeperApp')
        InstallPaths = @(
            'C:\Program Files\Keeper Security',
            'C:\Program Files (x86)\Keeper Security',
            'C:\Users\*\AppData\Local\Keeper',
            'C:\Users\*\AppData\Roaming\Keeper'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*Keeper*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*Keeper*'
        )
        MigrationCompatibility = 'High'
        MigrationNotes = 'Direct import from Keeper CSV export. Supports passwords, notes, and file attachments.'
    }
    'Password Boss' = @{
        Name = 'Password Boss'
        ProcessNames = @('PasswordBoss', 'PasswordBossApp')
        InstallPaths = @(
            'C:\Program Files\Password Boss',
            'C:\Program Files (x86)\Password Boss'
        )
        RegistryKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*PasswordBoss*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*PasswordBoss*'
        )
        MigrationCompatibility = 'Medium'
        MigrationNotes = 'Import via CSV export. Some features may require manual configuration.'
    }
}

# Define common password manager browser extensions
$passwordManagerExtensions = @{
    '1Password' = @{
        Name = '1Password'
        ExtensionIds = @('aeblfdkhhhdcdjpifhhbdiojplfjncoa', 'aomjjhallfgjeglblehebfpbcfeobgkm')
        Browsers = @('Chrome', 'Edge', 'Firefox')
        MigrationCompatibility = 'High'
    }
    'LastPass' = @{
        Name = 'LastPass'
        ExtensionIds = @('hdokiejnpimakedhajhdlcegeplioahd', 'hclgegipaehbigmdhjkdahfddllofppe')
        Browsers = @('Chrome', 'Edge', 'Firefox')
        MigrationCompatibility = 'High'
    }
    'Bitwarden' = @{
        Name = 'Bitwarden'
        ExtensionIds = @('nngceckbapebfimnlniiiahkandclblb', 'jbkfoedolllejbhkalfljikfdjfbcdae')
        Browsers = @('Chrome', 'Edge', 'Firefox')
        MigrationCompatibility = 'High'
    }
    'KeePass' = @{
        Name = 'KeePass'
        ExtensionIds = @('oboonakemofpalcgghocfoadofidjkkk', 'bfgdeidkbaqhgcpfijjilocddhiedof')
        Browsers = @('Chrome', 'Edge', 'Firefox')
        MigrationCompatibility = 'Medium'
    }
    'Dashlane' = @{
        Name = 'Dashlane'
        ExtensionIds = @('fdjamakpfbbddfjjcifddaibpamfodda', 'chfdnecihphmhljaaejmgoiahnihplgn')
        Browsers = @('Chrome', 'Edge', 'Firefox')
        MigrationCompatibility = 'N/A'
    }
    'NordPass' = @{
        Name = 'NordPass'
        ExtensionIds = @('fooolghllnmhmmndgjiamiiodkpenpbb', 'nldfocmeagfklgkgdkhkhmbcklbegbca')
        Browsers = @('Chrome', 'Edge', 'Firefox')
        MigrationCompatibility = 'High'
    }
    'Enpass' = @{
        Name = 'Enpass'
        ExtensionIds = @('kmcfomidfpdkfieipokbalgegidffkal', 'bblddlllbbfjblncffnncllmhmlapjfl')
        Browsers = @('Chrome', 'Edge', 'Firefox')
        MigrationCompatibility = 'Medium'
    }
    'Keeper' = @{
        Name = 'Keeper'
        ExtensionIds = @('bfogiafebkohllanpklchhldobkpkdai', 'bfogiafebkohllanpklchhldobkpkdai')
        Browsers = @('Chrome', 'Edge', 'Firefox')
        MigrationCompatibility = 'High'
    }
    'RoboForm' = @{
        Name = 'RoboForm'
        ExtensionIds = @('pnlccmojcmeohlpggmfnbbiapkmbliob', 'pnlccmojcmeohlpggmfnbbiapkmbliob')
        Browsers = @('Chrome', 'Edge', 'Firefox')
        MigrationCompatibility = 'Medium'
    }
}

# =============================================================================
# DETECTION FUNCTIONS SECTION
# =============================================================================

# Function to detect installed applications
Function Get-InstalledApplications {
    param(
        [string]$UserContext = "System"
    )
    
    Write-Log "Detecting installed password manager applications for user: $UserContext" -Level "INFO"
    
    $detectedApps = @()
    
    foreach ($managerName in $passwordManagers.Keys) {
        $manager = $passwordManagers[$managerName]
        $detectionResult = @{
            Name = $manager.Name
            Detected = $false
            DetectionMethod = $null
            Version = $null
            InstallPath = $null
            MigrationCompatibility = $manager.MigrationCompatibility
            MigrationNotes = $manager.MigrationNotes
            UserContext = $UserContext
        }
        
        # Check running processes
        foreach ($processName in $manager.ProcessNames) {
            try {
                $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
                if ($processes) {
                    $detectionResult.Detected = $true
                    $detectionResult.DetectionMethod = "Running Process"
                    Write-Log "Found $managerName running process: $processName" -Level "INFO"
                    break
                }
            } catch {
                Write-Log "Error checking process $processName for $managerName`: $($_.Exception.Message)" -Level "DEBUG"
            }
        }
        
        # Check installation paths
        if (-not $detectionResult.Detected) {
            foreach ($pathPattern in $manager.InstallPaths) {
                try {
                    $expandedPaths = $pathPattern -replace '\*', '*'
                    $foundPaths = Get-ChildItem -Path $expandedPaths -ErrorAction SilentlyContinue
                    if ($foundPaths) {
                        $detectionResult.Detected = $true
                        $detectionResult.DetectionMethod = "Installation Path"
                        $detectionResult.InstallPath = $foundPaths[0].FullName
                        Write-Log "Found $managerName installation at: $($foundPaths[0].FullName)" -Level "INFO"
                        break
                    }
                } catch {
                    Write-Log "Error checking path $pathPattern for $managerName`: $($_.Exception.Message)" -Level "DEBUG"
                }
            }
        }
        
        # Check registry for uninstall information
        if (-not $detectionResult.Detected) {
            foreach ($regPattern in $manager.RegistryKeys) {
                try {
                    $regPaths = Get-ChildItem -Path $regPattern -ErrorAction SilentlyContinue
                    if ($regPaths) {
                        $detectionResult.Detected = $true
                        $detectionResult.DetectionMethod = "Registry"
                        
                        # Try to get version information
                        try {
                            $version = Get-ItemProperty -Path $regPaths[0].PSPath -Name "DisplayVersion" -ErrorAction SilentlyContinue
                            if ($version) {
                                $detectionResult.Version = $version.DisplayVersion
                            }
                        } catch {
                            Write-Log "Could not get version for $managerName from registry" -Level "DEBUG"
                        }
                        
                        Write-Log "Found $managerName in registry: $($regPaths[0].PSPath)" -Level "INFO"
                        break
                    }
                } catch {
                    Write-Log "Error checking registry $regPattern for $managerName`: $($_.Exception.Message)" -Level "DEBUG"
                }
            }
        }
        
        $detectedApps += $detectionResult
    }
    
    return $detectedApps
}

# Function to detect browser extensions
Function Get-BrowserExtensions {
    param(
        [string]$UserContext = "System"
    )
    
    Write-Log "Detecting password manager browser extensions for user: $UserContext" -Level "INFO"
    
    $detectedExtensions = @()
    $userProfile = Get-ChildItem 'C:\Users' -Force | Where-Object { $_.Name -eq $UserContext -and $_.PSIsContainer }
    
    if (-not $userProfile) {
        Write-Log "User profile not found for: $UserContext" -Level "WARNING"
        return $detectedExtensions
    }
    
    $localAppData = Join-Path $userProfile.FullName 'AppData\Local'
    $roamingAppData = Join-Path $userProfile.FullName 'AppData\Roaming'
    
    # Check Chrome extensions
    $chromeExtensionsPath = Join-Path $localAppData 'Google\Chrome\User Data\Default\Extensions'
    if (Test-Path $chromeExtensionsPath) {
        Write-Log "Checking Chrome extensions for user: $UserContext" -Level "INFO"
        
        foreach ($extensionName in $passwordManagerExtensions.Keys) {
            $extension = $passwordManagerExtensions[$extensionName]
            
            foreach ($extensionId in $extension.ExtensionIds) {
                $extensionPath = Join-Path $chromeExtensionsPath $extensionId
                if (Test-Path $extensionPath) {
                    $detectionResult = @{
                        Name = $extension.Name
                        Browser = 'Chrome'
                        ExtensionId = $extensionId
                        Detected = $true
                        MigrationCompatibility = $extension.MigrationCompatibility
                        UserContext = $UserContext
                        InstallPath = $extensionPath
                    }
                    
                    # Try to get extension version
                    try {
                        $versionDirs = Get-ChildItem -Path $extensionPath -Directory -ErrorAction SilentlyContinue
                        if ($versionDirs) {
                            $manifestPath = Join-Path $versionDirs[0].FullName 'manifest.json'
                            if (Test-Path $manifestPath) {
                                $manifestContent = Get-Content -Path $manifestPath -Raw -ErrorAction SilentlyContinue
                                $manifest = $manifestContent | ConvertFrom-Json -ErrorAction SilentlyContinue
                                if ($manifest.version) {
                                    $detectionResult.Version = $manifest.version
                                }
                            }
                        }
                    } catch {
                        Write-Log "Could not get version for Chrome extension $extensionName" -Level "DEBUG"
                    }
                    
                    $detectedExtensions += $detectionResult
                    Write-Log "Found Chrome extension: $($extension.Name) ($extensionId)" -Level "INFO"
                }
            }
        }
    }
    
    # Check Edge extensions
    $edgeExtensionsPath = Join-Path $localAppData 'Microsoft\Edge\User Data\Default\Extensions'
    if (Test-Path $edgeExtensionsPath) {
        Write-Log "Checking Edge extensions for user: $UserContext" -Level "INFO"
        
        foreach ($extensionName in $passwordManagerExtensions.Keys) {
            $extension = $passwordManagerExtensions[$extensionName]
            
            foreach ($extensionId in $extension.ExtensionIds) {
                $extensionPath = Join-Path $edgeExtensionsPath $extensionId
                if (Test-Path $extensionPath) {
                    $detectionResult = @{
                        Name = $extension.Name
                        Browser = 'Edge'
                        ExtensionId = $extensionId
                        Detected = $true
                        MigrationCompatibility = $extension.MigrationCompatibility
                        UserContext = $UserContext
                        InstallPath = $extensionPath
                    }
                    
                    # Try to get extension version
                    try {
                        $versionDirs = Get-ChildItem -Path $extensionPath -Directory -ErrorAction SilentlyContinue
                        if ($versionDirs) {
                            $manifestPath = Join-Path $versionDirs[0].FullName 'manifest.json'
                            if (Test-Path $manifestPath) {
                                $manifestContent = Get-Content -Path $manifestPath -Raw -ErrorAction SilentlyContinue
                                $manifest = $manifestContent | ConvertFrom-Json -ErrorAction SilentlyContinue
                                if ($manifest.version) {
                                    $detectionResult.Version = $manifest.version
                                }
                            }
                        }
                    } catch {
                        Write-Log "Could not get version for Edge extension $extensionName" -Level "DEBUG"
                    }
                    
                    $detectedExtensions += $detectionResult
                    Write-Log "Found Edge extension: $($extension.Name) ($extensionId)" -Level "INFO"
                }
            }
        }
    }
    
    # Check Firefox extensions
    $firefoxProfilesPath = Join-Path $roamingAppData 'Mozilla\Firefox\Profiles'
    if (Test-Path $firefoxProfilesPath) {
        Write-Log "Checking Firefox extensions for user: $UserContext" -Level "INFO"
        
        $firefoxProfiles = Get-ChildItem -Path $firefoxProfilesPath -Directory -ErrorAction SilentlyContinue
        foreach ($profile in $firefoxProfiles) {
            $extensionsPath = Join-Path $profile.FullName 'extensions'
            if (Test-Path $extensionsPath) {
                foreach ($extensionName in $passwordManagerExtensions.Keys) {
                    $extension = $passwordManagerExtensions[$extensionName]
                    
                    foreach ($extensionId in $extension.ExtensionIds) {
                        $extensionPath = Join-Path $extensionsPath "$extensionId.xpi"
                        if (Test-Path $extensionPath) {
                            $detectionResult = @{
                                Name = $extension.Name
                                Browser = 'Firefox'
                                ExtensionId = $extensionId
                                Detected = $true
                                MigrationCompatibility = $extension.MigrationCompatibility
                                UserContext = $UserContext
                                InstallPath = $extensionPath
                            }
                            
                            $detectedExtensions += $detectionResult
                            Write-Log "Found Firefox extension: $($extension.Name) ($extensionId)" -Level "INFO"
                        }
                    }
                }
            }
        }
    }
    
    return $detectedExtensions
}

# Function to generate migration assessment
Function Get-MigrationAssessment {
    param(
        [array]$DetectedApps,
        [array]$DetectedExtensions
    )
    
    Write-Log "Generating Dashlane migration assessment" -Level "INFO"
    
    $assessment = @{
        TotalApplications = $DetectedApps.Count
        TotalExtensions = $DetectedExtensions.Count
        HighCompatibilityApps = @()
        MediumCompatibilityApps = @()
        LowCompatibilityApps = @()
        AlreadyUsingDashlane = $false
        MigrationRecommendations = @()
        MigrationSteps = @()
    }
    
    # Analyze applications
    foreach ($app in $DetectedApps) {
        if ($app.Detected) {
            switch ($app.MigrationCompatibility) {
                'High' {
                    $assessment.HighCompatibilityApps += $app
                    $assessment.MigrationRecommendations += "High compatibility: $($app.Name) - $($app.MigrationNotes)"
                }
                'Medium' {
                    $assessment.MediumCompatibilityApps += $app
                    $assessment.MigrationRecommendations += "Medium compatibility: $($app.Name) - $($app.MigrationNotes)"
                }
                'Low' {
                    $assessment.LowCompatibilityApps += $app
                    $assessment.MigrationRecommendations += "Low compatibility: $($app.Name) - Manual migration may be required"
                }
                'N/A' {
                    if ($app.Name -eq 'Dashlane') {
                        $assessment.AlreadyUsingDashlane = $true
                    }
                }
            }
        }
    }
    
    # Analyze extensions
    foreach ($extension in $DetectedExtensions) {
        if ($extension.Detected) {
            switch ($extension.MigrationCompatibility) {
                'High' {
                    $assessment.MigrationRecommendations += "High compatibility extension: $($extension.Name) in $($extension.Browser)"
                }
                'Medium' {
                    $assessment.MigrationRecommendations += "Medium compatibility extension: $($extension.Name) in $($extension.Browser)"
                }
                'Low' {
                    $assessment.MigrationRecommendations += "Low compatibility extension: $($extension.Name) in $($extension.Browser)"
                }
                'N/A' {
                    if ($extension.Name -eq 'Dashlane') {
                        $assessment.AlreadyUsingDashlane = $true
                    }
                }
            }
        }
    }
    
    # Generate migration steps
    if ($assessment.AlreadyUsingDashlane) {
        $assessment.MigrationSteps += "Dashlane is already installed - no migration needed"
    } else {
        $assessment.MigrationSteps += "Install Dashlane application and browser extensions"
        
        if ($assessment.HighCompatibilityApps.Count -gt 0) {
            $assessment.MigrationSteps += "Export data from high compatibility applications: $($assessment.HighCompatibilityApps.Name -join ', ')"
            $assessment.MigrationSteps += "Import exported data into Dashlane using CSV import feature"
        }
        
        if ($assessment.MediumCompatibilityApps.Count -gt 0) {
            $assessment.MigrationSteps += "Export data from medium compatibility applications: $($assessment.MediumCompatibilityApps.Name -join ', ')"
            $assessment.MigrationSteps += "Review and manually configure any features that don't import automatically"
        }
        
        if ($assessment.LowCompatibilityApps.Count -gt 0) {
            $assessment.MigrationSteps += "Manual migration required for: $($assessment.LowCompatibilityApps.Name -join ', ')"
            $assessment.MigrationSteps += "Consider exporting data and manually recreating entries in Dashlane"
        }
        
        $assessment.MigrationSteps += "Remove old password manager applications and extensions"
        $assessment.MigrationSteps += "Configure Dashlane browser extensions for all browsers"
        $assessment.MigrationSteps += "Test password filling and generation functionality"
    }
    
    return $assessment
}

# =============================================================================
# USER PROFILE ENUMERATION AND PROCESSING SECTION
# =============================================================================

Write-Log "Enumerating local user profiles for password manager detection" -Level "INFO"

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

# Initialize detection results
$allDetectedApps = @()
$allDetectedExtensions = @()
$totalUsersProcessed = 0

# Process each user profile
foreach ($profile in $profileRoots) {
    $userName = $profile.Name
    
    Write-Log "=== Processing user profile: $userName ===" -Level "INFO"
    $totalUsersProcessed++
    
    try {
        # Detect applications
        $userApps = Get-InstalledApplications -UserContext $userName
        $allDetectedApps += $userApps
        
        # Detect extensions
        $userExtensions = Get-BrowserExtensions -UserContext $userName
        $allDetectedExtensions += $userExtensions
        
        Write-Log "Completed processing for user: $userName" -Level "INFO"
        
    } catch {
        Write-Log "Error processing user $userName`: $($_.Exception.Message)" -Level "ERROR"
    }
}

# =============================================================================
# MIGRATION ASSESSMENT AND REPORTING SECTION
# =============================================================================

Write-Log "Generating comprehensive migration assessment" -Level "INFO"

$migrationAssessment = Get-MigrationAssessment -DetectedApps $allDetectedApps -DetectedExtensions $allDetectedExtensions

# Generate detailed report if requested
if ($DetailedReport) {
    Write-Log "=== DETAILED MIGRATION ASSESSMENT REPORT ===" -Level "INFO"
    Write-Log "Total Users Processed: $totalUsersProcessed" -Level "INFO"
    Write-Log "Total Applications Detected: $($migrationAssessment.TotalApplications)" -Level "INFO"
    Write-Log "Total Extensions Detected: $($migrationAssessment.TotalExtensions)" -Level "INFO"
    
    if ($migrationAssessment.AlreadyUsingDashlane) {
        Write-Log "Dashlane Status: Already Installed" -Level "INFO"
    } else {
        Write-Log "Dashlane Status: Not Installed" -Level "INFO"
    }
    
    Write-Log "High Compatibility Applications: $($migrationAssessment.HighCompatibilityApps.Count)" -Level "INFO"
    foreach ($app in $migrationAssessment.HighCompatibilityApps) {
        Write-Log "  - $($app.Name) (Version: $($app.Version), Method: $($app.DetectionMethod))" -Level "INFO"
    }
    
    Write-Log "Medium Compatibility Applications: $($migrationAssessment.MediumCompatibilityApps.Count)" -Level "INFO"
    foreach ($app in $migrationAssessment.MediumCompatibilityApps) {
        Write-Log "  - $($app.Name) (Version: $($app.Version), Method: $($app.DetectionMethod))" -Level "INFO"
    }
    
    Write-Log "Low Compatibility Applications: $($migrationAssessment.LowCompatibilityApps.Count)" -Level "INFO"
    foreach ($app in $migrationAssessment.LowCompatibilityApps) {
        Write-Log "  - $($app.Name) (Version: $($app.Version), Method: $($app.DetectionMethod))" -Level "INFO"
    }
    
    Write-Log "Migration Recommendations:" -Level "INFO"
    foreach ($recommendation in $migrationAssessment.MigrationRecommendations) {
        Write-Log "  - $recommendation" -Level "INFO"
    }
    
    Write-Log "Migration Steps:" -Level "INFO"
    foreach ($step in $migrationAssessment.MigrationSteps) {
        Write-Log "  - $step" -Level "INFO"
    }
}

# Export results to CSV if requested
if ($ExportResults) {
    $exportPath = Join-Path $logRoot "password-manager-detection-results.csv"
    
    try {
        # Export application results
        $appExportData = $allDetectedApps | Where-Object { $_.Detected } | Select-Object Name, Version, DetectionMethod, InstallPath, MigrationCompatibility, MigrationNotes, UserContext
        $appExportData | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
        
        # Export extension results
        $extensionExportPath = Join-Path $logRoot "password-manager-extensions-results.csv"
        $extensionExportData = $allDetectedExtensions | Where-Object { $_.Detected } | Select-Object Name, Browser, ExtensionId, Version, MigrationCompatibility, UserContext, InstallPath
        $extensionExportData | Export-Csv -Path $extensionExportPath -NoTypeInformation -Encoding UTF8
        
        Write-Log "Results exported to: $exportPath and $extensionExportPath" -Level "INFO"
        
    } catch {
        Write-Log "Failed to export results: $($_.Exception.Message)" -Level "ERROR"
    }
}

# =============================================================================
# EXECUTION SUMMARY AND COMPLETION SECTION
# =============================================================================

Write-Log "=== Password Manager Detection Script Execution Summary ===" -Level "INFO"
Write-Log "Script Version: 1.0.0" -Level "INFO"
Write-Log "Total Users Processed: $totalUsersProcessed" -Level "INFO"
Write-Log "Total Applications Detected: $($migrationAssessment.TotalApplications)" -Level "INFO"
Write-Log "Total Extensions Detected: $($migrationAssessment.TotalExtensions)" -Level "INFO"
Write-Log "High Compatibility Apps: $($migrationAssessment.HighCompatibilityApps.Count)" -Level "INFO"
Write-Log "Medium Compatibility Apps: $($migrationAssessment.MediumCompatibilityApps.Count)" -Level "INFO"
Write-Log "Low Compatibility Apps: $($migrationAssessment.LowCompatibilityApps.Count)" -Level "INFO"

if ($migrationAssessment.AlreadyUsingDashlane) {
    Write-Log "Dashlane Status: Already Installed - No Migration Needed" -Level "INFO"
} else {
    Write-Log "Dashlane Status: Not Installed - Migration Recommended" -Level "INFO"
}

Write-Log "Script execution completed successfully" -Level "INFO"
Write-Log "=== Password Manager Detection Script Ended ===" -Level "INFO"

# Exit with success code
exit 0
