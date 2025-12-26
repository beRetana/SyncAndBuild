# Troubleshooting Guide

Complete guide to solving common issues with the AutoSyncBuild Tool.

---

## 🔍 Diagnostic Steps

Before troubleshooting specific issues:

1. **Run with verbose flag**
   ```powershell
   .\sync_and_build.bat -Verbose
   ```

2. **Check the log file**
   ```
   Tools/AutoSyncBuild/Logs/last_run.log
   ```

3. **Verify your environment**
   ```powershell
   p4 info          # Check P4 connection
   p4 set           # Check P4 settings
   ```

---

## 🚨 Common Issues

### Issue: "Perforce command not found"

**Symptoms:**
- Error: `p4 : The term 'p4' is not recognized...`
- Script fails immediately

**Cause:**
Perforce command-line tools not installed or not in PATH

**Solution:**
1. Download and install Perforce command-line tools:
   - Download from: https://www.perforce.com/downloads/helix-command-line-client-p4
   - Or install P4V (includes command-line tools)

2. Add P4 to your system PATH:
   - Windows: System Properties → Environment Variables → PATH
   - Add: `C:\Program Files\Perforce` (or wherever p4.exe is)

3. Restart your terminal/P4V

4. Test:
   ```powershell
   p4 -V
   # Should show version info
   ```

---

### Issue: Build is Slow

**Symptoms:**
- Build takes 2-3x longer than Visual Studio
- Build seems to freeze/hang
- No output during build

**Cause (v1.0):**
Output redirection bottleneck

**Solution:**
✅ **Upgrade to v2.0** - This issue is completely fixed!

If still slow in v2.0:
- Check disk speed (use SSD for better performance)
- Check CPU usage (should be 70-100% during build)
- Check antivirus (may scan build outputs in real-time)
- Close other applications using CPU/disk

**Verify it's fixed:**
```powershell
# v2.0 should show real-time output like this:
[1/100] Compiling Module.MyGame.cpp
[2/100] Compiling Character.cpp
...
```

---

### Issue: Sync Fails or Reports Incorrect Status

**Symptoms:**
- Says "up-to-date" but files weren't synced
- Sync fails with unclear error
- Different users get different results

**Cause (v1.0):**
Fragile string parsing and `...#have` bug

**Solution:**
✅ **Upgrade to v2.0** - This issue is fixed!

If still having sync issues:

1. **Check P4 connection:**
   ```powershell
   p4 info
   ```
   Should show your server, client, user

2. **Check workspace mapping:**
   ```powershell
   p4 client -o
   ```
   Verify your View mapping

3. **Manual sync test:**
   ```powershell
   cd YourProjectRoot
   p4 sync ...
   ```
   If this works, the tool should work

4. **Check P4CONFIG:**
   - Ensure `.p4config` file exists in project root
   - Contains: `P4CLIENT=YourWorkspaceName`

---

### Issue: "Project file not found"

**Symptoms:**
- Error: `Project file not found: ...`
- Script can't find your `.uproject`

**Cause:**
Incorrect path detection or project structure

**Solution:**

1. **Let auto-detect work (v2.0):**
   - Ensure tool is in `YourProject/Tools/AutoSyncBuild/`
   - Your `.uproject` should be found automatically

2. **Manual configuration:**
   - Edit `Config/config.json`:
   ```json
   {
       "project": {
           "name": "YourProjectName",
           "autoDetect": false
       }
   }
   ```

3. **Check your structure:**
   ```
   YourProject/
     YourProjectName/
       YourProjectName.uproject  ← Must exist
     Tools/
       AutoSyncBuild/
         Source/
           sync_and_build.bat
   ```

4. **Verify project file exists:**
   ```powershell
   ls YourProject\YourProjectName\*.uproject
   ```

---

### Issue: Wrong Unreal Engine Version

**Symptoms:**
- Build fails with version mismatch errors
- Uses old UE installation
- "Engine not compatible" errors

**Solution:**

**Option 1: Delete config and re-select**
```powershell
del Tools\AutoSyncBuild\Config\config.json
.\sync_and_build.bat
# Will prompt to select UE again
```

**Option 2: Edit config manually**
1. Open `Config/config.json`
2. Update:
   ```json
   {
       "unrealEngine": {
           "path": "C:\\Apps\\UE_5.6",
           "version": "5.6"
       }
   }
   ```
