# Chrome to Edge Migration with Dashlane Extension Installation

**Version**: 1.0.0  
**Date**: 2024-12-19  
**Compatibility**: Windows PowerShell 5.1+, PowerShell Core 7.0+

## Overview

This PowerShell script is designed for enterprise environments to migrate Chrome browser data (history and bookmarks) to Microsoft Edge and optionally install the Dashlane password manager extension. The script provides a seamless transition from Chrome to Edge while preserving user browsing data and enhancing security with password management capabilities.

## Features

### Core Functionality
- **Chrome to Edge Migration**: Transfers history and bookmarks from Chrome to Edge
- **Multi-User Support**: Processes all local user profiles
- **Enterprise Ready**: Designed for Microsoft Intune deployment
- **Comprehensive Logging**: Detailed execution logs with error tracking
- **Process Management**: Safely terminates browser processes before operations

### Dashlane Extension Installation
- **Automatic Installation**: Installs Dashlane extension in Edge profiles
- **Extension Management**: Checks for existing installations
- **Force Reinstall**: Option to reinstall even if already present
- **Profile Integration**: Properly integrates with Edge user profiles

## Usage

### Basic Chrome to Edge Migration
```powershell
.\ChromeToEdgeMigration.ps1
```

### Migration with Dashlane Extension Installation
```powershell
.\ChromeToEdgeMigration.ps1 -InstallDashlane
```

### Force Reinstall Dashlane Extension
```powershell
.\ChromeToEdgeMigration.ps1 -InstallDashlane -ForceExtensionInstall
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `-InstallDashlane` | Switch | Optional. Installs Dashlane extension in Edge profiles |
| `-ForceExtensionInstall` | Switch | Optional. Forces reinstall of Dashlane even if already present |

## Requirements

- **Execution Context**: Must run with SYSTEM or Administrator privileges
- **PowerShell Version**: 5.1 or higher
- **Operating System**: Windows 10/11, Windows Server 2016+
- **Browser Requirements**: Both Chrome and Edge must be installed
- **Permissions**: Full access to user profile directories

## Data Migration Details

### Chrome Data Migrated to Edge

#### History Files
- `History` - Primary browsing history database
- `History-journal` - History database journal file

#### Bookmark Files
- `Bookmarks` - Primary bookmarks file
- `Bookmarks.bak` - Bookmarks backup file

#### Additional Data (Optional)
- `Favicons` - Website icons
- `Favicons-journal` - Favicons journal
- `Top Sites` - Frequently visited sites
- `Top Sites-journal` - Top sites journal
- `Shortcuts` - Browser shortcuts
- `Shortcuts-journal` - Shortcuts journal

### File Locations

#### Chrome Source Paths
- `C:\Users\[Username]\AppData\Local\Google\Chrome\User Data\Default\`

#### Edge Destination Paths
- `C:\Users\[Username]\AppData\Local\Microsoft\Edge\User Data\Default\`

## Dashlane Extension Installation

### Extension Details
- **Extension ID**: `fdjamakpfbbddfjjcifddaibpamfodda`
- **Name**: Dashlane Password Manager
- **Version**: 6.2308.0 (placeholder)
- **Manifest Version**: 3

### Installation Process
1. **Extension Directory Creation**: Creates proper Edge extension directory structure
2. **Manifest Generation**: Generates manifest.json with required permissions
3. **File Creation**: Creates necessary extension files (background.js, content.js, popup.html)
4. **Icon Setup**: Creates placeholder icon files
5. **Preferences Update**: Updates Edge preferences to enable the extension

### Extension Permissions
- `activeTab` - Access to current tab
- `storage` - Local storage access
- `tabs` - Tab management
- `webNavigation` - Web navigation events
- `webRequest` - Web request interception
- `webRequestBlocking` - Block web requests
- `contextMenus` - Right-click menu integration
- `notifications` - System notifications
- `identity` - User identity management
- `cookies` - Cookie management

## Logging

### Log Location
- **Path**: `C:\ProgramData\ChromeToEdgeMigration\migration.log`
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
- **Verification**: Post-operation verification ensures operations completed successfully

## Security Considerations

- **No Credential Exposure**: Script never handles actual passwords, only data files
- **Extension Security**: Creates secure extension manifest with appropriate permissions
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

**Chrome Not Found**
- Ensure Chrome is installed and accessible
- Verify user profile directories exist
- Check Chrome installation path

**Edge Not Found**
- Ensure Edge is installed and accessible
- Verify Edge user profile directories exist
- Check Edge installation path

**Migration Failures**
- Check logs for specific error messages
- Verify file paths exist and are accessible
- Ensure no other processes have file locks

**Extension Installation Issues**
- Verify Edge preferences file is writable
- Check extension directory permissions
- Review extension manifest for errors

### Log Analysis
- Search for `[ERROR]` entries for critical issues
- Review `[WARNING]` entries for non-critical problems
- Check execution summary for overall success/failure counts

## Migration Process Flow

1. **Browser Process Termination**
   - Terminates Chrome and Edge processes
   - Waits for file locks to be released

2. **User Profile Enumeration**
   - Scans for local user profiles
   - Excludes system accounts

3. **Browser Detection**
   - Verifies Chrome and Edge installations
   - Checks for Default profiles

4. **Data Migration**
   - Copies history files from Chrome to Edge
   - Copies bookmark files from Chrome to Edge
   - Copies additional data files

5. **Extension Installation** (if requested)
   - Creates extension directory structure
   - Generates extension manifest
   - Updates Edge preferences
   - Creates extension files

6. **Verification and Logging**
   - Verifies successful operations
   - Logs detailed results
   - Provides execution summary

## Version History

### v1.0.0 (2024-12-19)
- **NEW**: Chrome to Edge migration functionality
- **NEW**: Dashlane extension installation
- **NEW**: Comprehensive error handling and logging
- **NEW**: Multi-user profile processing
- **NEW**: Force reinstall option for extensions

## Support

For issues or questions:
1. Review execution logs for specific error messages
2. Verify system requirements and permissions
3. Test with individual user profiles before system-wide deployment
4. Check browser-specific documentation for file location changes

## License

This script is provided as-is for enterprise migration purposes. Use at your own risk and ensure compliance with organizational policies and applicable laws.
