#Requires -Version 5.0

# ==========================================
# Setup and Initialization
# ==========================================

$ErrorActionPreference = "Stop"

# Keep Constant/script variables organized and easy to modify
$script:CONSTANTS = @{

    FileNames = @{
        ConfigFileName = "config.json"
        RunLogFileName = "last_run.log"
        BuildLogFileName = "last_build.log"
    }
    
    ConfigKeys = @{
        ProjectName = "project.name"
        ProjectDisplayName = "project.displayName"
        EnginePath = "unrealEngine.path"
        EngineVersion = "unrealEngine.version"
        EditorAutoLaunch = "editor.autoLaunch"
        UseUBTLogging = "build.useUBTLogging"
        LastBuiltCL = "build.lastBuiltCL"
        PerforceFileExtentions = "perforce.fileExtensions"
        LoggingVerbose = "logging.verbose"
    }
    
    Paths = @{
        UnrealBuildBat = "Engine\Build\BatchFiles\Build.bat"
        UnrealEditorExe = "Engine\Binaries\Win64\UnrealEditor.exe"
    }
    
    PerforceUpToDate = "file(s) up-to-date."
    JsonConfigDepth = 10
    SearchRecursionDepth = 5

}

# Core Directories used often in the project
$script:scriptRoot = $PSScriptRoot
$configDir = Join-Path $script:scriptRoot "..\Config"
$logsDir = Join-Path $script:scriptRoot "..\Logs"

# Create directories if they don't exist
New-Item -ItemType Directory -Force -Path $configDir
New-Item -ItemType Directory -Force -Path $logsDir

# Config files
$script:configFile = Join-Path $configDir $script:CONSTANTS.FileNames.ConfigFileName
$script:logFile = Join-Path $logsDir $script:CONSTANTS.FileNames.RunLogFileName

# Will be set during initialization
$script:projectRoot = $null
$script:projectName = $null
$script:projectFile = $null
$script:configCache = $null

# ==========================================
# Error Handling Classes
# ==========================================

class BuildException : System.Exception {
    [string]$Category
    [string]$Suggestion
    
    BuildException([string]$message, [string]$category, [string]$suggestion) : base($message) {
        $this.Category = $category
        $this.Suggestion = $suggestion
    }
}

# ==========================================
# Logging Functions
# ==========================================

function Initialize-Log {
    <#
    .SYNOPSIS
        Initialize log file with header
    #>
    
    $header = @"
==========================================
Sync and Build Tool v2.0
Started: $(Get-Date)
==========================================

"@
    $header | Out-File -FilePath $script:logFile -Encoding UTF8
}

