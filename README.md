# Unreal Engine - Auto Sync & Build Tool

Automatically syncs your Unreal Engine project with Perforce, detects code changes, builds when needed, and launches the editor - all with one click.

---

## Quick Start

### Installation

1. Download the latest release `SyncAndBuild.zip`
2. In your project folder, you should have a `Tools` folder
3. Extract `SyncAndBuild.zip` into `Tools` you should have `Proyect/Tools/AutoSyncBuild`
4. Open `AutoSyncBuild` and double click `Installer.bat`
5. Done! The tool will now be ready to use.

### First Use

1. Go to P4V → **Tools** and click on **Auto Sync And Build**
2. Input your preferences and close the window

---

## Requirements

- **P4 CLI, P4V, Python** installed
- **Unreal Engine** 5.0 or higher
- **PowerShell** 5.0 or higher (included with Windows 10/11)
- **Valid Perforce workspace** configured
- **Visual Studio** with C++ Build Tools

---

## Usage

### From P4V (Recommended)
1. Right-click on your project folder or any file
2. Select `Auto Build`
3. Watch the script run with real-time output

### From File Explorer
1. Navigate to `Tools\AutoSyncBuild\Source`
2. Double-click `sync_and_build.bat`

### From Command Line

**Normal build:**
```powershell
.\sync_and_build.bat
```
You can also add flags:
1. `-Clean` - Delete binaries and rebuild everything
2. `-SkipSync` - Skip Perforce sync (for local testing)
3. `-ForceBuild` - Force rebuild even if no code changes
4. `-NoPrompt` - Auto-launch editor without asking
5. `-Verbose` - Show detailed operation logs

---

## Configuration

### Config File Location
`Tools/AutoSyncBuild/Config/config.json`

### Key Settings

**build.useUBTLogging** (default: `true`)
- Uses Unreal Build Tool's native logging
- Build logs saved to `Logs/last_build.log`
- Does NOT affect build performance

**editor.autoLaunch** (default: `false`)
- Set to `true` to skip the launch prompt
- Automatically opens the editor after a successful build

**logging.verbose** (default: `false`)
- Shows detailed operation logs
- Useful for troubleshooting

---

## How It Works

### Workflow
1. **Project Detection**: Auto-finds your .uproject file
2. **Configuration**: Loads settings or prompts for first-time setup
3. **Validation**: Checks P4 connection and UE installation
4. **Sync**: Gets latest files from Perforce
5. **Change Detection**: Checks if code files changed since last build
6. **Smart Building**:
   - Builds if code changed
   - Builds if `-Clean` or `-ForceBuild` used
   - Skips if already built for this changelist
7. **Editor Launch**: Optionally launches Unreal Editor

---

## Files & Folders

```
Tools/AutoSyncBuild/
├── Source/
│   ├── sync_and_build.bat          ← Run this file
│   └── sync_and_build.ps1          ← Main script
├── Config/
│   ├── config.json                 ← Your settings (auto-created)
│   └── config.template.json        ← Template for reference
├── Logs/
│   ├── last_run.log                ← Script execution log
│   └── last_build.log              ← Build output log
├── README.md                       ← This file
├── Installer.bat                   ← Windows batch wrapper
└── Installer.pyw                   ← Installer script
```

**Note:** `config.json` and `*.log` files should be in your `.p4ignore` or `.gitignore`

---
## Tips & Best Practices

### When to Use Clean Build
- After pulling major engine/plugin updates
- After changing Unreal Engine versions
- When getting weird linker errors

### Check Build Logs
If a build fails:
1. Open `Logs/last_build.log`
2. Search for "error"
3. Check the last 20 lines for the specific failure

---
## Team Deployment

### What's Shared in Source Control
✅ **Tracked** (everyone gets):
- `sync_and_build.bat`
- `sync_and_build.ps1`
- `Installer.bat`
- `Installer.pyw`
- `README.md`

❌ **Not tracked** (user-specific):
- `config.json` - Personal settings
- `*.log` - Log files
- `*.backup` - Backup files

Add to `.p4ignore`:
```
*.log
config.json
*.backup
```
---

## Troubleshooting

Read the [testing](TESTING.md) and [trouble shooting](TROUBLESHOOTING.md) documents for information on how to run tests and troubleshoot common issues.

---
*Last updated: 2026-02-12*