3. Run the script

**Verify UE path:**
```powershell
# Should exist:
C:\Apps\UE_5.6\Engine\Build\BatchFiles\Build.bat
C:\Apps\UE_5.6\Engine\Binaries\Win64\UnrealEditor.exe
```

---

### Issue: Build Fails

**Symptoms:**
- "BUILD FAILED!" message
- Exit code: 6 (or other non-zero)
- Compiler errors

**Diagnosis:**

1. **Check build log:**
   ```
   Tools/AutoSyncBuild/Logs/last_build.log
   ```

2. **Look for error:**
   - Search for "error" in the log
   - Last 50 lines usually show the problem

3. **Common errors:**

   **Missing Visual Studio:**
   ```
   Error: MSBuild not found
   ```
   **Solution:** Install Visual Studio 2022 with C++ workload

   **Disk space:**
   ```
   Error: No space left on device
   ```
   **Solution:** Free up disk space (need 10+ GB)

   **Missing SDK:**
   ```
   Error: Windows SDK not found
   ```
   **Solution:** Install Windows 10/11 SDK

   **Code error:**
   ```
   Error: identifier "MyVariable" is undefined
   ```
   **Solution:** Fix the code error (revert recent changes if needed)

**Quick fixes:**

1. **Try clean build:**
   ```powershell
   .\sync_and_build.bat -Clean
   ```

2. **Build in Visual Studio first:**
   - Open the `.sln` file
   - Build → Build Solution
   - If this works, the tool should work

3. **Check dependencies:**
   - Visual Studio 2022 installed
   - Windows SDK installed
   - Disk space available
   - No files locked by other apps

---

### Issue: P4V Custom Tool Doesn't Work

**Symptoms:**
- Right-click menu doesn't show "Auto Build"
- Tool runs but nothing happens
- No output shown

**Solution:**

1. **Verify P4V setup:**
   - Tools → Manage Custom Tools
   - Check "Auto Build" exists

2. **Critical settings:**
   - ☑ "Run tool in terminal window" **MUST be checked!**
   - Application: `C:\Windows\System32\cmd.exe` (not powershell.exe)
   - Arguments: `/k "full\path\to\sync_and_build.bat"`

3. **Test the command:**
   ```powershell
   cmd /k "C:\Your\Path\sync_and_build.bat"
   ```
   Should open terminal and run

4. **Common mistakes:**
   - Forgetting `/k` flag (window closes immediately)
   - Using PowerShell.exe instead of cmd.exe
   - Incorrect path (use absolute paths)
   - Not checking "Run tool in terminal window"

---

### Issue: Permission Errors

**Symptoms:**
- "Access denied"
- "Cannot write to file"
- "File is locked"

**Solution:**

1. **Check file permissions:**
   ```powershell
   icacls Tools\AutoSyncBuild
   ```
   Should show write permissions

2. **Close conflicting apps:**
   - Close any editors viewing log files
   - Close other instances of the tool
   - Close UE Editor if running

3. **Run as administrator (if needed):**
   - Right-click P4V → Run as administrator
   - Or right-click `sync_and_build.bat` → Run as administrator

4. **Check antivirus:**
   - Some antivirus blocks script execution
   - Add exception for `AutoSyncBuild` folder

---

### Issue: Config File Errors

**Symptoms:**
- "Invalid config file format"
- "Failed to read config"
- Script crashes on startup

**Solution:**

1. **Validate JSON:**
   - Open `Config/config.json`
   - Use JSON validator: https://jsonlint.com
   - Look for:
     - Missing commas
     - Extra commas
     - Unclosed brackets
     - Wrong quotes (use `"` not `'`)

2. **Reset to default:**
   ```powershell
   del Config\config.json
   copy Config\config.template.json Config\config.json
   ```

3. **Common JSON mistakes:**
   ```json
   // ❌ Bad:
   {
       "path": "C:\Users\Me",  // ❌ Single backslash
       "value": 123,           // ❌ Trailing comma
   }

   // ✅ Good:
   {
       "path": "C:\\Users\\Me",
       "value": 123
   }
   ```

---

### Issue: Encoding Problems

**Symptoms:**
- Log file shows garbage characters
- Config file has weird symbols
- Script fails to parse files