function Write-Log {
    <#
    .SYNOPSIS
        Write a log message to file and console
    #>
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    Add-Content -Path $script:logFile -Value $logMessage -Encoding UTF8
    
    switch ($Level) {
        "ERROR"   { Write-Host "[ERROR] $Message" -ForegroundColor Red }
        "WARNING" { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
        "SUCCESS" { Write-Host "[OK] $Message" -ForegroundColor Green }
        "INFO"    { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
        "VERBOSE" { 
            if (Get-ConfigValue $script:CONSTANTS.ConfigKeys.LoggingVerbose -DefaultValue $false) {
                Write-Host "[VERBOSE] $Message" -ForegroundColor Gray
            }
        }
        default   { Write-Host $Message }
    }
}

function Write-Header {
    <#
    .SYNOPSIS
        Write a formatted header to console
    #>
    param([string]$Text)
    
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-DetailedError {
    <#
    .SYNOPSIS
        Write detailed error with category and suggestion
    #>
    param(
        [string]$Message,
        [string]$Category = "Error",
        [string]$Suggestion = ""
    )
    
    Write-Log $Message "ERROR"
    Write-Host ""
    Write-Host "ERROR ($Category): $Message" -ForegroundColor Red
    
    if ($Suggestion) {
        Write-Host ""
        Write-Host "SUGGESTION: $Suggestion" -ForegroundColor Yellow
    }
    Write-Host ""
}

# ==========================================
# Configuration Functions
# ==========================================

function Get-Config {
    <#
    .SYNOPSIS
        Load configuration from JSON file with caching
    #>
    
    # Return cached config if available
    if ($script:configCache) {
        return $script:configCache
    }
    
    if (-not (Test-Path $script:configFile)) {
        Write-Log "Creating default config file" "INFO"
        
        # Create default config
        $defaultConfig = @{
            version = "2.0"
            project = @{
                name = ""
                displayName = ""
                autoDetect = $true
            }
            unrealEngine = @{
                path = ""
                version = ""
            }
            perforce = @{
                autoSync = $true
                checkCodeChanges = $true
                parallelSync = $false
                fileExtensions = @(".cpp", ".h", ".build.cs", ".target.cs", ".cs", ".ini", ".py")
            }
            build = @{
                lastBuiltCL = 0
                autoBuildOnCodeChange = $true
                showBuildOutput = $true
                useUBTLogging = $true
            }
            editor = @{
                autoLaunch = $false
                launchTimeout = 30
            }
            logging = @{
                enabled = $true
                verbose = $false
                keepLogs = 10
            }
        }
        
        $defaultConfig | ConvertTo-Json -Depth $script:CONSTANTS.SearchRecursionDepth | Out-File -FilePath $script:configFile -Encoding UTF8
        $script:configCache = $defaultConfig
        return $defaultConfig
    }
    
    try {
        $config = Get-Content $script:configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Validate required fields
        if (-not $config.version) {
            Write-Log "Migrating old config to v2.0" "INFO"
            $config | Add-Member -NotePropertyName "version" -NotePropertyValue "2.0" -Force
            Save-Config -Config $config
        }
        
        $script:configCache = $config
        return $config
        
    } catch {
        $errorMessage = $_.Exception.Message
        throw [BuildException]::new(
            "Failed to read config file: $errorMessage",
            "Configuration",
            "Delete $script:configFile and run the script again to recreate it"
        )
    }
}

function Save-Config {
    <#
    .SYNOPSIS
        Save configuration to JSON file
    #>
    param($Config)
    
    try {
        $Config | ConvertTo-Json -Depth $script:CONSTANTS.SearchRecursionDepth | Out-File -FilePath $script:configFile -Encoding UTF8
        $script:configCache = $Config
        Write-Log "Config saved" "VERBOSE"
    } catch {
        Write-Log "Failed to save config: $_" "ERROR"
    }
}

function Get-ConfigValue {
    <#
    .SYNOPSIS
        Get a configuration value using dot notation
    .EXAMPLE
        Get-ConfigValue "unrealEngine.path"
    #>
    param(
        [string]$Path,
        $DefaultValue = $null
    )
    
    $config = Get-Config
    $parts = $Path -split '\.'
    $current = $config
    
    foreach ($part in $parts) {
        if ($current.PSObject.Properties.Name -contains $part) {
            $current = $current.$part
        } else {
            return $DefaultValue
        }
    }
    
    return $current
}

function Set-ConfigValue {
    <#
    .SYNOPSIS
        Set a configuration value using dot notation
    .EXAMPLE
        Set-ConfigValue "unrealEngine.path" "C:\UE_5.6"
    #>
    param(
        [string]$Path,
        $Value
    )
    
    $startingConfigPoint = Get-Config
    $parts = $Path -split '\.'
    $current = $startingConfigPoint
    
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        $part = $parts[$i]
        if (-not ($current.PSObject.Properties.Name -contains $part)) {
            $current | Add-Member -NotePropertyName $part -NotePropertyValue @{} -Force
        }
        $current = $current.$part
    }
    
    $lastPart = $parts[-1]
    if ($current.PSObject.Properties.Name -contains $lastPart) {
        $current.$lastPart = $Value
    } else {
        $current | Add-Member -NotePropertyName $lastPart -NotePropertyValue $Value -Force
    }
    
    Save-Config -Config $startingConfigPoint
}

# ==========================================
# Project Detection Functions
# ==========================================

function Find-UnrealProject {
    <#
    .SYNOPSIS
        Auto-detect Unreal project file
    #>
    param([string]$SearchPath)
    
    Write-Log "Searching for .uproject files in: $SearchPath" "VERBOSE"
    
    $projects = Get-ChildItem -Path $SearchPath -Filter "*.uproject" -Recurse -Depth $script:CONSTANTS.SearchRecursionDepth -ErrorAction SilentlyContinue
    
    $projects = @($projects)

    if ($projects.Count -eq 0) {
        throw [BuildException]::new(
            "No Unreal project (.uproject) found in: $SearchPath",
            "Project Detection",
            "Ensure there is a .uproject in the search path"
        )
    }
    
    if ($projects.Count -eq 1) {
        Write-Log "Found project: $($projects[0].Name)" "SUCCESS"
        return $projects[0]
    }
    
    Write-Host ""
    Write-Host "Multiple projects found:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $projects.Count; $i++) {
        Write-Host "  [$($i + 1)] $($projects[$i].Name) - $($projects[$i].DirectoryName)" -ForegroundColor White
    }
    Write-Host ""
    
    do {
        Write-Host "Select project (1-$($projects.Count)): " -ForegroundColor Cyan
        $choice = Read-Host
        $index = $choice -as [int]
        
        if ($index -ge 1 -and $index -le $projects.Count) {
            $selected = $projects[$index - 1]
            Write-Log "Selected project: $($selected.Name)" "INFO"
            return $selected
        }
        
        Write-Host "Invalid choice. Please try again." -ForegroundColor Red
    } while ($true)
}

function Initialize-ProjectPaths {
    <#
    .SYNOPSIS
        Initialize project paths based on auto-detection or config
    #>
    
    $configuredName = Get-ConfigValue $script:CONSTANTS.ConfigKeys.ProjectName
    $scanForProjectDetails = $false

    if ($configuredName) {
        Write-Log "Using configured project: $configuredName" "VERBOSE"
        
        $ToolPath = Split-Path -Parent $script:scriptRoot
        $ToolsPath = Split-Path -Parent $ToolPath
        $script:projectRoot = Split-Path -Parent $ToolsPath
        $script:projectName = $configuredName
        $script:projectFile = Join-Path $script:projectRoot "$configuredName\$configuredName.uproject"
        
        if (-not (Test-Path $script:projectFile)) {
            Write-Log "Configured project not found, switching to detect for project details" "WARNING"
            $scanForProjectDetails = $true
        }
        else {
            return
        }
    }

    if ($scanForProjectDetails -or -not $configuredName) {
        Write-Log "Scanning for project details..." "INFO"
        
        $ToolPath = Split-Path -Parent $script:scriptRoot
        $toolsDir = Split-Path -Parent $ToolPath
        $searchRoot = Split-Path -Parent $toolsDir           
        $projectFileObj = Find-UnrealProject -SearchPath $searchRoot
        
        $script:projectFile = $projectFileObj.FullName
        $script:projectName = $projectFileObj.BaseName
        $script:projectRoot = Split-Path -Parent $projectFileObj.DirectoryName
        
        Set-ConfigValue $script:CONSTANTS.ConfigKeys.ProjectName $script:projectName
        Set-ConfigValue $script:CONSTANTS.ConfigKeys.ProjectDisplayName "$script:projectName Project"
        
        Write-Log "Project detected: $script:projectName" "VERBOSE"
        Write-Log "Project root: $script:projectRoot" "VERBOSE"
    }
    
    if (-not (Test-Path $script:projectFile)) {
        throw [BuildException]::new(
            "Project file not found: $script:projectFile",
            "Project Configuration",
            "Check the project name in config.json or move the script to the correct location"
        )
    }
}

# ==========================================
# Unreal Engine Functions
# ==========================================

function Find-UnrealEngine {
    <#
    .SYNOPSIS
        Search for Unreal Engine installations
    #>
    
    Write-Host "Searching for Unreal Engine installations..." -ForegroundColor Yellow
    Write-Host ""
    
    $searchPaths = @(
        "C:\Program Files\Epic Games",
        "C:\Epic Games",
        "C:\Apps\UE_Engines",
        "C:\UE"
    )
    
    $found = @()
    
    foreach ($basePath in $searchPaths) {
        if (Test-Path $basePath) {
            Write-Log "Scanning: $basePath" "VERBOSE"
            
            $ueDirs = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | 
                      Where-Object { $_.Name -match "^(UE|UnrealEngine)[_\s-]?[\d\.]+" }
            
            foreach ($ueDir in $ueDirs) {
                $buildBat = Join-Path $ueDir.FullName $script:CONSTANTS.Paths.UnrealBuildBat
                
                if (Test-Path $buildBat) {
                    $version = "Unknown"
                    if ($ueDir.Name -match "([\d\.]+)") {
                        $version = $Matches[1]
                    }

                    if ($found.Path -contains $ueDir.FullName) {continue}

                    $found += [PSCustomObject]@{
                        Index = $found.Count + 1
                        Path = $ueDir.FullName
                        Version = $version
                        Name = $ueDir.Name
                    }
                    
                    Write-Host "  [$($found.Count)] UE $version - $($ueDir.FullName)" -ForegroundColor White
                }
            }
        }
    }
    
    Write-Host ""
    
    if ($found.Count -eq 0) {
        Write-Host "No Unreal Engine installations found in common locations." -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host "Found $($found.Count) installation(s)" -ForegroundColor Green
        Write-Host ""
    }
    
    Write-Host "  [B] Browse for a different location" -ForegroundColor White
    Write-Host ""
    
    do {
        if ($found.Count -gt 0) {
            $choice = Read-Host "Select option (1-$($found.Count) or B)"
        } else {
            $choice = "B"
        }
        
        if ($choice -eq "B" -or $choice -eq "b") {

            $form = New-Object System.Windows.Forms.Form
            $form.TopMost = $true 
            $form.WindowState = "Minimized"
            $form.ShowInTaskbar = $false 

            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $dialog.Description = "Select your Unreal Engine installation folder (e.g., UE_5.6)"
            $dialog.RootFolder = "MyComputer"
            
            $result = $dialog.ShowDialog($form)

            $form.Dispose()
            
            if ($result -eq "OK") {
                $selectedPath = $dialog.SelectedPath
                $buildBat = Join-Path $selectedPath $script:CONSTANTS.Paths.UnrealBuildBat
                
                if (Test-Path $buildBat) {
                    return $selectedPath
                } else {
                    Write-Host ""
                    Write-Host "Invalid Unreal Engine installation (Build.bat not found)." -ForegroundColor Red
                    Write-Host "Please try again." -ForegroundColor Yellow
                    Write-Host ""
                    continue
                }
            } else {
                Write-Host ""
                Write-Host "Selection cancelled." -ForegroundColor Yellow
                return $null
            }
        }
        
        $index = $choice -as [int]
        if ($index -ge 1 -and $index -le $found.Count) {
            return $found[$index - 1].Path
        }
        
        Write-Host ""
        Write-Host "Invalid choice. Please try again." -ForegroundColor Red
        Write-Host ""
    } while ($true)
}

function Get-UnrealEngineRoot {
    <#
    .SYNOPSIS
        Get Unreal Engine installation path from config or prompt user
    #>
    
    $savedPath = Get-ConfigValue $script:CONSTANTS.ConfigKeys.EnginePath
    
    if ($savedPath) {
        $buildBat = Join-Path $savedPath $script:CONSTANTS.Paths.UnrealBuildBat
        
        if (Test-Path $buildBat) {
            Write-Log "Using UE installation: $savedPath" "VERBOSE"
            return $savedPath
        } else {
            Write-Log "Saved UE path is invalid, requesting new selection" "WARNING"
        }
    }
    
    # First time setup or invalid path
    Write-Header "UNREAL ENGINE SETUP"
    Write-Host "First time setup - please select your Unreal Engine installation." -ForegroundColor Yellow
    Write-Host ""
    
    $uePath = Find-UnrealEngine
    
    if (-not $uePath) {
        throw [BuildException]::new(
            "Setup cancelled or no valid Unreal Engine found",
            "Configuration",
            "Install Unreal Engine and run the script again"
        )
    }
    
    # Detect version from path
    if ($uePath -match "([\d\.]+)") {
        $version = $Matches[1]
        Set-ConfigValue $script:CONSTANTS.ConfigKeys.EngineVersion $version
        Write-Log "Detected UE version: $version" "INFO"
    }
    
    # Save to config
    Set-ConfigValue $script:CONSTANTS.ConfigKeys.EnginePath $uePath
    Write-Log "UE path saved to config" "INFO"
    
    return $uePath
}

function Test-UnrealEngineValid {
    <#
    .SYNOPSIS
        Validate Unreal Engine installation
    #>
    param([string]$UERoot)
    
    $buildBat = Join-Path $UERoot $script:CONSTANTS.Paths.UnrealBuildBat
    $editorExe = Join-Path $UERoot $script:CONSTANTS.Paths.UnrealEditorExe
    
    if (-not (Test-Path $buildBat)) {
        throw [BuildException]::new(
            "Build.bat not found in UE installation",
            "Unreal Engine",
            "Ensure you selected a valid UE installation folder"
        )
    }
    
    if (-not (Test-Path $editorExe)) {
        throw [BuildException]::new(
            "UnrealEditor.exe not found",
            "Unreal Engine",
            "Ensure you compile the Engine or select a different installation"
        )
    }
    
    return $true
}

# ==========================================
# Perforce Functions
# ==========================================

function Test-PerforceEnvironment {
    <#
    .SYNOPSIS
        Validate P4 environment and connection
    #>
    
    Write-Log "Validating Perforce environment..." "VERBOSE"
    
    # Check P4 is installed
    $p4Command = Get-Command p4 -ErrorAction SilentlyContinue
    if (-not $p4Command) {
        throw [BuildException]::new(
            "Perforce command-line tools not found",
            "Perforce",
            "Install Perforce command-line tools (p4.exe) and add to your system PATH"
        )
    }
    
    Write-Log "P4 command found: $($p4Command.Source)" "VERBOSE"
    
    # Check connection
    try {
        $p4info = p4 info 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Connection failed"
        }
        
        # Extract client name
        $clientLine = $p4info | Select-String "Client name:" | Select-Object -First 1
        if ($clientLine) {
            $clientName = ($clientLine.ToString() -replace "Client name:\s*", "").Trim()
            Write-Log "P4 Client: $clientName" "VERBOSE"
            return $clientName
        } else {
            throw "No client workspace configured"
        }
        
    } catch {
        $Message = $_.Exception.Message
        throw [BuildException]::new(
            "Cannot connect to Perforce server: $Message",
            "Perforce",
            "Run 'p4 info' to check your connection. Ensure P4PORT, P4USER, and P4CLIENT are set correctly."
        )
    }
}

