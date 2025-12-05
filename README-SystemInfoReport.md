# PowerShell System Information Collector

A comprehensive PowerShell script that collects detailed system information using parallel execution and generates a beautiful HTML report.

## Features

### 📊 Information Collected

- **User Information**: Current user, logged-on users, recent logons
- **Host Information**: Computer name, domain, manufacturer, model, OS details, BIOS info
- **System Resources**: CPU usage, memory usage, disk space, uptime
- **Network Information**: Active adapters, IP addresses (IPv4/IPv6), MAC addresses, link speeds, public IP
- **DNS Information**: DNS servers, DNS cache entries
- **Firewall Status**: Firewall profiles, active rules
- **Installed Applications**: Traditional desktop apps and modern Windows apps
- **Windows Services**: Running services, stopped automatic services
- **Event Logs**: Recent system errors, application errors, security audits
- **Windows Updates**: Pending updates, recently installed hotfixes

### ⚡ Performance Features

- **Parallel Execution**: Uses PowerShell runspaces to collect data concurrently
- **Fast Collection**: 10 concurrent data collection tasks
- **Efficient Output**: Single HTML file with embedded CSS styling

## Requirements

- **Operating System**: Windows 10/11 or Windows Server 2016+
- **PowerShell**: Version 5.1 or higher
- **Permissions**: Administrator privileges recommended for full data access

## Usage

### Basic Usage

```powershell
# Run with default settings (creates report in current directory)
.\Get-SystemInfoReport.ps1
```

### Custom Output Path

```powershell
# Specify custom output location
.\Get-SystemInfoReport.ps1 -OutputPath "C:\Reports\MySystemReport.html"
```

### Running as Administrator

For complete information collection, run PowerShell as Administrator:

1. Right-click PowerShell
2. Select "Run as Administrator"
3. Navigate to the script directory
4. Execute the script

## Output

The script generates an HTML file with:

- **Professional Design**: Modern, responsive layout with gradient styling
- **Organized Sections**: Information grouped by category
- **Visual Metrics**: Key metrics displayed in card format
- **Color-Coded Status**: Green/yellow/red indicators for health status
- **Sortable Data**: Tables with alternating row colors for easy reading
- **Auto-Open**: Report automatically opens in default browser

### Default Output Filename

```
SystemInfo_<ComputerName>_<Timestamp>.html
```

Example: `SystemInfo_DESKTOP-ABC123_20231205_143022.html`

## Examples

### Example 1: Quick System Check

```powershell
.\Get-SystemInfoReport.ps1
```

Output: Report saved to current directory and opened in browser

### Example 2: Scheduled Report

```powershell
# Create report in specific location for scheduled task
.\Get-SystemInfoReport.ps1 -OutputPath "C:\Reports\Daily\SystemReport_$(Get-Date -Format 'yyyyMMdd').html"
```

### Example 3: Network Share

```powershell
# Save to network location
.\Get-SystemInfoReport.ps1 -OutputPath "\\server\share\Reports\SystemInfo.html"
```

## Execution Policy

If you encounter execution policy errors, you may need to adjust your PowerShell execution policy:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or bypass for single execution
powershell.exe -ExecutionPolicy Bypass -File .\Get-SystemInfoReport.ps1
```

## Troubleshooting

### Permission Errors

Some data collection requires administrator privileges:
- Event Logs (Security log especially)
- Windows Update information
- Some service details

**Solution**: Run PowerShell as Administrator

### COM Object Errors (Windows Update)

If Windows Update collection fails:
- Ensure Windows Update service is running
- Check COM object registration
- Try running `wuauclt /detectnow` first

### Network Timeout

If public IP detection times out:
- The script will show "Unable to retrieve" and continue
- This doesn't affect other data collection

## Performance

Typical execution time: **15-30 seconds** (varies by system)

Performance breakdown:
- Data collection (parallel): 10-20 seconds
- HTML generation: 2-5 seconds
- File writing: <1 second

## Customization

### Modify Data Collection

Edit the `$scriptBlocks` hashtable to add/remove collectors:

```powershell
$scriptBlocks = @{
    'CustomData' = {
        # Your custom collection code
    }
}
```

### Adjust Limits

Change the number of items collected:

```powershell
# Example: Change from 20 to 50 event log entries
$systemErrors = Get-EventLog -LogName System -EntryType Error -Newest 50
```

### Styling

Modify the CSS in the HTML generation section to customize appearance.

## Security Considerations

- **Sensitive Data**: Report may contain sensitive information (IP addresses, user names, installed software)
- **Storage**: Store reports in secure locations
- **Sharing**: Redact sensitive information before sharing
- **Cleanup**: Regularly delete old reports

## Changelog

### Version 1.0.0
- Initial release
- Parallel execution with runspaces
- Comprehensive system information collection
- HTML report generation with modern styling
- Auto-open in browser

## License

This script is provided as-is for system administration purposes.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Verify PowerShell version compatibility
3. Ensure adequate permissions
4. Review error messages in console output

## Contributing

Suggestions for additional data collection or improvements are welcome!
