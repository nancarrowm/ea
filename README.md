# Enterprise Automation Scripts

A collection of PowerShell scripts for enterprise automation tasks. Each script is organized in its own folder with documentation.

## Repository Structure

```
ea/
├── Edge/                           # Microsoft Edge browser management scripts
│   ├── GoogleChromeDeauthentication/
│   ├── MigrateFromChromeToEdge/
│   ├── PasswordManagerDetection/
│   ├── RemoveStoredBrowserPasswords/
│   └── SensitiveCredentialDetection.ps1
├── SystemInfoReport/               # System information collection
│   ├── Get-SystemInfoReport.ps1
│   └── README.md
└── ZscalerSentinelOneSync/         # Zscaler to SentinelOne firewall automation
    ├── Sync-ZscalerToSentinelOneFirewall.ps1
    └── README.md
```

## Scripts Overview

| Folder | Description | Platform |
|--------|-------------|----------|
| [Edge](./Edge/) | Browser management and security scripts | Windows |
| [SystemInfoReport](./SystemInfoReport/) | Collects comprehensive system information with parallel execution | Windows, macOS, Linux |
| [ZscalerSentinelOneSync](./ZscalerSentinelOneSync/) | Syncs Zscaler IP ranges to SentinelOne Firewall Control | Windows, macOS, Linux |

## Requirements

- **PowerShell 7.0+** recommended for cross-platform scripts
- Windows PowerShell 5.1 for Windows-only scripts
- Appropriate permissions and API credentials as documented in each script's README

## Usage

Each folder contains its own README with detailed usage instructions. Navigate to the specific script folder for more information.

## Notes

- Scripts are built for their specific environment and may not work elsewhere
- Scripts assume devices are in compliant states
- AI-generated documentation may need verification