function Sync-FromPerforce {
    <#
    .SYNOPSIS
        Sync project from Perforce with proper error handling
    #>

    param(
        [switch]$SkipSync = $false,
        [switch]$Verbose = $false
    )
    
    Write-Header "STEP 1: SYNCING FROM PERFORCE"
    
    if ($SkipSync) {
        Write-Host "Skipping sync (SkipSync flag set)" -ForegroundColor Yellow
        Write-Log "Sync skipped by user" "INFO"
        return $true
    }
    
    try {
        # Validate P4 environment
        $clientName = Test-PerforceEnvironment
        Write-Host "Client workspace: $clientName" -ForegroundColor Cyan
        Write-Host ""
        
        # Get current changelist before sync
        $beforeCL = Get-LatestHaveChangelist
        if ($beforeCL) {
            Write-Host "Current changelist: $beforeCL" -ForegroundColor Gray
        }
        
        # Perform sync
        Write-Host "Syncing from Perforce..." -ForegroundColor Cyan
        Write-Log "Executing: p4 sync ..." "VERBOSE"

        Push-Location $script:projectRoot
        
        try {
            $syncOutput = @()
            $syncError = @()
             
            # Perforce might throw an exception for when everything is up-to-date, we need to collect the logs then check for them.
            $p4Output = & { 
                $ErrorActionPreference = "Continue"
                & p4 sync ... 2>&1 
            }

            $syncExitCode = $LASTEXITCODE
            
            foreach ($outputObject in $p4Output) {
                $line = $outputObject.ToString()

                if ($outputObject -is [System.Management.Automation.ErrorRecord])
                {
                    $syncError += $line
                }
                else
                {
                    $syncOutput += $line
                    
                    # Show progress to user
                    if ($line -match "^//") {
                        Write-Host $line -ForegroundColor DarkGray
                    }
                }
            }
            
            # Check result using exit code
            if ($syncExitCode -eq 0 -or $syncError -match $script:CONSTANTS.PerforceUpToDate) {
                $afterCL = Get-LatestHaveChangelist
                
                Write-Host ""
                
                if ($beforeCL -eq $afterCL) {
                    Write-Host "Already up-to-date (CL $afterCL)" -ForegroundColor Green
                    Write-Log "Already up-to-date at CL $afterCL" "INFO"
                } else {
                    Write-Host "Successfully synced from CL $beforeCL to CL $afterCL" -ForegroundColor Green
                    Write-Log "Synced from CL $beforeCL to CL $afterCL" "INFO"
                    
                    # Show summary of changes
                    $updatedFiles = $syncOutput | Where-Object { $_ -match "updating|added|deleted" }
                    if ($updatedFiles.Count -gt 0) {
                        Write-Host ""
                        Write-Host "Files changed: $($updatedFiles.Count)" -ForegroundColor Cyan
                        
                        if ($Verbose -and $updatedFiles.Count -le 20) {
                            $updatedFiles | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
                        }
                    }
                }
                
                Write-Host ""
                return $true
                
            } else {
                # Sync failed
                $errorMsg = $syncError | Where-Object { $_ -match "error|failed|can't" } | Select-Object -First 5
                $jointErrorMsg = $errorMsg -join "; "
                
                throw [BuildException]::new(
                    "Perforce sync failed (Exit code: $syncExitCode)",
                    "Perforce",
                    "Check your network connection and workspace mapping. Error: $jointErrorMsg"
                )
            }
            
        } finally {
            Pop-Location
        }
        
    } catch [BuildException] {
        Write-DetailedError `
            -Message $_.Exception.Message `
            -Category $_.Exception.Category `
            -Suggestion $_.Exception.Suggestion
        return $false
    } catch {
        $Message = $_.Exception.Message
        Write-DetailedError `
            -Message "Sync error: $Message" `
            -Category "Perforce" `
            -Suggestion "Run 'p4 set' to check your Perforce configuration"
        return $false
    }
}