**Solution:**

1. **Save config as UTF-8:**
   - Open `config.json` in Notepad++
   - Encoding → UTF-8 (without BOM)
   - Save

2. **Check PowerShell encoding:**
   ```powershell
   $PSDefaultParameterValues['Out-File:Encoding'] = 'UTF8'
   ```

3. **Regenerate config:**
   ```powershell
   del Config\config.json
   .\sync_and_build.bat
   # Will create new clean config
   ```

---

### Issue: Network/Connection Issues

**Symptoms:**
- "Cannot connect to Perforce server"
- Timeout errors
- Intermittent failures

**Solution:**

1. **Check P4 connection:**
   ```powershell
   p4 info
   ```

2. **Check environment:**
   ```powershell
   p4 set
   # Should show:
   # P4PORT=yourserver:1666
   # P4USER=yourname
   # P4CLIENT=yourworkspace
   ```

3. **Set environment if missing:**
   ```powershell
   p4 set P4PORT=yourserver:1666
   p4 set P4USER=yourname
   p4 set P4CLIENT=yourworkspace
   ```

4. **Test connection:**
   ```powershell
   p4 login
   p4 info
   ```

5. **Check network:**
   - VPN connected?
   - Firewall blocking port 1666?
   - Can ping server?

---

## 🔧 Advanced Troubleshooting

### Enable Maximum Verbosity

```powershell
.\sync_and_build.bat -Verbose
```

Or edit config:
```json
{
    "logging": {
        "verbose": true
    }
}
```

### Check PowerShell Version

```powershell
$PSVersionTable.PSVersion
# Should be 5.0 or higher
```

### Manual Test Script Sections

Test sync only:
```powershell
.\sync_and_build.bat -SkipSync
```

Test build only:
```powershell
.\sync_and_build.bat -ForceBuild
```

### Clean Slate Reset

```powershell
# Backup first
copy Config\config.json Config\config.backup.json

# Delete all generated files
del Config\config.json
del Logs\*.log

# Run fresh
.\sync_and_build.bat
```

---

## 📊 Performance Issues

### Slow Disk I/O

**Symptoms:**
- High disk usage during build
- Long pauses
- Disk LED constantly on

**Solution:**
- Use SSD for project (not HDD)
- Check disk health
- Disable real-time antivirus scanning for build folders
- Close other disk-intensive apps

### Memory Issues

**Symptoms:**
- Build runs out of memory
- System becomes unresponsive
- "Out of memory" errors

**Solution:**
- Close other applications
- Increase virtual memory (page file)
- Upgrade RAM (16GB minimum, 32GB recommended)
- Use incremental builds instead of clean builds

### CPU Bottleneck

**Symptoms:**
- Build time not improved by tool
- CPU at 100% for entire build
- Long compilation times

**Solution:**
- This is normal! UE builds are CPU-intensive
- Can't speed up beyond hardware limits
- Consider:
  - Upgrade CPU
  - Use distributed build (IncrediBuild)
  - Reduce parallel build jobs

---

## 🆘 Still Having Issues?

### Gather Debug Info

1. **Run with verbose:**
   ```powershell
   .\sync_and_build.bat -Verbose > debug.txt 2>&1
   ```

2. **Collect info:**
   - `debug.txt` (full output)
   - `Logs/last_run.log`
   - `Logs/last_build.log` (if build ran)
   - `Config/config.json`
   - Output of `p4 info`
   - Output of `p4 set`

3. **System info:**
   ```powershell
   systeminfo
   $PSVersionTable
   ```

### Contact Support

Provide:
- Detailed error message
- Steps to reproduce
- All debug info collected above
- What you've already tried

### Check for Updates

- See if issue is fixed in newer version
- Check `CHANGELOG.md` for bug fixes
- Update to latest version

---

## 🎯 Quick Reference

| Issue | Quick Fix |
|-------|-----------|
| Build slow | Upgrade to v2.0 |
| Sync fails | Upgrade to v2.0 |
| Can't find P4 | Add to PATH, restart |
| Wrong UE | Delete config.json |
| Build fails | Check build log |
| Permission error | Run as admin |
| Config error | Delete config.json |
| P4V tool doesn't work | Check "Run in terminal" |

---

*Last updated: 2024-12-23*
