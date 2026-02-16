# Auto Sync And Build - Project Summary

## Overview

AutoSyncBuild is a PowerShell-based automation tool for Unreal Engine development that integrates Perforce version control with automated building and editor launching. 

The tool transforms a multistep workflow (sync → check → build → launch) into a single-click operation while maintaining intelligence about when building is actually necessary.

**For teams:** Reduces friction in daily development and ensures everyone stays in sync.

**For individuals:** Saves 5–10 minutes per day on routine operations.

---

## Project Structure

```
AutoSyncBuild/
├── README.md                       # Complete user documentation
├── Installer.bat                   # Windows batch wrapper
├── Installer.pyw                   # Installer script 
├── Source/
│   ├── sync_and_build.bat          # Windows batch wrapper
│   └── sync_and_build.ps1          # Main PowerShell script
│
├── Config/
│   ├── config.template.json        # Template configuration
│   └── config.json                 # User configuration (auto-generated)
│
├── Logs/
│   ├── last_run.log                # Execution log
│   ├── last_build.log              # Build output log
│   └── example_success.log         # Example log file
│
└── Documentation/
    ├── QUICK_START.md              # 5-minute setup guide
    ├── TESTING.md                # Version history
    ├── TROUBLESHOOTING.md          # Problem-solving guide
```

---

## Key Features

### Core Functionality
- ✅ Perforce sync automation
- ✅ Code change detection
- ✅ Smart conditional building
- ✅ Build progress tracking
- ✅ Unreal Editor launching
- ✅ P4V integration

### Usability
- 📊 Real-time progress feedback
- 📊 Color-coded console output
- 📊 Helpful error messages
- 📊 Verbose logging mode
- 📊 Auto-detection of projects

---

## Architecture

### Component Breakdown

#### 1. Configuration System
- **JSON-based** storage
- **Dot notation** access (`"unrealEngine.path"`)
- **In-memory caching** for performance
- **Validation** on load

#### 2. Perforce Integration
- **Connection validation** before operations
- **Exit code checking** (not string parsing)
- **Real-time sync** progress

#### 3. Build System
- **Direct console** streaming (no redirection)
- **UBT native logging** (optional, no overhead)
- **Build time tracking**
- **Smart change detection**
- **Incremental build** support

#### 4. Error Handling
- **Typed exceptions** (`BuildException`)
- **Category tagging** (Perforce, Build, Config)
- **Helpful suggestions** for each error
- **Detailed logging**
- **Stack traces** for debugging

#### 5. Logging System
- **Timestamped entries**
- **Log levels** (INFO, SUCCESS, WARNING, ERROR, VERBOSE)
- **UTF-8 encoding**
- **Dual output** (console + file)
- **Configurable verbosity**

---
## Dependencies

### Required
- **Windows 10/11**
- **Python 3.10+**
- **PowerShell 5.0+** (included with Windows)
- **Perforce command-line tools** (p4.exe)
- **Unreal Engine 5.0+**
- **Visual Studio 2022** with C++ Build Tools
- **P4V** (for GUI integration)

---
## Use Cases

### 1. Daily Development Workflow
```powershell
# Morning: Sync and build
.\sync_and_build.bat

# Takes 5-10 min if changes exist
# Takes <30 sec if no changes
# Auto-detects code changes
```

### 2. Clean Build After Major Update
```powershell
# After engine update or big merge
.\sync_and_build.bat -Clean

# Deletes binaries, rebuilds everything
# Takes 15-30 min depending on hardware
```

### 3. Local Testing Without Sync
```powershell
# Testing local changes
.\sync_and_build.bat -SkipSync -ForceBuild

# Skips P4 sync
# Forces rebuild
# Useful for testing code changes
```

### 4. Integration with P4V
```
Right-click in P4V → Custom Tools → Auto Build
# Runs in terminal
# Shows real-time progress
# Refreshes P4V when done
```

---
## Configuration Options Reference

```json
{
    "version": "2.0",
    
    "project": {
        "name": "YourProject",           // Auto-detected or manual
        "displayName": "Your Project",   // Display name
        "autoDetect": true               // Enable auto-detection
    },
    
    "unrealEngine": {
        "path": "C:\\UE_5.6",           // UE installation path
        "version": "5.6"                 // UE version
    },
    
    "perforce": {
        "autoSync": true,                // Auto-sync on run
        "checkCodeChanges": true,        // Check for code changes
        "parallelSync": false            // Use parallel sync (future)
    },
    
    "build": {
        "lastBuiltCL": 245,              // Last built changelist
        "autoBuildOnCodeChange": true,   // Build if code changed
        "showBuildOutput": true,         // Show build progress
        "useUBTLogging": true            // Use UBT's native logging
    },
    
    "editor": {
        "autoLaunch": false,             // Auto-launch editor
        "launchTimeout": 30              // Launch timeout (seconds)
    },
    
    "logging": {
        "enabled": true,                 // Enable logging
        "verbose": false,                // Verbose output
        "keepLogs": 10                   // Number of logs to keep
    }
}
```
---

*Last updated: 2026-02-12*
*Version: 2.1*