function Get-LatestHaveChangelist {
    <#
    .SYNOPSIS
        Get the latest changelist number that the user has synced
    #>
    
    try {
        Push-Location $script:projectRoot
        
        # FIXED: Proper quoting of ...#have
        Write-Log "Executing: p4 changes -m1 `"...#have`"" "VERBOSE"
        $output = p4 changes -m1 "...#have" 2>&1
        
        if ($LASTEXITCODE -eq 0 -and $output -match "Change (\d+)") {
            $cl = [int]$Matches[1]
            Write-Log "Latest have changelist: $cl" "VERBOSE"
            return $cl
        }
        
        Write-Log "Could not determine changelist (output: $output)" "VERBOSE"
        throw "Could not determine changelist (output: $output)"
        
    } catch {
        $Message = $_.Exception.Message
        Write-Log "Could not get changelist info: $Message" "WARNING"
        throw [BuildException]::new(
            "Could not get changelist info: $Message",
            "Perforce",
            "Check your Perforce connection and workspace"
        )
    } finally {
        Pop-Location
    }
}

function Test-CodeChanges {
    <#
    .SYNOPSIS
        Check if code files changed in a specific changelist or range
    #>
    param(
        [int]$Changelist,
        [int]$FromCL = $null
    )

    try {
        # Change to project root for p4 commands
        Push-Location $script:projectRoot

        if ($FromCL)
        {
            Write-Log "Checking for code changes between CL $FromCL and CL $Changelist" "VERBOSE"
            # Use depot syntax to search in submitted changelists (not just #have)
            # Search submitted changelists in range, excluding FromCL
            $changesOutput = p4 changes -m 100 "//...@>$FromCL,@<=$Changelist" 2>&1

            # Filter out error records and keep only string output
            $changes = @($changesOutput | Where-Object { $_ -is [String] -and $_.Trim() -ne "" })

            Write-Log "p4 changes returned $($changes.Count) changelist(s)" "VERBOSE"
            if ($changes.Count -eq 0) {
                Write-Log "No changelists found in range >$FromCL to <=$Changelist" "VERBOSE"
                Pop-Location
                return $false
            }
        }
        else
        {
            Write-Log "Checking for code changes in CL $Changelist" "VERBOSE"
            $changes = @($Changelist)
        }

        $codeExtensions = Get-ConfigValue $script:CONSTANTS.ConfigKeys.PerforceFileExtentions @(".cpp", ".h")
        $foundChanges = $false

        foreach ($cl in $changes)
        {
            $clNum = $cl

            if ($cl -match "Change (\d+)")
            {
                $clNum = [int]$Matches[1]
            }

            Write-Log "Describing CL $clNum" "VERBOSE"

            $description = p4 describe -s $clNum 2>&1 | Out-String
            Write-Log "CL $clNum description: `n$description"
            foreach ($ext in $codeExtensions)
            {
                $pattern = [regex]::Escape($ext) + "#\d+"
                if ($description -match $pattern)
                {
                    Write-Log "Found code changes in CL $clNum (matched: $ext)" "VERBOSE"
                    $foundChanges = $true
                }
            }
        }

        if (-not $foundChanges)
        {
            Write-Log "No code changes detected" "VERBOSE"
        }

        Pop-Location
        return $foundChanges

    } catch {
        $Message = $_.Exception.Message
        Write-Log "Could not check for code changes: $Message" "WARNING"
        Pop-Location
        return $true
    }
}

