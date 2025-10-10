<# 
Sensitive Credential Detection Script
Version: 1.0.0
Intune-ready PowerShell script. Run as SYSTEM or Administrator.
Scans user profiles for files containing passwords, usernames, and other sensitive credential information.

Designed by Michael Nancarrow
Date: $(Get-Date -Format "yyyy-MM-dd")
Changelog: 
- v1.0.0: Initial release with sensitive credential detection
- v1.0.0: File pattern matching and content analysis
- v1.0.0: Comprehensive error handling and logging

Usage:
    .\SensitiveCredentialDetection.ps1 [-DetailedScan] [-ExportResults] [-ScanContent]
    
Parameters:
    -DetailedScan: Optional switch to perform detailed content analysis
    -ExportResults: Optional switch to export results to CSV file
    -ScanContent: Optional switch to scan file contents for sensitive patterns
#>

[CmdletBinding()]
param(
    [switch]$DetailedScan,
    [switch]$ExportResults,
    [switch]$ScanContent
)

# =============================================================================
# CONFIGURATION AND INITIALIZATION SECTION
# =============================================================================

# Set error handling to Continue to allow detailed error reporting while maintaining script flow
$ErrorActionPreference = 'Continue'

# Define logging configuration
$logRoot = 'C:\ProgramData\SensitiveCredentialDetection'
$null = New-Item -ItemType Directory -Force -Path $logRoot
$log = Join-Path $logRoot 'credential-detection.log'

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
Write-Log "=== Sensitive Credential Detection Script Started ===" -Level "INFO"
Write-Log "Script Version: 1.0.0" -Level "INFO"
Write-Log "Designed by Michael Nancarrow" -Level "INFO"
Write-Log "Detailed Scan: $($DetailedScan.IsPresent)" -Level "INFO"
Write-Log "Export Results: $($ExportResults.IsPresent)" -Level "INFO"
Write-Log "Scan Content: $($ScanContent.IsPresent)" -Level "INFO"
Write-Log "Execution User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -Level "INFO"

# =============================================================================
# SENSITIVE CREDENTIAL DETECTION CONFIGURATION
# =============================================================================

# Define file patterns that commonly contain sensitive credentials
$sensitiveFilePatterns = @{
    'Password Files' = @(
        '*.pwd',
        '*.pass',
        '*.password',
        'passwords.txt',
        'passwords.csv',
        'passwords.json',
        'credentials.txt',
        'credentials.csv',
        'credentials.json',
        'login.txt',
        'login.csv',
        'login.json',
        'auth.txt',
        'auth.csv',
        'auth.json',
        'secrets.txt',
        'secrets.csv',
        'secrets.json',
        'keys.txt',
        'keys.csv',
        'keys.json',
        'tokens.txt',
        'tokens.csv',
        'tokens.json'
    )
    'Configuration Files' = @(
        'config.txt',
        'config.csv',
        'config.json',
        'config.xml',
        'settings.txt',
        'settings.csv',
        'settings.json',
        'settings.xml',
        '*.conf',
        '*.cfg',
        '*.ini',
        '*.env',
        '.env',
        'environment.txt',
        'environment.csv',
        'environment.json'
    )
    'Database Files' = @(
        '*.db',
        '*.sqlite',
        '*.sqlite3',
        '*.mdb',
        '*.accdb',
        '*.fdb',
        '*.gdb'
    )
    'Backup Files' = @(
        '*.bak',
        '*.backup',
        '*.old',
        '*.orig',
        '*.tmp',
        '*.temp'
    )
    'Archive Files' = @(
        '*.zip',
        '*.rar',
        '*.7z',
        '*.tar',
        '*.gz',
        '*.bz2'
    )
    'Document Files' = @(
        '*.doc',
        '*.docx',
        '*.xls',
        '*.xlsx',
        '*.ppt',
        '*.pptx',
        '*.pdf',
        '*.txt',
        '*.rtf'
    )
    'Script Files' = @(
        '*.ps1',
        '*.bat',
        '*.cmd',
        '*.vbs',
        '*.js',
        '*.py',
        '*.rb',
        '*.php',
        '*.sh',
        '*.sql'
    )
}

