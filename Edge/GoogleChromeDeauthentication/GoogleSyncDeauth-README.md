# Google Sync Detection and De-authentication Script

**Version**: 1.1.0  
**Date**: 2024-12-19  
**Compatibility**: Windows PowerShell 5.1+, PowerShell Core 7.0+

## Overview

This PowerShell script is designed for enterprise environments to detect Google Sync status in Chrome browsers and de-authenticate users before password deletion operations. The script ensures that cloud-synced passwords are not restored after local password deletion by breaking the sync connection and clearing authentication tokens.

## Features

### Core Functionality
- **Chrome Sync Detection**: Detects Google account sync status in Chrome browsers
- **Account Detection**: Identifies signed-in Google accounts
- **De-authentication**: Safely de-authenticates users and disables sync
- **Token Cleanup**: Removes authentication tokens and account data
- **Multi-User Support**: Processes all local user profiles
- **Enterprise Ready**: Designed for Microsoft Intune deployment

## Usage

### Basic Sync Detection and De-authentication
```powershell
.\GoogleSyncDeauth.ps1
```

### Force De-authentication (Skip Detection)
```powershell
.\GoogleSyncDeauth.ps1 -ForceDeauth
```

### Skip Detection and Force De-authentication
```powershell
.\GoogleSyncDeauth.ps1 -SkipDetection
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-ForceDeauth` | Switch | Optional. Forces de-authentication even if sync appears disabled |
| `-SkipDetection` | Switch | Optional. Skips sync detection and proceeds directly to de-authentication |

## Requirements

- **Execution Context**: Must run with SYSTEM or Administrator privileges
- **PowerShell Version**: 5.1 or higher
- **Operating System**: Windows 10/11, Windows Server 2016+
- **Browser Requirements**: Chrome must be installed
- **Permissions**: Full access to user profile directories

## Sync Detection Details

### Chrome Sync Detection
The script analyzes Chrome preferences to detect:
- **Account Sign-in Status**: Whether a Google account is signed in
- **Sync Enabled Status**: Whether sync is currently enabled
- **Sync Data Types**: What data is being synced (passwords, bookmarks, history, etc.)
- **Last Sync Time**: When the last sync occurred
- **Account Email**: The email address of the signed-in account

### File Locations Analyzed

#### Chrome Preferences
- `C:\Users\[Username]\AppData\Local\Google\Chrome\User Data\Default\Preferences`

## De-authentication Process

### Chrome De-authentication
1. **Disable Sync**: Sets `sync_enabled` to `false` in preferences
2. **Clear Account Info**: Removes account information from preferences
3. **Disable Sign-in**: Sets sign-in to not allowed
4. **Remove Tokens**: Deletes Google account picture files
5. **Clean Account Data**: Removes Google Account Pictures directory

## Logging

### Log Location
- **Path**: `C:\ProgramData\GoogleSyncDeauth\sync-deauth.log`
- **Format**: Structured logging with timestamps and severity levels
- **Encoding**: UTF-8 for international character support

### Log Levels
- **INFO**: General operational information
- **WARNING**: Non-critical issues that don't stop execution
- **ERROR**: Critical errors that may affect functionality
- **DEBUG**: Detailed debugging information

## Error Handling

The script implements comprehensive error handling:

- **Process Termination**: Graceful handling of browser process termination failures
- **File Operations**: Individual file operation failures don't stop overall execution
- **Profile Processing**: User profile processing continues even if individual profiles fail
- **JSON Parsing**: Handles corrupted or invalid preference files
- **Verification**: Post-operation verification ensures operations completed successfully

## Security Considerations

- **No Credential Exposure**: Script never handles actual passwords, only sync settings
- **Token Cleanup**: Removes authentication tokens to prevent re-authentication
- **Account Data Removal**: Clears account-related data files
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

**Sync Detection Failures**
- Check browser installation paths
- Verify user profile directories exist
- Review preference file permissions

**De-authentication Failures**
- Ensure script runs with sufficient privileges
- Check file system permissions
- Verify preference files are not locked

**Account Data Not Cleared**
- Check for running browser processes
- Verify file system access
- Review error logs for specific issues

### Log Analysis
- Search for `[ERROR]` entries for critical issues
- Review `[WARNING]` entries for non-critical problems
- Check execution summary for overall success/failure counts
- Look for sync detection results and account information

## Integration with Password Deletion

### Recommended Workflow
1. **Run GoogleSyncDeauth.ps1**: Detect and de-authenticate sync
2. **Run Remove-StoredBrowserPasswords.ps1**: Delete local passwords
3. **Verify Results**: Check logs for successful completion

### Why This Order Matters
- **Prevents Re-sync**: De-authentication prevents cloud passwords from being restored
- **Clean Slate**: Ensures local password deletion is permanent
- **User Experience**: Users will need to re-authenticate, providing opportunity to use password manager

## Sync Data Types Detected

### Chrome Sync Data Types
- **passwords**: Saved passwords
- **bookmarks**: Bookmarks and favorites
- **history**: Browsing history
- **tabs**: Open tabs
- **preferences**: Browser preferences
- **extensions**: Installed extensions
- **themes**: Browser themes
- **apps**: Installed web apps

## User Impact

### After De-authentication
- **Sign-out Required**: Users will be signed out of their Chrome accounts
- **Sync Disabled**: Chrome sync will be disabled
- **Re-authentication**: Users will need to sign back in if they want to use sync
- **Password Manager**: Opportunity to introduce enterprise password manager

### User Communication
- **Advance Notice**: Inform users about the de-authentication process
- **Password Manager**: Provide guidance on using enterprise password manager
- **Re-authentication**: Explain how to sign back in if needed
- **Support**: Provide contact information for assistance

## Version History

### v1.1.0 (2024-12-19)
- **CHANGED**: Removed Edge de-authentication functionality
- **FOCUSED**: Chrome-only sync detection and de-authentication
- **UPDATED**: Documentation and logging to reflect Chrome-only operation

### v1.0.0 (2024-12-19)
- **NEW**: Google Sync detection functionality
- **NEW**: Chrome and Edge de-authentication
- **NEW**: Comprehensive error handling and logging
- **NEW**: Multi-user profile processing
- **NEW**: Force de-authentication options

## Support

For issues or questions:
1. Review execution logs for specific error messages
2. Verify system requirements and permissions
3. Test with individual user profiles before system-wide deployment
4. Check browser-specific documentation for preference file changes

## License

This script is provided as-is for enterprise security purposes. Use at your own risk and ensure compliance with organizational policies and applicable laws.