# ==========================================
# Build Functions
# ==========================================

function Invoke-ProjectBuild {
    <#
    .SYNOPSIS
        Build the Unreal project with real-time output
    #>
    param(
        [string]$UERoot,
        [switch]$CleanBuild
    )
    
    Write-Header "BUILDING PROJECT"
    
    if ($CleanBuild) {
        Write-Host "Clean build requested - this will take longer" -ForegroundColor Yellow
    } else {
        Write-Host "Performing incremental build" -ForegroundColor Cyan
    }
    
    Write-Host "Estimated time: 5-15 minutes (depending on changes)" -ForegroundColor Gray
    Write-Host ""
    
    $buildBat = Join-Path $UERoot $script:CONSTANTS.Paths.UnrealBuildBat
    
    # Build arguments
    $buildArgs = @(
        "$($script:projectName)Editor",
        "Win64",
        "Development",
        "`"$($script:projectFile)`""
    )
    
    if ($CleanBuild) {
        $buildArgs += "-Clean"
    }
    
    # Optional: Add UBT logging (doesn't affect performance)
    $useUBTLogging = Get-ConfigValue $script:CONSTANTS.ConfigKeys.UseUBTLogging -DefaultValue $true
    if ($useUBTLogging) {
        $buildLogFile = Join-Path $logsDir $script:CONSTANTS.FileNames.BuildLogFileName
        $buildArgs += "-Log=`"$buildLogFile`""
        Write-Log "Build log will be saved to: $buildLogFile" "VERBOSE"
    }
    
    $buildArgsStr = $buildArgs -join " "
    Write-Log "Executing: $buildBat $buildArgsStr" "VERBOSE"
    
    Write-Host "Starting build..." -ForegroundColor Cyan
    Write-Host "Build output will stream below:" -ForegroundColor Gray
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor DarkGray
    
    $buildStartTime = Get-Date
    
    try {
        $process = Start-Process  -FilePath $buildBat `
                                  -ArgumentList $buildArgs `
                                  -NoNewWindow `
                                  -Wait `
                                  -PassThru
        
        $buildEndTime = Get-Date
        $buildDuration = $buildEndTime - $buildStartTime
        
        Write-Host "----------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
        
        if ($process.ExitCode -eq 0) {
            Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
            Write-Host "Build time: $($buildDuration.ToString('mm\:ss'))" -ForegroundColor Cyan
            Write-Host ""
            
            Write-Log "Build succeeded in $($buildDuration.TotalSeconds) seconds" "INFO"
            
            return $true
        } else {
            Write-Host "BUILD FAILED!" -ForegroundColor Red
            Write-Host "Exit code: $($process.ExitCode)" -ForegroundColor Red
            Write-Host "Build time: $($buildDuration.ToString('mm\:ss'))" -ForegroundColor Gray
            Write-Host ""
            
            if ($useUBTLogging) {
                Write-Host "Check the build log for details: $buildLogFile" -ForegroundColor Yellow
            }
            
            Write-Log "Build failed (Exit code: $($process.ExitCode), Duration: $($buildDuration.TotalSeconds)s)" "ERROR"
            
            return $false
        }
        
    } catch {
        $Message = $_.Exception.Message
        Write-Log "Build error: $Message" "ERROR"
        Write-DetailedError `
            -Message "Build process crashed: $Message" `
            -Category "Build" `
            -Suggestion "Check that Visual Studio Build Tools are installed and UE path is correct"
        return $false
    }
}

function Test-ProjectBinariesExist {
    <#
    .SYNOPSIS
        Check if project binaries exist
    #>
    
    $binaryPath = Join-Path $script:projectRoot "$($script:projectName)\Binaries\Win64\UnrealEditor-$($script:projectName).dll"
    
    $exists = Test-Path $binaryPath
    Write-Log "Checking for project binary: $binaryPath - Exists: $exists" "VERBOSE"
    
    return $exists
}

# ==========================================
# Editor Functions
# ==========================================

function Start-UnrealEditor {
    <#
    .SYNOPSIS
        Launch the Unreal Editor
    #>
    param([string]$UERoot)
    
    Write-Header "READY TO LAUNCH"
    
    $editorExe = Join-Path $UERoot $script:CONSTANTS.Paths.UnrealEditorExe
    
    if (-not (Test-Path $editorExe)) {
        Write-Log "Editor executable not found: $editorExe" "WARNING"
        Write-Host "Warning: UnrealEditor.exe not found" -ForegroundColor Yellow
        Write-Host "You may need to build the engine first" -ForegroundColor Yellow
        return $false
    }
    
    # Check if auto-launch is enabled
    $autoLaunch = Get-ConfigValue $script:CONSTANTS.ConfigKeys.EditorAutoLaunch -DefaultValue $false
    
    if (-not $autoLaunch){
        Write-Host "Launch Unreal Editor now? (Y/N): " -NoNewline -ForegroundColor Yellow
        $response = Read-Host
        $launch = $response -eq "Y" -or $response -eq "y"
    }
    
    if ($launch -or $autoLaunch) {

        if (-not $autoLaunch){
            Write-Host ""
            Write-Host "Save Response for future operations? (Y/N): " -NoNewline -ForegroundColor Yellow
            $response = Read-Host
            
            if ($response -eq "Y" -or $response -eq "y")
            {
                Set-ConfigValue $script:CONSTANTS.ConfigKeys.EditorAutoLaunch $true
            }
        }
        
        Write-Host "Launching editor..." -ForegroundColor Cyan
        
        try {
            Start-Process -FilePath $editorExe -ArgumentList "`"$($script:projectFile)`""
            
            Write-Host "Editor launched successfully!" -ForegroundColor Green
            Write-Host "It may take a minute to open." -ForegroundColor Gray
            Write-Host ""
            
            Write-Log "Editor launched successfully" "INFO"
            return $true
            
        } catch {
            Write-Log "Failed to launch editor: $($_.Exception.Message)" "ERROR"
            Write-Host "Failed to launch editor: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host ""
        Write-Host "Skipping editor launch" -ForegroundColor Gray
        Write-Log "User chose not to launch editor" "INFO"
        return $true
    }
}

