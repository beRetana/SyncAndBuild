# Quick Start Guide

## 5-Minute Setup

### Step 1: Install (30 seconds)
1. Place `AutoSyncBuild` folder in your project's `Tools/` directory
2. Your structure should look like:
   ```
   YourProject/
     Tools/
       AutoSyncBuild/
         Source/
           sync_and_build.bat  ← This is what you'll run
   ```

### Step 2: First Run (1 minute)
1. Double-click `sync_and_build.bat`
2. Select your Unreal Engine installation when prompted
3. Done! Settings saved automatically.

---

## Daily Usage

### From P4V (Recommended)
1. Right-click on any file/folder
2. Select `Custom Tools` → `Auto Build`
3. Watch it sync and build

### From File Explorer
Double-click `sync_and_build.bat`

---

## Command Options

```powershell
# Normal build
.\sync_and_build.bat

# Clean rebuild
.\sync_and_build.bat -Clean

# Skip sync (build local changes only)
.\sync_and_build.bat -SkipSync

# Force rebuild
.\sync_and_build.bat -ForceBuild

# Auto-launch editor (no prompt)
.\sync_and_build.bat -NoPrompt
```

---

## What It Does

1. ✅ Syncs latest from Perforce
2. ✅ Detects if code changed
3. ✅ Builds only if needed (smart!)
4. ✅ Tracks what was last built
5. ✅ Prompts to launch editor

---

## Troubleshooting

### "p4 command not found"
- Install Perforce command-line tools
- Add to PATH and restart

### Build is slow
- Fixed in v2.0! Should be as fast as Visual Studio now
- If still slow, check disk/CPU

### Wrong UE version
- Delete `Config/config.json`
- Run script again to re-select

---

## P4V Integration (2 minutes)

1. Open P4V → Tools → Manage Custom Tools
2. Click **New**
3. Fill in:
   - **Name:** `Auto Build`
   - **Application:** `C:\Windows\System32\cmd.exe`
   - **Arguments:** `/k "path\to\Tools\AutoSyncBuild\Source\sync_and_build.bat"`
   - **Start In:** `path\to\Tools\AutoSyncBuild\Source`
   - ☑ **Run tool in terminal window**
   - ☑ **Refresh P4V upon completion**
4. Click OK

Now you can run it from right-click menu!

---

## Features

- **Fast**: No performance overhead (v2.0)
- **Smart**: Only builds when code changes
- **Reliable**: Proper error detection
- **Easy**: One click to sync+build+launch

---

See `README.md` for complete documentation.