# Define sensitive content patterns for content scanning
$sensitiveContentPatterns = @{
    'Password Patterns' = @(
        'password\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'passwd\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'pwd\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'secret\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'key\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'token\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'auth\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'login\s*[:=]\s*["\']?[^"\'\s]+["\']?'
    )
    'Username Patterns' = @(
        'username\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'user\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'login\s*[:=]\s*["\']?[^"\'\s]+["\']?',
        'email\s*[:=]\s*["\']?[^"\'\s@]+@[^"\'\s@]+\.[^"\'\s@]+["\']?',
        'account\s*[:=]\s*["\']?[^"\'\s]+["\']?'
    )
    'API Key Patterns' = @(
        'api[_-]?key\s*[:=]\s*["\']?[A-Za-z0-9]{20,}["\']?',
        'apikey\s*[:=]\s*["\']?[A-Za-z0-9]{20,}["\']?',
        'access[_-]?key\s*[:=]\s*["\']?[A-Za-z0-9]{20,}["\']?',
        'secret[_-]?key\s*[:=]\s*["\']?[A-Za-z0-9]{20,}["\']?'
    )
    'Database Connection Patterns' = @(
        'connection[_-]?string\s*[:=]\s*["\']?[^"\']+["\']?',
        'conn[_-]?string\s*[:=]\s*["\']?[^"\']+["\']?',
        'database[_-]?url\s*[:=]\s*["\']?[^"\']+["\']?',
        'db[_-]?url\s*[:=]\s*["\']?[^"\']+["\']?'
    )
    'SSH Key Patterns' = @(
        '-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----',
        '-----BEGIN PRIVATE KEY-----',
        'ssh-rsa\s+[A-Za-z0-9+/]+=*',
        'ssh-dss\s+[A-Za-z0-9+/]+=*',
        'ssh-ed25519\s+[A-Za-z0-9+/]+=*'
    )
}

# Define directories to scan within user profiles
$scanDirectories = @(
    'Desktop',
    'Documents',
    'Downloads',
    'AppData\Local',
    'AppData\Roaming',
    'AppData\LocalLow',
    'OneDrive',
    'OneDrive - *',
    'Google Drive',
    'Dropbox',
    'Box',
    'iCloud Drive'
)

# Define file extensions to exclude from scanning (system files, binaries, etc.)
$excludeExtensions = @(
    '.exe',
    '.dll',
    '.sys',
    '.bin',
    '.dat',
    '.log',
    '.tmp',
    '.temp',
    '.cache',
    '.lock',
    '.pid',
    '.swp',
    '.swo',
    '.obj',
    '.o',
    '.so',
    '.dylib',
    '.a',
    '.lib'
)

# =============================================================================
# SENSITIVE CREDENTIAL DETECTION FUNCTIONS
# =============================================================================

# Function to scan files for sensitive patterns
Function Scan-FileForSensitiveContent {
    param(
        [string]$FilePath,
        [string]$UserContext
    )
    
    Write-Log "Scanning file content: $FilePath" -Level "DEBUG"
    
    $sensitiveMatches = @()
    
    try {
        # Check if file is readable and not too large (limit to 10MB)
        $fileInfo = Get-Item -Path $FilePath -ErrorAction SilentlyContinue
        if ($fileInfo -and $fileInfo.Length -gt 10MB) {
            Write-Log "File too large for content scanning: $FilePath ($($fileInfo.Length) bytes)" -Level "DEBUG"
            return $sensitiveMatches
        }
        
        # Read file content
        $content = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
        if (-not $content) {
            return $sensitiveMatches
        }
        
        # Scan for sensitive patterns
        foreach ($patternCategory in $sensitiveContentPatterns.Keys) {
            foreach ($pattern in $sensitiveContentPatterns[$patternCategory]) {
                try {
                    $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
                    foreach ($match in $matches) {
                        $sensitiveMatches += @{
                            FilePath = $FilePath
                            PatternCategory = $patternCategory
                            Pattern = $pattern
                            Match = $match.Value
                            UserContext = $UserContext
                            Severity = 'High'
                        }
                    }
                } catch {
                    Write-Log "Error scanning pattern $pattern in file $FilePath`: $($_.Exception.Message)" -Level "DEBUG"
                }
            }
        }
        
    } catch {
        Write-Log "Error scanning file content $FilePath`: $($_.Exception.Message)" -Level "DEBUG"
    }
    
    return $sensitiveMatches
}

# Function to scan directory for sensitive files
Function Scan-DirectoryForSensitiveFiles {
    param(
        [string]$DirectoryPath,
        [string]$UserContext
    )
    
    Write-Log "Scanning directory: $DirectoryPath" -Level "INFO"
    
    $sensitiveFiles = @()
    
    if (-not (Test-Path $DirectoryPath)) {
        Write-Log "Directory not found: $DirectoryPath" -Level "DEBUG"
        return $sensitiveFiles
    }
    
    try {
        # Scan each pattern category
        foreach ($category in $sensitiveFilePatterns.Keys) {
            foreach ($pattern in $sensitiveFilePatterns[$category]) {
                try {
                    $foundFiles = Get-ChildItem -Path $DirectoryPath -Filter $pattern -Recurse -ErrorAction SilentlyContinue
                    
                    foreach ($file in $foundFiles) {
                        # Skip excluded file extensions
                        $fileExtension = $file.Extension.ToLower()
                        if ($excludeExtensions -contains $fileExtension) {
                            continue
                        }
                        
                        # Skip system files and directories
                        if ($file.Attributes -band [System.IO.FileAttributes]::System) {
                            continue
                        }
                        
                        $sensitiveFile = @{
                            FilePath = $file.FullName
                            FileName = $file.Name
                            FileSize = $file.Length
                            LastModified = $file.LastWriteTime
                            PatternCategory = $category
                            Pattern = $pattern
                            UserContext = $UserContext
                            Severity = 'Medium'
                        }
                        
                        # Perform content scanning if requested
                        if ($ScanContent) {
                            $contentMatches = Scan-FileForSensitiveContent -FilePath $file.FullName -UserContext $UserContext
                            if ($contentMatches.Count -gt 0) {
                                $sensitiveFile.Severity = 'High'
                                $sensitiveFile.ContentMatches = $contentMatches.Count
                            }
                        }
                        
                        $sensitiveFiles += $sensitiveFile
                        Write-Log "Found sensitive file: $($file.FullName)" -Level "INFO"
                    }
                } catch {
                    Write-Log "Error scanning pattern $pattern in directory $DirectoryPath`: $($_.Exception.Message)" -Level "DEBUG"
                }
            }
        }
        
    } catch {
        Write-Log "Error scanning directory $DirectoryPath`: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $sensitiveFiles
}

# Function to scan user profile for sensitive credentials
Function Scan-UserProfileForSensitiveCredentials {
    param(
        [string]$UserProfilePath,
        [string]$UserContext
    )
    
    Write-Log "Scanning user profile for sensitive credentials: $UserContext" -Level "INFO"
    
    $allSensitiveFiles = @()
    
    try {
        # Scan each configured directory
        foreach ($directory in $scanDirectories) {
            $directoryPath = Join-Path $UserProfilePath $directory
            
            # Handle wildcard directories (like OneDrive - *)
            if ($directory -like '*') {
                $wildcardPath = Join-Path $UserProfilePath ($directory -replace '\*', '*')
                $matchingDirs = Get-ChildItem -Path $wildcardPath -Directory -ErrorAction SilentlyContinue
                foreach ($matchingDir in $matchingDirs) {
                    $sensitiveFiles = Scan-DirectoryForSensitiveFiles -DirectoryPath $matchingDir.FullName -UserContext $UserContext
                    $allSensitiveFiles += $sensitiveFiles
                }
            } else {
                $sensitiveFiles = Scan-DirectoryForSensitiveFiles -DirectoryPath $directoryPath -UserContext $UserContext
                $allSensitiveFiles += $sensitiveFiles
            }
        }
        
        # Also scan the root of the user profile for sensitive files
        $rootSensitiveFiles = Scan-DirectoryForSensitiveFiles -DirectoryPath $UserProfilePath -UserContext $UserContext
        $allSensitiveFiles += $rootSensitiveFiles
        
    } catch {
        Write-Log "Error scanning user profile $UserContext`: $($_.Exception.Message)" -Level "ERROR"
    }
    
    return $allSensitiveFiles
}

# Function to generate security assessment
Function Get-SecurityAssessment {
    param(
        [array]$SensitiveFiles
    )
    
    Write-Log "Generating security assessment" -Level "INFO"
    
    $assessment = @{
        TotalSensitiveFiles = $SensitiveFiles.Count
        HighSeverityFiles = @()
        MediumSeverityFiles = @()
        LowSeverityFiles = @()
        FilesByCategory = @{}
        SecurityRecommendations = @()
        RiskLevel = 'Low'
    }
    
    # Categorize files by severity
    foreach ($file in $SensitiveFiles) {
        switch ($file.Severity) {
            'High' {
                $assessment.HighSeverityFiles += $file
            }
            'Medium' {
                $assessment.MediumSeverityFiles += $file
            }
            'Low' {
                $assessment.LowSeverityFiles += $file
            }
        }
        
        # Categorize by pattern category
        if (-not $assessment.FilesByCategory.ContainsKey($file.PatternCategory)) {
            $assessment.FilesByCategory[$file.PatternCategory] = @()
        }
        $assessment.FilesByCategory[$file.PatternCategory] += $file
    }
    
    # Determine overall risk level
    if ($assessment.HighSeverityFiles.Count -gt 0) {
        $assessment.RiskLevel = 'High'
    } elseif ($assessment.MediumSeverityFiles.Count -gt 5) {
        $assessment.RiskLevel = 'Medium'
    } elseif ($assessment.MediumSeverityFiles.Count -gt 0) {
        $assessment.RiskLevel = 'Low'
    } else {
        $assessment.RiskLevel = 'Minimal'
    }
    
    # Generate security recommendations
    if ($assessment.HighSeverityFiles.Count -gt 0) {
        $assessment.SecurityRecommendations += "IMMEDIATE ACTION REQUIRED: Remove or secure high-severity sensitive files"
        $assessment.SecurityRecommendations += "Review and delete files containing actual passwords or credentials"
    }
    
    if ($assessment.MediumSeverityFiles.Count -gt 0) {
        $assessment.SecurityRecommendations += "Review medium-severity files for sensitive information"
        $assessment.SecurityRecommendations += "Consider moving sensitive files to secure locations"
    }
    
    $assessment.SecurityRecommendations += "Implement enterprise password management solution"
    $assessment.SecurityRecommendations += "Provide user training on secure file storage practices"
    $assessment.SecurityRecommendations += "Implement file scanning and monitoring solutions"
    $assessment.SecurityRecommendations += "Review and update data handling policies"
    
    return $assessment
}

# =============================================================================
# USER PROFILE ENUMERATION AND PROCESSING SECTION
# =============================================================================

Write-Log "Enumerating local user profiles for sensitive credential detection" -Level "INFO"

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
$allSensitiveFiles = @()
$totalUsersProcessed = 0

# Process each user profile
foreach ($profile in $profileRoots) {
    $userName = $profile.Name
    
    Write-Log "=== Processing user profile: $userName ===" -Level "INFO"
    $totalUsersProcessed++
    
    try {
        # Scan user profile for sensitive credentials
        $userSensitiveFiles = Scan-UserProfileForSensitiveCredentials -UserProfilePath $profile.FullName -UserContext $userName
        $allSensitiveFiles += $userSensitiveFiles
        
        Write-Log "Found $($userSensitiveFiles.Count) sensitive files for user: $userName" -Level "INFO"
        Write-Log "Completed processing for user: $userName" -Level "INFO"
        
    } catch {
        Write-Log "Error processing user $userName`: $($_.Exception.Message)" -Level "ERROR"
    }
}

# =============================================================================
# SECURITY ASSESSMENT AND REPORTING SECTION
# =============================================================================

Write-Log "Generating comprehensive security assessment" -Level "INFO"

$securityAssessment = Get-SecurityAssessment -SensitiveFiles $allSensitiveFiles

# Generate detailed report if requested
if ($DetailedScan) {
    Write-Log "=== DETAILED SECURITY ASSESSMENT REPORT ===" -Level "INFO"
    Write-Log "Total Users Processed: $totalUsersProcessed" -Level "INFO"
    Write-Log "Total Sensitive Files Found: $($securityAssessment.TotalSensitiveFiles)" -Level "INFO"
    Write-Log "Overall Risk Level: $($securityAssessment.RiskLevel)" -Level "INFO"
    
    Write-Log "High Severity Files: $($securityAssessment.HighSeverityFiles.Count)" -Level "INFO"
    foreach ($file in $securityAssessment.HighSeverityFiles) {
        Write-Log "  - $($file.FilePath) (Category: $($file.PatternCategory))" -Level "INFO"
    }
    
    Write-Log "Medium Severity Files: $($securityAssessment.MediumSeverityFiles.Count)" -Level "INFO"
    foreach ($file in $securityAssessment.MediumSeverityFiles) {
        Write-Log "  - $($file.FilePath) (Category: $($file.PatternCategory))" -Level "INFO"
    }
    
    Write-Log "Files by Category:" -Level "INFO"
    foreach ($category in $securityAssessment.FilesByCategory.Keys) {
        Write-Log "  - $category`: $($securityAssessment.FilesByCategory[$category].Count) files" -Level "INFO"
    }
    
    Write-Log "Security Recommendations:" -Level "INFO"
    foreach ($recommendation in $securityAssessment.SecurityRecommendations) {
        Write-Log "  - $recommendation" -Level "INFO"
    }
}

# Export results to CSV if requested
if ($ExportResults) {
    $exportPath = Join-Path $logRoot "sensitive-credential-detection-results.csv"
    
    try {
        # Export sensitive files results
        $exportData = $allSensitiveFiles | Select-Object FilePath, FileName, FileSize, LastModified, PatternCategory, Pattern, Severity, UserContext, ContentMatches
        $exportData | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
        
        Write-Log "Results exported to: $exportPath" -Level "INFO"
        
    } catch {
        Write-Log "Failed to export results: $($_.Exception.Message)" -Level "ERROR"
    }
}

# =============================================================================
# EXECUTION SUMMARY AND COMPLETION SECTION
# =============================================================================

Write-Log "=== Sensitive Credential Detection Script Execution Summary ===" -Level "INFO"
Write-Log "Script Version: 1.0.0" -Level "INFO"
Write-Log "Designed by Michael Nancarrow" -Level "INFO"
Write-Log "Total Users Processed: $totalUsersProcessed" -Level "INFO"
Write-Log "Total Sensitive Files Found: $($securityAssessment.TotalSensitiveFiles)" -Level "INFO"
Write-Log "High Severity Files: $($securityAssessment.HighSeverityFiles.Count)" -Level "INFO"
Write-Log "Medium Severity Files: $($securityAssessment.MediumSeverityFiles.Count)" -Level "INFO"
Write-Log "Overall Risk Level: $($securityAssessment.RiskLevel)" -Level "INFO"

if ($securityAssessment.RiskLevel -eq 'High') {
    Write-Log "WARNING: High risk level detected - immediate action required" -Level "WARNING"
} elseif ($securityAssessment.RiskLevel -eq 'Medium') {
    Write-Log "WARNING: Medium risk level detected - review recommended" -Level "WARNING"
}

Write-Log "Script execution completed successfully" -Level "INFO"
Write-Log "=== Sensitive Credential Detection Script Ended ===" -Level "INFO"

# Exit with success code
exit 0
