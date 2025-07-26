# Cursor Bundle v2.0 - Professional Edition

## Quick Start Guide

This is the v2.0 professional edition of the Cursor Bundle, with all components optimized for enterprise use.

### Prerequisites

- Linux/macOS/WSL environment
- Bash 4.0 or later
- Python 3.6+ (for GUI components)
- curl (for auto-updater)

### Installation

1. Extract the zip file:
   ```bash
   unzip cursor_bundle_v2_complete.zip
   cd cursor_bundle_v2
   ```

2. Set permissions:
   ```bash
   chmod +x *.sh
   chmod +x *.py
   ```

3. Run the installer:
   ```bash
   ./14-install-improved-v2.sh
   ```

### Main Components

- **02-launcher-improved-v2.sh** - Main application launcher
- **03-autoupdater-improved-v2.sh** - Auto-update system
- **04-secure-improved-v2.sh** - Security framework
- **05-secureplus-improved-v2.sh** - Enhanced security
- **bump_merged-v2.sh** - Version management

### Usage

Launch Cursor IDE:
```bash
./02-launcher-improved-v2.sh
```

Check for updates:
```bash
./03-autoupdater-improved-v2.sh check
```

Run security scan:
```bash
./04-secure-improved-v2.sh scan
```

### Features

✓ Professional error handling with self-correction
✓ Enterprise-grade security validation
✓ Comprehensive logging and monitoring
✓ Multi-platform compatibility
✓ All scripts under 1000 lines (policy compliant)

### Troubleshooting

If you encounter errors:

1. Check logs in `~/.config/cursor-*/logs/`
2. Run with debug mode: `./script-name.sh --debug`
3. Verify all files are present: `ls -la *-v2.*`

### Version

Current version: v6.9.229
Build: Professional Edition v2.0

All scripts have been professionally optimized with:
- Strong error handling
- Self-correcting mechanisms
- Policy compliance (max 1000 lines)
- No experimental features

For support, check the logs directory for detailed error information.