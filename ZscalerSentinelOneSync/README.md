# Zscaler to SentinelOne Firewall Sync

A cross-platform PowerShell script that automatically synchronizes Zscaler IP ranges to SentinelOne Firewall Control policies.

## Features

- **Multi-Endpoint Support**: Fetches IP ranges from three Zscaler API endpoints:
  - Hub IPs (`/hubs/cidr/json/required`)
  - Aggregate/Future IPs (`/future/json`)
  - ZEN IPs (`/cenr/json`)
- **IPv4 and IPv6 Support**: Handles both IPv4 and IPv6 CIDR ranges
- **Protocol Coverage**: Creates rules for both TCP/443 and UDP/443
- **Change Detection**: Maintains a local cache to only apply changes when new ranges are detected
- **Comprehensive Logging**: Detailed logs with timestamps and severity levels
- **Dry Run Mode**: Preview changes without actually applying them
- **Cross-Platform**: Works on Windows, macOS, and Linux (requires PowerShell 7+)
- **Retry Logic**: Built-in retry with exponential backoff for API reliability

## Requirements

- **PowerShell 7.0+** (for cross-platform compatibility)
  - Windows: Pre-installed or download from [PowerShell GitHub](https://github.com/PowerShell/PowerShell)
  - macOS: `brew install powershell` or download from GitHub
  - Linux: See [installation docs](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux)
- **SentinelOne Management Console** with Firewall Control enabled
- **SentinelOne API Token** with firewall management permissions

## Installation

1. Clone or download this repository
2. Ensure PowerShell 7+ is installed:
   ```bash
   # Check version
   pwsh --version
   ```

## Usage

### Basic Usage

```powershell
./Sync-ZscalerToSentinelOneFirewall.ps1 `
    -SentinelOneApiUrl "https://usea1.sentinelone.net" `
    -SentinelOneApiToken "your-api-token" `
    -ScopeType "site" `
    -ScopeId "123456789012345678"
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `SentinelOneApiUrl` | Yes | Base URL of your SentinelOne Management Console |
| `SentinelOneApiToken` | Yes | API token for authentication |
| `ScopeType` | Yes | Rule scope: `site`, `group`, `account`, or `tenant` |
| `ScopeId` | Conditional | ID of the scope (not required for `tenant` scope) |
| `CacheFilePath` | No | Path to cache file (default: script directory) |
| `LogFilePath` | No | Path to log file (default: script directory) |
| `RuleNamePrefix` | No | Prefix for rule names (default: `Zscaler-AutoManaged`) |
| `DryRun` | No | Preview changes without applying |
| `Force` | No | Bypass cache and force full sync |

### Examples

**Dry Run (Preview Changes)**
```powershell
./Sync-ZscalerToSentinelOneFirewall.ps1 `
    -SentinelOneApiUrl "https://usea1.sentinelone.net" `
    -SentinelOneApiToken "your-token" `
    -ScopeType "tenant" `
    -DryRun
```

**Force Full Sync**
```powershell
./Sync-ZscalerToSentinelOneFirewall.ps1 `
    -SentinelOneApiUrl "https://usea1.sentinelone.net" `
    -SentinelOneApiToken "your-token" `
    -ScopeType "site" `
    -ScopeId "123456789012345678" `
    -Force
```

**Custom Rule Prefix and Log Location**
```powershell
./Sync-ZscalerToSentinelOneFirewall.ps1 `
    -SentinelOneApiUrl "https://usea1.sentinelone.net" `
    -SentinelOneApiToken "your-token" `
    -ScopeType "group" `
    -ScopeId "987654321098765432" `
    -RuleNamePrefix "Zscaler-Production" `
    -LogFilePath "/var/log/zscaler-sync.log" `
    -CacheFilePath "/var/cache/zscaler-cache.json"
```

## Rule Naming Convention

Rules are created with the following naming pattern:
```
{RuleNamePrefix}-{IpVersion}-{Protocol}-{Port}-{SanitizedCIDR}
```

Example:
```
Zscaler-AutoManaged-IPv4-TCP-443-185-46-212-0-22
Zscaler-AutoManaged-IPv6-UDP-443-2a03-f80--22
```

## Cache File Structure

The cache file (`zscaler-sentinelone-cache.json`) stores:
- Last sync timestamp
- All synced IPv4 and IPv6 ranges
- Rule metadata for tracking

Example:
```json
{
  "LastSync": "2024-01-15T10:30:00Z",
  "IPv4Ranges": ["185.46.212.0/22", "147.161.128.0/17"],
  "IPv6Ranges": ["2a03:f80::/29"],
  "TotalCount": 150,
  "SyncedRules": [...],
  "Version": "1.0"
}
```

## Logging

The script provides comprehensive logging with severity levels:
- `INFO`: General operational messages
- `SUCCESS`: Successful operations
- `WARNING`: Non-critical issues or dry-run actions
- `ERROR`: Failed operations
- `DEBUG`: Detailed debugging information

Logs are written to both console (with color coding) and log file.

## Scheduling

### Windows (Task Scheduler)
```powershell
# Create a scheduled task to run daily at 2 AM
$Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File C:\Scripts\Sync-ZscalerToSentinelOneFirewall.ps1 -SentinelOneApiUrl https://usea1.sentinelone.net -SentinelOneApiToken your-token -ScopeType tenant"
$Trigger = New-ScheduledTaskTrigger -Daily -At "2:00AM"
Register-ScheduledTask -TaskName "Zscaler-SentinelOne-Sync" -Action $Action -Trigger $Trigger
```

### macOS/Linux (cron)
```bash
# Edit crontab
crontab -e

# Add entry for daily sync at 2 AM
0 2 * * * /usr/local/bin/pwsh /path/to/Sync-ZscalerToSentinelOneFirewall.ps1 -SentinelOneApiUrl "https://usea1.sentinelone.net" -SentinelOneApiToken "your-token" -ScopeType "tenant" >> /var/log/zscaler-sync-cron.log 2>&1
```

### macOS (launchd)
Create a plist file at `~/Library/LaunchAgents/com.zscaler.sentinelone.sync.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.zscaler.sentinelone.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/pwsh</string>
        <string>/path/to/Sync-ZscalerToSentinelOneFirewall.ps1</string>
        <string>-SentinelOneApiUrl</string>
        <string>https://usea1.sentinelone.net</string>
        <string>-SentinelOneApiToken</string>
        <string>your-token</string>
        <string>-ScopeType</string>
        <string>tenant</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
```

Load with: `launchctl load ~/Library/LaunchAgents/com.zscaler.sentinelone.sync.plist`

## Security Considerations

1. **API Token Security**: Store the SentinelOne API token securely:
   - Use environment variables
   - Use a secrets manager (HashiCorp Vault, AWS Secrets Manager, etc.)
   - Use Windows Credential Manager or macOS Keychain

2. **Least Privilege**: Create a SentinelOne API token with minimal required permissions:
   - Read firewall rules
   - Create firewall rules
   - Delete firewall rules

3. **Log File Security**: Ensure log files don't contain sensitive information and have appropriate permissions

## Troubleshooting

### Common Issues

**"PowerShell version too old"**
- Install PowerShell 7+: https://github.com/PowerShell/PowerShell/releases

**"Failed to fetch Zscaler data"**
- Check network connectivity to `config.zscaler.com`
- Verify firewall allows outbound HTTPS

**"SentinelOne API authentication failed"**
- Verify API token is valid and not expired
- Check API token has correct permissions
- Verify SentinelOne URL is correct

**"No IP ranges retrieved"**
- Zscaler API may be temporarily unavailable
- Check for API response format changes

## Zscaler API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/api/zscaler.net/hubs/cidr/json/required` | Hub IP addresses in CIDR format |
| `/api/zscaler.net/future/json` | Future/aggregate data center IPs |
| `/api/zscaler.net/cenr/json` | Cloud Enforcement Node Ranges (ZEN IPs) |

## SentinelOne API Reference

- API Version: v2.1
- Endpoint: `/web/api/v2.1/firewall-control`
- Documentation: Available in your SentinelOne Management Console under Settings > API Documentation

## License

This script is provided as-is for internal use. Modify as needed for your environment.

## Contributing

1. Test changes in dry-run mode first
2. Verify against your specific SentinelOne and Zscaler configurations
3. Submit issues or improvements via pull request