# ==========================================
# Main Script
# ==========================================
function Main 
{
    <#
    .SYNOPSIS
        Unreal Engine Project - Sync and Build Automation Tool

    .DESCRIPTION
        Syncs project from Perforce, detects code changes, builds if needed,
        and optionally launches the Unreal Editor.

    .PARAMETER SkipSync
        Skip Perforce sync (useful for local testing)

    .PARAMETER Clean
        Force a clean rebuild (delete binaries first)

    .PARAMETER ForceBuild
        Force rebuild even if no code changes detected

    .PARAMETER NoPrompt
        Auto-launch editor without prompting

    .PARAMETER Verbose
        Show detailed operation logs

    .NOTES
        Version: 2.0
        Improvements over v1:
        - Fixed build performance (no output redirection)
        - Fixed sync reliability (proper P4 commands)
        - Auto-detects project name
        - Better error handling
        - Real-time progress feedback
    #>

    param(
        [switch]$SkipSync = $false,
        [switch]$Clean = $false,
        [switch]$ForceBuild = $false,
        [switch]$Verbose = $false
    )

    try 
    {
        # Initialize
        Initialize-Log
        
        Write-Host ""
        Write-Header "UNREAL ENGINE - SYNC AND BUILD TOOL v2.0"
        Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host ""
        
        # Initialize project paths
        Write-Log "Initializing project paths..." "INFO"
        Initialize-ProjectPaths
        
        Write-Host "Project: $script:projectName" -ForegroundColor White
        Write-Host "Location: $script:projectRoot" -ForegroundColor Gray
        Write-Host ""
        
        # Get Unreal Engine path
        $ueRoot = Get-UnrealEngineRoot
        Test-UnrealEngineValid -UERoot $ueRoot
        
        Write-Host "Unreal Engine: $ueRoot" -ForegroundColor White
        Write-Host ""
    
        # Check if initial build is needed
        if (-not (Test-ProjectBinariesExist)) {
            Write-Header "INITIAL BUILD REQUIRED"
            Write-Host "Project binaries not found. This is normal for first-time setup." -ForegroundColor Yellow
            Write-Host "An initial build is required before the editor can open." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "This will take 10-30 minutes depending on your hardware." -ForegroundColor Yellow
            Write-Host ""
            
            if (-not (Invoke-ProjectBuild -UERoot:$ueRoot -CleanBuild:$Clean)) {
                throw "Initial build failed"
            }
            
            Write-Host ""
        }
    
        # Sync from Perforce
        if (-not (Sync-FromPerforce -SkipSync:$SkipSync)) {
            throw "Perforce sync failed"
        }
    
        # Check for code changes and build if needed
        Write-Header "STEP 2: CHECKING FOR CODE CHANGES"
        try{
            $currentCL = Get-LatestHaveChangelist
        }
        catch {
            if (-not $ForceBuild) { throw $_.Exception.Message }
            $currentCL = $null
        }

        $needsBuild = $false
    
        if (-not $currentCL) {
            Write-Host "Warning: Could not determine current changelist" -ForegroundColor Yellow
            Write-Log "No changelist information available" "WARNING"
            
            if ($ForceBuild) {
                $needsBuild = $true
            }
        } else {
            Write-Host "Current changelist: $currentCL" -ForegroundColor Cyan
            
            # Check if we already built this CL
            $lastBuiltCL = Get-ConfigValue $script:CONSTANTS.ConfigKeys.LastBuiltCL -DefaultValue 0
            Write-Host "Last built changelist: $lastBuiltCL" -ForegroundColor Gray
            Write-Host ""
            
            if ($ForceBuild) {
                Write-Host "Force build requested" -ForegroundColor Yellow
                Write-Log "Force build requested by user" "INFO"
                $needsBuild = $true
                
            } elseif ($Clean) {
                Write-Host "Clean build requested" -ForegroundColor Yellow
                Write-Log "Clean build requested by user" "INFO"
                $needsBuild = $true
                
            } elseif ($currentCL -ne $lastBuiltCL) {
                Write-Host "Checking for code changes..." -ForegroundColor Cyan
                
                # Check if there are code changes
                if (Test-CodeChanges -Changelist $currentCL -FromCL $lastBuiltCL) {
                    Write-Host "Code changes detected!" -ForegroundColor Yellow
                    Write-Log "Code changes detected between CL $lastBuiltCL and CL $currentCL" "INFO"
                    $needsBuild = $true
                } else {
                    Write-Host "No code changes detected - skipping build" -ForegroundColor Green
                    Write-Log "No code changes detected" "INFO"
                    
                    # Update tracker even though we didn't build
                    Set-ConfigValue $script:CONSTANTS.ConfigKeys.lastBuiltCL $currentCL
                }
            } else {
                Write-Host "Project already built for this changelist" -ForegroundColor Green
                Write-Log "Already built CL $currentCL" "INFO"
            }
        }
    
        Write-Host ""
        
        # Build if needed
        if ($needsBuild) {
            if (Invoke-ProjectBuild -UERoot $ueRoot -CleanBuild:$Clean) {
                # Save the changelist we just built
                if ($currentCL) {
                    Set-ConfigValue $script:CONSTANTS.ConfigKeys.lastBuiltCL $currentCL
                    Write-Log "Updated last built CL to: $currentCL" "INFO"
                }
            } else {
                throw "Build failed"
            }
        } else {
            Write-Host "No build required" -ForegroundColor Green
            Write-Host ""
        }
        
        # Launch editor
        if (-not (Start-UnrealEditor -UERoot $ueRoot)) {
            Write-Log "Editor launch failed or cancelled" "WARNING"
        }
        
        # Success
        Write-Header "COMPLETE"
        Write-Host "Finished: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Log file: $logFile" -ForegroundColor DarkGray
        Write-Host ""
    
    $footer = @"

Finished: $(Get-Date)
==========================================
"@
        $footer | Out-File -FilePath $logFile -Append -Encoding UTF8
        
        Write-Log "Script completed successfully" "SUCCESS"
        
        return $true
    
    } 
    catch [BuildException] 
    {
        # Specific build exception with helpful info
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Red
        Write-Host "SCRIPT FAILED" -ForegroundColor Red
        Write-Host "==========================================" -ForegroundColor Red
        Write-Host ""
        Write-DetailedError `
            -Message $_.Exception.Message `
            -Category $_.Exception.Category `
            -Suggestion $_.Suggestion
        Write-Host "Log file: $logFile" -ForegroundColor Yellow
        Write-Host ""
        
        Write-Log "Script failed: $($_.Exception.Message)" "ERROR"
        
        return $false
    
    } 
    catch 
    {
        # Generic error
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Red
        Write-Host "SCRIPT FAILED" -ForegroundColor Red
        Write-Host "==========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        Write-Host "Stack trace:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        Write-Host ""
        Write-Host "Log file: $logFile" -ForegroundColor Yellow
        Write-Host ""
        
        Write-Log "Script failed with unhandled exception: $($_.Exception.Message)" "ERROR"
        
        return $false
    }
}
