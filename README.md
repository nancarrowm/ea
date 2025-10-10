# Browser Password Purge with Profile Migration

**Version**: 2.0.0  
**Author**: Enhanced by AI Assistant  
**Date**: 2024-12-19  
**Compatibility**: Windows PowerShell 5.1+, PowerShell Core 7.0+

## Overview

This PowerShell script is designed for enterprise environments to systematically remove saved browser passwords from Microsoft Edge, Google Chrome, and Mozilla Firefox installations across all local user profiles. The script includes an optional Chrome profile migration feature that preserves user data (history, cookies, cache, bookmarks) while removing password databases.

## Features

### Core Functionality
- **Multi-Browser Support**: Edge (Chromium), Chrome, Firefox
- **System-Wide Processing**: Processes all local user profiles
- **Enterprise Ready**: Designed for Microsoft Intune deployment
- **Comprehensive Logging**: Detailed execution logs with error tracking
- **Process Management**: Safely terminates browser processes before file operations

### Chrome Profile Migration (New in v2.0.0)
- **Data Preservation**: Maintains browsing history, cookies, cache, bookmarks, extensions
- **Password Removal**: Completely removes password databases
- **Backup Creation**: Creates timestamped backups of original profiles
- **Safe Migration**: Atomic operations with rollback capability

## Usage

### Standard Password Removal
```powershell
.\Remove-StoredBrowserPasswords.ps1
```

### Chrome Profile Migration
```powershell
.\Remove-StoredBrowserPasswords.ps1 -MigrateChromeProfiles
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-MigrateChromeProfiles` | Switch | Optional. When specified, migrates Chrome profiles instead of just deleting passwords |

## Requirements

- **Execution Context**: Must run with SYSTEM privileges
- **PowerShell Version**: 5.1 or higher
- **Operating System**: Windows 10/11, Windows Server 2016+
- **Permissions**: Full access to user profile directories

## File Locations Processed

### Microsoft Edge (Chromium)
- `C:\Users\[Username]\AppData\Local\Microsoft\Edge\User Data\[Profile]\Login Data*`

### Google Chrome
- `C:\Users\[Username]\AppData\Local\Google\Chrome\User Data\[Profile]\Login Data*`

### Mozilla Firefox
- `C:\Users\[Username]\AppData\Roaming\Mozilla\Firefox\Profiles\[Profile]\logins.json`
- `C:\Users\[Username]\AppData\Roaming\Mozilla\Firefox\Profiles\[Profile]\signons.sqlite*`
- `C:\Users\[Username]\AppData\Roaming\Mozilla\Firefox\Profiles\[Profile]\key*.db`

## Logging

### Log Location
- **Path**: `C:\ProgramData\BrowserPasswordPurge\purge.log`
- **Format**: Structured logging with timestamps and severity levels
- **Encoding**: UTF-8 for international character support

### Log Levels
- **INFO**: General operational information
- **WARNING**: Non-critical issues that don't stop execution
- **ERROR**: Critical errors that may affect functionality
- **DEBUG**: Detailed debugging information

## Chrome Profile Migration Details

When using the `-MigrateChromeProfiles` parameter, the script:

1. **Creates Backup**: Original profile moved to timestamped backup directory
2. **Copies Data**: Preserves the following data types:
   - Browsing history and journal files
   - Cookies and session data
   - Bookmarks and favorites
   - Browser cache and GPU cache
   - Extensions and their data
   - User preferences and settings
   - Local storage and IndexedDB
3. **Removes Passwords**: Deletes all password-related files
4. **Atomic Replacement**: Replaces original profile with migrated version

### Preserved Data Types
- History (`History`, `History-journal`)
- Cookies (`Cookies`, `Cookies-journal`)
- Bookmarks (`Bookmarks`, `Bookmarks.bak`)
- Cache (`Cache`, `Code Cache`, `GPUCache`, `ShaderCache`)
- Extensions (`Default\Extensions`)
- Preferences (`Preferences`, `Secure Preferences`)
- Local Storage (`Default\Local Storage`, `Default\Session Storage`)
- IndexedDB (`Default\IndexedDB`, `Default\databases`)

## Error Handling

The script implements comprehensive error handling:

- **Process Termination**: Graceful handling of browser process termination failures
- **File Operations**: Individual file operation failures don't stop overall execution
- **Profile Processing**: User profile processing continues even if individual profiles fail
- **Verification**: Post-deletion verification ensures operations completed successfully

## Security Considerations

- **No Credential Exposure**: Script never handles actual passwords, only database files
- **Backup Safety**: Original profiles backed up before modification
- **Audit Trail**: Comprehensive logging for compliance and troubleshooting
- **System Account**: Designed to run with SYSTEM privileges for maximum access

## Deployment

### Microsoft Intune
1. Package script as `.ps1` file
2. Deploy as PowerShell script
3. Configure to run with SYSTEM privileges
4. Monitor logs for execution results

### Manual Execution
1. Run PowerShell as Administrator
2. Execute script with appropriate parameters
3. Review logs for completion status

## Troubleshooting

### Common Issues

**Permission Denied**
- Ensure script runs with SYSTEM privileges
- Verify user profile directories are accessible

**Browser Processes Running**
- Script automatically terminates browser processes
- Wait 5 seconds after termination before file operations

**Incomplete Deletion**
- Check logs for specific error messages
- Verify file paths exist and are accessible
- Ensure no other processes have file locks

### Log Analysis
- Search for `[ERROR]` entries for critical issues
- Review `[WARNING]` entries for non-critical problems
- Check execution summary for overall success/failure counts

## Version History

### v2.0.0 (2024-12-19)
- **NEW**: Chrome profile migration feature
- **ENHANCED**: Comprehensive Firefox key database handling
- **IMPROVED**: Structured error handling and logging
- **ADDED**: Process termination timing and verification
- **ENHANCED**: Verbose commenting throughout script
- **ADDED**: Execution summary and statistics

### v1.0.0 (Original)
- Basic password file deletion for Edge, Chrome, Firefox
- Simple logging functionality
- Basic error handling

## Support

For issues or questions:
1. Review execution logs for specific error messages
2. Verify system requirements and permissions
3. Test with individual user profiles before system-wide deployment
4. Check browser-specific documentation for file location changes

## License

This script is provided as-is for enterprise security purposes. Use at your own risk and ensure compliance with organizational policies and applicable laws.
