# =============================================================================
# SETUP
# =============================================================================

BeforeAll {
    # Importar el script principal
    . "Source\sync_and_build.ps1"
    
    # Variables de test
    $script:testProjectRoot = "C:\TestProject"
    $script:testConfigPath = Join-Path $testProjectRoot "config.json"
}

# =============================================================================
# TESTS DE LOGGING
# =============================================================================

Describe "Initialize-Log" -Tag "Logging" {

    It "Crea archivo de log con header" {
        $testLogFile = "TestDrive:\testLog.log"
        $script:logFile = $testLogFile
        
        Mock Out-File { }
        
        Initialize-Log 
        
        Assert-MockCalled Out-File -Times 1
        Assert-MockCalled Out-File -ParameterFilter {
            $FilePath -eq $testLogFile
            $Encoding -eq "UTF8"
        }
    }
}

# =============================================================================

Describe "Write-Log" -Tag "Logging"{
    
    BeforeEach {
        $testLogFile = "TestDrive:\testLog.log"
        $script:logFile = $testLogFile
        Mock Get-Date { return "2024-12-31 23:59:59"}
    }

    Context "Escritura de logs" {

        It "Escribe mensaje en archivo de log" {
            Mock Write-Host { }
            Mock Add-Content { 
                param(
                    $Path,
                    $Value,
                    $Encoding
                )
                
                $Path | Should -Be $testLogFile
                $Value | Should -Match "\[2024-12-31 23:59:59\] \[INFO\] This is a test log message."
                $Encoding | Should -Be "UTF8"
            }

            $message = "This is a test log message."
            $level = "INFO"
            
            Write-Log -Message $message -Level $level
            
            Assert-MockCalled Add-Content -Times 1
        }

        It "Escribe todos los niveles de log correctamente" {
            Mock Get-ConfigValue {
                return $true
            }

            Mock Add-Content { }

            $testCases = @(
                @{ Level = "INFO";    Prefix = "[INFO]";    Color = "Cyan" }
                @{ Level = "SUCCESS"; Prefix = "[OK]";      Color = "Green" }
                @{ Level = "ERROR";   Prefix = "[ERROR]";   Color = "Red" }
                @{ Level = "WARNING"; Prefix = "[WARN]";    Color = "Yellow" }
                @{ Level = "VERBOSE"; Prefix = "[VERBOSE]"; Color = "Gray" }
            )

            foreach ($case in $testCases) {
                $script:capturedMessage = $null
                $script:capturedColor = $null
                
                Mock Write-Host {
                    param($Object, $ForegroundColor)
                    $script:capturedMessage = $Object
                    $script:capturedColor = $ForegroundColor
                }
                
                # Ejecutar
                Write-Log -Message "Test message" -Level $case.Level
                
                # Verificar
                $script:capturedMessage | Should -Be "$($case.Prefix) Test message"
                $script:capturedColor | Should -Be $case.Color
            }
        }

        It "No escribe mensajes VERBOSE cuando está deshabilitado" {
            
            Mock Write-Host { }
            
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq $script:CONSTANTS.ConfigKeys.LoggingVerbose) {
                    return $false
                }
                return $DefaultValue
            }
            
            Write-Log -Message "Verbose message" -Level "VERBOSE"

            Assert-MockCalled Write-Host -Times 0
            Assert-MockCalled Get-ConfigValue -Times 1 -ParameterFilter {
                $Path -eq $script:CONSTANTS.ConfigKeys.LoggingVerbose
            }
        }

        It "Escribe solo el mesaje cuando el nivel es desconocido" {
            Mock Add-Content { }
            Mock Write-Host {
                param($Object, $ForegroundColor)
                $script:capturedMessage = $Object
                $script:capturedColor = $ForegroundColor
            }
            
            Write-Log -Message "Unknown level message" -Level "UNKNOWN"
            
            $script:capturedMessage | Should -Be "Unknown level message"
            $script:capturedColor | Should -Be $null
        }
        
    }
}

# =============================================================================

Describe "Write-Header" -Tag "Logging"{

    Context "Formato del header" {
        It "Escribe header del log" {

            $script:timesCalled = 0
            $script:title = "Auto Sync and Build Tool v2.0"
            Mock Write-Host{
                param($Object, $ForegroundColor)
                if ($script:timesCalled -eq 0 -or $script:timesCalled -eq 4) {
                    $script:timesCalled++
                    $Object | Should -Be ""
                }
                elseif ($script:timesCalled -eq 1 -or $script:timesCalled -eq 3) {
                    $script:timesCalled++
                    $Object | Should -Match "=========================================="
                    $ForegroundColor | Should -Be "Cyan"
                }
                elseif ($script:timesCalled -eq 2) {
                    $script:timesCalled++
                    $Object | Should -Match $script:title
                    $ForegroundColor | Should -Be "Cyan"
                }
            }
            
            Write-Header $script:title
            
            Assert-MockCalled Write-Host -Times 5
        }
    }
}

# =============================================================================

Describe "Write-DetailedError" -Tag "Logging"{

    It "Escribe error detallado correctamente" {
        Mock Write-Host{ }
        Mock Write-Log { }

        $errorMessage = "An error occurred"
        $category = "Testing"
        
        Write-DetailedError -Message $errorMessage -Category $category
        
        Assert-MockCalled Write-Log -Times 1 -ParameterFilter{
            $Level -eq "ERROR" -and $Message -Match $errorMessage
        }
    }

    It "Escribe sugerencias si se proporcionan" {
        Mock Write-Log { }
        $script:callCounts = 0
        Mock Write-Host { 
            param($Object, $ForegroundColor)
            if ($script:callCounts -eq 0 -or $script:callCounts -eq 2 -or $script:callCounts -eq 5) {
                $script:callCounts++
                $Object | Should -Be ""
            }
            elseif ($script:callCounts -eq 1) {
                $script:callCounts++
                $Object | Should -Be "ERROR (Testing): An error occurred"
                $ForegroundColor | Should -Be "Red"
            }
            elseif ($script:callCounts -eq 3) {
                $script:callCounts++
                $Object | Should -Be "SUGGESTION: Try again later"
                $ForegroundColor | Should -Be "Yellow"
            }
        }

        $errorMessage = "An error occurred"
        $category = "Testing"
        $suggestion = "Try again later"
        
        Write-DetailedError -Message $errorMessage -Category $category -Suggestion $suggestion
        
        Assert-MockCalled Write-Log -Times 1 -ParameterFilter{
            $Level -eq "ERROR" -and $Message -eq $errorMessage
        }
    }
}

# =============================================================================
# TESTS DE CONFIGURACIÓN
# =============================================================================

Describe "Get-Config" -Tag "Configuracion" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
        Mock Write-Log { }
    }
    
    BeforeEach {
        $script:testConfigFile = "TestDrive:\testConfig.json"
        Mock -CommandName 'Get-Variable' -ParameterFilter { $Name -eq 'configFile' } -MockWith {
            [PSCustomObject]@{ Value = $script:testConfigFile }
        }
    }

    AfterEach {
        $script:configCache = $null
    }
    
    Context "Config no existe" {
        
        It "Crea config default cuando no existe archivo" {
            Mock Test-Path { $false }
            Mock Out-File { }
            
            $result = Get-Config
            
            $result | Should -Not -BeNullOrEmpty
            $result.version | Should -Be "2.0"
            $result.project | Should -Not -BeNullOrEmpty
            $result.unrealEngine | Should -Not -BeNullOrEmpty
            
            Assert-MockCalled Out-File -Times 1
        }
        
        It "Config default tiene todos los campos requeridos" {
            Mock Test-Path { $false }
            Mock Out-File { }
            
            
            $result = Get-Config
            
            $result.version | Should -Be "2.0"

            $result.project.name | Should -Be ""
            $result.project.displayName | Should -Be ""
            $result.project.autoDetect | Should -Be $true

            $result.unrealEngine.path | Should -Be ""
            $result.unrealEngine.version | Should -Be ""

            $result.perforce.autoSync | Should -Be $true
            $result.perforce.checkCodeChanges | Should -Be $true
            $result.perforce.parallelSync | Should -Be $false
            $result.perforce.fileExtensions | Should -Be @(".cpp", ".h", ".build.cs", ".target.cs", ".cs", ".ini", ".py")

            $result.build.lastBuiltCL | Should -Be 0
            $result.build.autoBuildOnCodeChange | Should -Be $true
            $result.build.showBuildOutput | Should -Be $true
            $result.build.useUBTLogging | Should -Be $true

            $result.editor.autoLaunch | Should -Be $false
            $result.editor.launchTimeout | Should -Be 30

            $result.logging.enabled | Should -Be $true
            $result.logging.verbose | Should -Be $false
            $result.logging.keepLogs | Should -Be 10
        }
    }
    
    Context "Config existe y es válido" {
        
        It "Lee config existente correctamente" {
            $MockConfig = @{
                version = "2.0"
                project = @{
                    name = "TestGame"
                    displayName = "My Test Game"
                    autoDetect = $true
                }
                unrealEngine = @{
                    path = "C:\UE_5.3"
                    version = "5.3"
                }
                build = @{
                    lastBuiltCL = 12345
                }
            } | ConvertTo-Json -Depth 10
            
            Mock Test-Path { $true }
            Mock Get-Content { $MockConfig }
            
            $result = Get-Config
            
            $result.project.name | Should -Be "TestGame"
            $result.unrealEngine.path | Should -Be "C:\UE_5.3"
            $result.build.lastBuiltCL | Should -Be 12345
            Mock Test-Path { $false }
        }
        
        It "Cachea el config después de primera lectura" {
            $mockConfigJson = '{"version":"2.0","project":{"name":"Test"}}' 
            
            Mock Test-Path { $true }
            Mock Get-Content { $mockConfigJson }
            
            Get-Config
            Get-Config
            
            Assert-MockCalled Get-Content -Times 1
            Mock Test-Path { $false }
        }
    }
    
    Context "Config corrupto o inválido" {
        
        It "Lanza BuildException cuando JSON es inválido" {
            Mock Test-Path { $true }
            Mock Get-Content { "{invalid json" }
            
            $exception = { Get-Config } | Should -Throw -PassThru
            $exception.Exception.GetType().Name | Should -Be "BuildException"
            Mock Test-Path { $false }
        }

        It "Lanza BuildException Con Mensaje Correcto"{
            Mock Test-Path { $true }
            Mock Get-Content { throw [System.IO.IOException]::new("File read error") }

            Set-Variable -Name "configFile" -Value $script:testConfigFile -Scope Script
            
            try {
                Get-Config
                Should -Fail "Expected BuildException was not thrown"
            } catch {
                $_.Exception.Message | Should -Be "Failed to read config file: File read error"
                $_.Exception.Category | Should -Be "Configuration"
                $_.Exception.Suggestion | Should -Be "Delete $script:testConfigFile and run the script again to recreate it"
            }
            
            Mock Test-Path { $false }
        }
        
        It "Migra config sin version automáticamente" {
            $mockOldConfig = @{
                project = @{ name = "OldGame" }
            } | ConvertTo-Json
            
            Mock Test-Path { $true }
            Mock Get-Content { $mockOldConfig }
            Mock Save-Config { }
            
            # Act
            $result = Get-Config
            
            # Assert
            $result.version | Should -Be "2.0"
            Assert-MockCalled Save-Config -Times 1
            Mock Test-Path { $false }
        }
    }
}

# =============================================================================

Describe "Save-Config" -Tag "Configuracion" {

    BeforeAll{
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
        Mock Write-Log { }
    }
    
    BeforeEach {

        $script:testConfigFile = "$PSscriptRoot\testConfig.json"

        Mock -CommandName 'Get-Variable' -ParameterFilter { $Name -eq 'configFile' } -MockWith {
            [PSCustomObject]@{ Value = $script:testConfigFile }
        }
    }
    
    Context "Guardado exitoso" {
        
        It "Guarda config correctamente como JSON" {
            $testConfig = [PSCustomObject]@{
                version = "2.0"
                project = [PSCustomObject]@{
                    name = "TestProject"
                }
            }
            
            Mock Out-File { }
            
            Save-Config -Config $testConfig
            
            Assert-MockCalled Out-File -Times 1
            Assert-MockCalled Write-Log -ParameterFilter { 
                $Level -eq "VERBOSE" 
            }
        }
        
        It "Actualiza cache después de guardar" {
            # Arrange
            $testConfig = [PSCustomObject]@{
                version = "2.0"
            }
            
            Mock Out-File { }
            Mock Write-Log { }
            
            # Act
            Save-Config -Config $testConfig
            
            # Assert - El cache debe actualizarse
            $script:configCache | Should -Not -BeNullOrEmpty
            $script:configCache.version | Should -Be "2.0"
        }
    }
    
    Context "Manejo de errores" {
        
        It "Lanza excepción si no puede escribir archivo" {
            $testConfig = [PSCustomObject]@{ version = "2.0" }
            
            Mock Out-File { throw "Access denied" }
            
            # Como atrapamos la excepción en el codigo no podemos usar Should -Throw, así veremos si Write-Log fue llamado por el error
            Save-Config -Config $testConfig
            Assert-MockCalled Write-Log -Times 1 -ParameterFilter {
                $Level -eq "ERROR"
            }
        }
        
        It "No actualiza cache si guardado falla" {
            $testConfig = [PSCustomObject]@{ version = "2.0" }
            $script:configCache = [PSCustomObject]@{ version = "1.0" }
            
            Mock Out-File { throw "Write failed" }
            
            Save-Config -Config $testConfig
            
            # Cache no debe cambiar
            $script:configCache.version | Should -Be "1.0"
        }
    }
}

# =============================================================================

Describe "Get-ConfigValue" -Tag "Configuracion" {
    
    BeforeEach {
        # Config de prueba para cada test
        $script:mockConfig = [PSCustomObject]@{
            Project = [PSCustomObject]@{
                Name = "TestGame"
                DisplayName = "My Test Game"
            }
            UnrealEngine = [PSCustomObject]@{
                Path = "C:\UE_5.3"
                Version = "5.3"
            }
            Build = [PSCustomObject]@{
                Options = [PSCustomObject]@{
                    Timeout = 300
                    UseUBT = $true
                }
            }
            CodeExtensions = @('.cpp', '.h', '.cs')
        }
        
        # Mock Get-Config para usar el config de prueba
        Mock Get-Config { return $script:mockConfig }
    }
    
    Context "Navegacion de paths" {

        It "Utiliza el config correcto"{
            $config = Get-Config
            $config | Should -Not -BeNullOrEmpty
            $config.Project.Name | Should -Be "TestGame"
        }
        
        It "Obtiene valor de primer nivel" {
            $result = Get-ConfigValue -Path "CodeExtensions"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 3
            $result[0] | Should -Be '.cpp'
        }
        
        It "Obtiene valor anidado (2 niveles)" {
            $result = Get-ConfigValue -Path "Project.Name"
            
            $result | Should -Be "TestGame"
        }
        
        It "Obtiene valor anidado profundo (3+ niveles)" {
            $result = Get-ConfigValue -Path "Build.Options.Timeout"
            
            $result | Should -Be 300
        }
    }
    
    Context "Manejo de valores inexistentes" {
        
        It "Retorna default value cuando path no existe" {
            $result = Get-ConfigValue -Path "NonExistent.Path" -DefaultValue "fallback"
            
            $result | Should -Be "fallback"
        }
        
        It "Retorna default cuando nivel intermedio falta" {
            $result = Get-ConfigValue -Path "Build.Missing.DeepValue" -DefaultValue 999
            
            $result | Should -Be 999
        }
        
        It "Retorna default array cuando propiedad no existe" {
            $result = Get-ConfigValue -Path "MissingExtensions" -DefaultValue @('.cpp')
            
            $result | Should -Be @('.cpp')
        }
    }
    
    Context "Tipos de datos" {
        
        It "Retorna booleano correctamente" {
            $result = Get-ConfigValue -Path "Build.Options.UseUBT"
            
            $result | Should -BeOfType [bool]
            $result | Should -Be $true
        }
        
        It "Retorna número correctamente" {
            $result = Get-ConfigValue -Path "Build.Options.Timeout"
            
            $result | Should -BeOfType [int]
        }
        
        It "Retorna array correctamente" {
            $result = Get-ConfigValue -Path "CodeExtensions"
            $result -is [array] | Should -Be $true
        }
    }
}

# =============================================================================

Describe "Set-ConfigValue" -Tag "Configuracion" {
    
    BeforeEach {
        $script:mockConfig = [PSCustomObject]@{
            Project = [PSCustomObject]@{
                Name = "TestGame"
                DisplayName = "My Test Game"
            }
            UnrealEngine = [PSCustomObject]@{
                Path = "C:\UE_5.3"
                Version = "5.3"
            }
        }
        
        Mock Get-Config { return $script:mockConfig }
        Mock Save-Config { }
    }

    Context "Navegación de paths cuando existen" {

        It "Actualiza valor existente" {
            Set-ConfigValue -Path "Project.Name" -Value "NewGameName"
            
            $script:mockConfig.Project.Name | Should -Be "NewGameName"
            Assert-MockCalled Save-Config -Times 1
        }
    }

    Context "Creación de propiedades cuando no existen" {
        It "Crea propiedades anidadas si no existen" {
            Set-ConfigValue -Path "Build.Options.Timeout" -Value 600
            
            $script:mockConfig.Build.Options.Timeout | Should -Be 600
            Assert-MockCalled Save-Config -Times 1
        }

        It "Crea propiedades del ultimo nivel si faltan" {
            Set-ConfigValue -Path "UnrealEngine.AutoLaunch" -Value $true
            
            $script:mockConfig.UnrealEngine.AutoLaunch | Should -Be $true
            Assert-MockCalled Save-Config -Times 1
        }
    }
}

# =============================================================================
# TESTS DE INICIACIÓN - RUTAS DE PROYECTO 
# =============================================================================

Describe "Initialize-Project" -Tag "IniciacionProyecto" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
        Mock Write-Log { }
    }
    
    BeforeEach {
        $script:projectRoot = "C:\TestProject"
        $script:projectFile = ""
        $script:scriptRoot = "C:\TestProject\Tools\AutoSyncBuild\Source"
    }

    Context "Proyecto configurado" {

        It "Encuentra archivo de proyecto correctamente" {
            $script:projectFile = "C:\TestProject\MyProject.uproject"
            
            Mock Test-Path {
                param($Path)
                return $Path -eq $script:projectFile
            }

            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq $script:CONSTANTS.ConfigKeys.ProjectName) {
                    return "MyProject"
                }
                return $DefaultValue
            }

            Mock Test-Path {return $true}
            
            Initialize-ProjectPaths
            
            $script:projectRoot | Should -Be "C:\TestProject"
            $script:projectFile | Should -Be "C:\TestProject\MyProject\MyProject.uproject"
        }

        It "No encuentra archivo de proyecto" {
            $script:projectFile = "C:\TestProject\NonExistent.uproject"
            
            Mock Test-Path { 
                if ($Path -match "NonExistent.uproject") {
                    return $false
                }
                return $true
            }

            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq $script:CONSTANTS.ConfigKeys.ProjectName) {
                    return "NonExistent"
                }
                return $DefaultValue
            }

            Mock Find-UnrealProject { 
                return [PSCustomObject]@{
                    FullName = "Existent.uproject"
                    BaseName = "Existent"
                    DirectoryName = "C:\TestProject\MyProject"
                }
            }

            Mock Set-ConfigValue { }
            
            Initialize-ProjectPaths
            
            Should -Invoke Set-ConfigValue -Times 2 
            Should -Invoke Test-Path -Times 2
            Should -Invoke Write-Log -Times 1 -ParameterFilter {
                $Message -eq "Project detected: Existent" -and $Level -eq "VERBOSE"
            }
            Should -Invoke Write-Log -Times 1 -ParameterFilter {
                $Message -eq "Project root: C:\TestProject" -and $Level -eq "VERBOSE"
            }
        }
    }

    Context "Proyecto no configurado" {

        It "Auto-detecta proyecto correctamente" {
            $script:projectFile = ""
            
            Mock Test-Path {
                return $true
            }

            Mock Get-ConfigValue {
                return $null
            }

            Mock Set-ConfigValue { }
            
            Mock Find-UnrealProject {
                return [PSCustomObject]@{
                    FullName = "MyProject.uproject"
                    BaseName = "MyProject"
                    DirectoryName = "C:\TestProject\GameProject"
                }
            }
            
            Initialize-ProjectPaths
            
            $script:projectRoot | Should -Be "C:\TestProject"
            $script:projectFile | Should -Be "MyProject.uproject"
        }

    }

    Context "Archivo de proyecto no existe" {

        It "Lanza excepción si no puede auto-detectar proyecto" {
            $script:projectFile = ""
            
            Mock Test-Path {
                return $false
            }

            Mock Get-ConfigValue {
                return $null
            }

            Mock Set-ConfigValue { }
            
            Mock Find-UnrealProject {
                return [PSCustomObject]@{
                    FullName = "MyProject.uproject"
                    BaseName = "MyProject"
                    DirectoryName = "C:\TestProject\GameProject"
                }
            }
            
            try{
                Initialize-ProjectPaths
                Should -Fail "Expected BuildException was not thrown"
            } catch {
                $_.Exception.Message | Should -Be "Project file not found: MyProject.uproject"
                $_.Exception.Category | Should -Be "Project Configuration"
                $_.Exception.Suggestion | Should -Be "Check the project name in config.json or move the script to the correct location"
            }
        }
    }
}

# =============================================================================
# TESTS DE PERFORCE - ENVIRONMENT
# =============================================================================

Describe "Test-PerforceEnvironment" -Tag "Perforce" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        Mock Write-Log { }
    }

    Context "Caso: Entorno Perforce válido" {

        It "Retorna el nombre del cliente cuando la conexión es exitosa" {
            $expectedClient = "my-workspace"

            Mock Get-Command {
                param($Name, $ErrorAction)
                if ($Name -eq "p4") {
                    return [PSCustomObject]@{
                        Name = "p4"
                        Source = "C:\Program Files\Perforce\p4.exe"
                    }
                }
                return $null
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "User name: john.doe",
                    "Client name: my-workspace",
                    "Client host: DESKTOP-ABC123",
                    "Client root: C:\Workspace",
                    "Server address: perforce:1666"
                )
            }

            $result = Test-PerforceEnvironment

            $result | Should -Be $expectedClient
        }

        It "Escribe log con la ubicación del comando p4" {
            Mock Get-Command {
                return [PSCustomObject]@{
                    Name = "p4"
                    Source = "C:\Perforce\p4.exe"
                }
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Client name: test-workspace"
            }

            Test-PerforceEnvironment

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "P4 command found.*C:\\Perforce\\p4.exe" -and $Level -eq "VERBOSE"
            }
        }

        It "Escribe log con el nombre del cliente" {
            Mock Get-Command {
                return [PSCustomObject]@{ Source = "p4.exe" }
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Client name: development-workspace"
            }

            Test-PerforceEnvironment

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "P4 Client: development-workspace" -and $Level -eq "VERBOSE"
            }
        }

        It "Extrae correctamente el nombre del cliente con espacios extra" {
            Mock Get-Command { return [PSCustomObject]@{ Source = "p4.exe" } }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "User name: user",
                    "Client name:    workspace-with-spaces   ",
                    "Server address: server:1666"
                )
            }

            $result = Test-PerforceEnvironment

            $result | Should -Be "workspace-with-spaces"
        }

        It "Funciona con diferentes formatos de salida de p4 info" {
            Mock Get-Command { return [PSCustomObject]@{ Source = "p4.exe" } }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "Perforce client: p4client version 2023.1",
                    "",
                    "User name: john.doe",
                    "Client name: ue5-development",
                    "Client host: WORKSTATION-01",
                    "Client root: C:\P4\UE5"
                )
            }

            $result = Test-PerforceEnvironment

            $result | Should -Be "ue5-development"
        }
    }

    Context "Caso: Perforce no está instalado" {

        It "Lanza excepción cuando p4 no está en PATH" {
            Mock Get-Command {
                param($Name, $ErrorAction)
                return $null
            }

            try {
                Test-PerforceEnvironment
                Should -Fail "No se lanzó la excepción esperada"
            }
            catch {
                $_.Exception.Message | Should -Match "Perforce command-line tools not found"
                $_.Exception.Category | Should -Be "Perforce"
                $_.Exception.Suggestion | Should -Match "Install Perforce command-line tools"
            }
        }
    }

    Context "Caso: Falla la conexión a Perforce" {

        It "Lanza excepción cuando p4 info retorna error (LASTEXITCODE != 0)" {
            Mock Get-Command {
                return [PSCustomObject]@{ Source = "p4.exe" }
            }

            Mock p4 {
                $global:LASTEXITCODE = 1
                return "Perforce client error: Connect to server failed"
            }

            try {
                Test-PerforceEnvironment
                Should -Fail "No se lanzó la excepción esperada"
            }
            catch {
                $_.Exception.Message | Should -Match "Cannot connect to Perforce server"
                $_.Exception.Category | Should -Be "Perforce"
                $_.Exception.Suggestion | Should -Match "p4 info"
            }
        }
    }

    Context "Caso: No hay workspace configurado" {

        It "Lanza excepción cuando no hay línea 'Client name' en la salida" {
            Mock Get-Command {
                return [PSCustomObject]@{ Source = "p4.exe" }
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "User name: john.doe",
                    "Server address: perforce:1666"
                )
            }

            try {
                Test-PerforceEnvironment
                Should -Fail "No se lanzó la excepción esperada"
            }
            catch {
                $_.Exception.Message | Should -Match "Cannot connect to Perforce server"
                $_.Exception.Message | Should -Match "No client workspace configured"
            }
        }

        It "Lanza BuildException cuando falta el workspace" {
            Mock Get-Command {
                return [PSCustomObject]@{ Source = "p4.exe" }
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "User name: user",
                    "Host: workstation"
                )
            }

            try {
                Test-PerforceEnvironment
                Should -Fail "No se lanzó la excepción esperada"
            }
            catch {
                $_.Exception.Message | Should -Match "Cannot connect to Perforce server"
                $_.Exception.Message | Should -Match "No client workspace configured"
            }
        }

        It "Cuando Client name está vacío" {
            Mock Get-Command {
                return [PSCustomObject]@{ Source = "p4.exe" }
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "User name: user",
                    "Client name:    ",
                    "Server: server:1666"
                )
            }

            $result = Test-PerforceEnvironment

            # Debería retornar string vacío cuando Client name está vacío
            $result | Should -Be ""
        }
    }

    Context "Caso: Múltiples líneas Client name (edge case)" {

        It "Toma la primera línea cuando hay múltiples Client name" {
            Mock Get-Command {
                return [PSCustomObject]@{ Source = "p4.exe" }
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "Client name: first-workspace",
                    "Client name: second-workspace",
                    "User name: user"
                )
            }

            $result = Test-PerforceEnvironment

            $result | Should -Be "first-workspace"
        }
    }
}

# =============================================================================
# TESTS DE PERFORCE - SYNC
# =============================================================================

Describe "Sync-FromPerforce" -Tag "Perforce" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        $script:projectRoot = "C:\TestProject"
        $script:callCount = 0

        if (-not $script:CONSTANTS) {
            $script:CONSTANTS = @{
                PerforceUpToDate = "file\(s\) up-to-date\."
            }
        }

        Mock Test-PerforceEnvironment { return "test-workspace" }
        Mock Write-Host { }
        Mock Write-Log { }
        Mock Write-Header { }
        Mock Push-Location { }
        Mock Pop-Location { }
        Mock Write-DetailedError { }
    }

    Context "Caso: SkipSync flag" {

        It "Retorna true sin ejecutar p4 cuando SkipSync está activo" {
            Mock p4 { throw "No debería llamarse" }
            Mock Test-PerforceEnvironment { throw "No debería llamarse" }

            $result = Sync-FromPerforce -SkipSync:$true

            $result | Should -Be $true
        }
    }

    Context "Caso: Ya está actualizado (up-to-date)" {

        It "Retorna true cuando ya está up-to-date con mismo CL" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                Write-Error "file(s) up-to-date."
                $global:LASTEXITCODE = 0
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $true
        }

        It "Ejecuta p4 sync con argumentos correctos" {
            Mock Get-LatestHaveChangelist { return 12345 }

            $capturedArgs = $null
            Mock p4 {
                param([Parameter(ValueFromRemainingArguments)]$Arguments)
                $script:capturedArgs = $Arguments
                Write-Error "file(s) up-to-date."
                $global:LASTEXITCODE = 0
            }

            Sync-FromPerforce -SkipSync:$false

            $script:capturedArgs | Should -Contain "sync"
            $script:capturedArgs | Should -Contain "..."
        }
    }

    Context "Caso: Sincronización exitosa con cambios" {

        It "Retorna true cuando sincroniza archivos correctamente" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 12340
                }
                return 12345
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "//depot/Source/Player.cpp#5 - updating C:\Project\Source\Player.cpp",
                    "//depot/Source/Game.h#3 - updating C:\Project\Source\Game.h"
                )
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $true
        }
    }

    Context "Caso: Errores de conexión y permisos" {

        It "Retorna false cuando hay access denied" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                Write-Error "Access denied"
                $global:LASTEXITCODE = 1
                return "error: Access denied to //depot/..."
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $false
        }

        It "Retorna false cuando p4 sync falla con exit code != 0" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                Write-Error "Connection timeout"
                $global:LASTEXITCODE = 1
                return "error: TCP connect failed"
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $false
        }

        It "Llama a Write-DetailedError cuando hay error de acceso" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                $global:LASTEXITCODE = 1
                Write-Error "Permission denied"
                return "error: Permission denied"
            }

            Sync-FromPerforce -SkipSync:$false

            Should -Invoke Write-DetailedError -Times 1 
        }

        It "Retorna false y llama Write-DetailedError cuando exit code es diferente de 0" {
            Mock Get-LatestHaveChangelist { return 12345 }

            Mock p4 {
                $global:LASTEXITCODE = 42
                return @()
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $false
            Should -Invoke Write-DetailedError -Times 1
        }
    }

    Context "Caso: Test-PerforceEnvironment falla" {

        It "Retorna false cuando Test-PerforceEnvironment lanza BuildException" {
            Mock Test-PerforceEnvironment {
                throw [BuildException]::new("P4 not found", "Perforce", "Install p4")
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $false
        }

        It "Retorna false cuando Test-PerforceEnvironment lanza excepción genérica" {
            Mock Test-PerforceEnvironment {
                throw "Network error"
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $false
        }
    }

    Context "Caso: Gestión de ubicación (Push/Pop-Location)" {

        It "Ejecuta Push-Location al project root antes de sync" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                $global:LASTEXITCODE = 0
                Write-Error "file(s) up-to-date."
            }

            Sync-FromPerforce -SkipSync:$false

            Should -Invoke Push-Location -ParameterFilter {
                $Path -eq "C:\TestProject"
            }
        }

        It "Ejecuta Pop-Location después de sync (éxito)" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                $global:LASTEXITCODE = 0
                Write-Error "file(s) up-to-date."
            }

            Sync-FromPerforce -SkipSync:$false

            Should -Invoke Pop-Location -Times 1
        }

        It "Ejecuta Pop-Location después de sync (fallo)" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                $global:LASTEXITCODE = 1
                Write-Error "Error"
            }

            Sync-FromPerforce -SkipSync:$false

            Should -Invoke Pop-Location -Times 1
        }
    }

    Context "Caso: Validación de workflow" {

        It "Llama a Write-Header con el mensaje correcto" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                $global:LASTEXITCODE = 0
                Write-Error "file(s) up-to-date."
            }

            Sync-FromPerforce -SkipSync:$false

            Should -Invoke Write-Header -ParameterFilter {
                $Text -match "STEP 1.*SYNCING FROM PERFORCE"
            }
        }

        It "Llama a Test-PerforceEnvironment primero" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                $global:LASTEXITCODE = 0
                Write-Error "file(s) up-to-date."
            }

            Sync-FromPerforce -SkipSync:$false

            Should -Invoke Test-PerforceEnvironment -Times 1
        }

        It "Muestra el nombre del workspace en consola" {
            Mock Test-PerforceEnvironment { return "my-workspace" }
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                $global:LASTEXITCODE = 0
                Write-Error "file(s) up-to-date."
            }

            Sync-FromPerforce -SkipSync:$false

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Client workspace: my-workspace"
            }
        }

        It "Muestra el changelist actual antes de sincronizar" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 12340
                }
                return 12340
            }
            Mock p4 {
                $global:LASTEXITCODE = 0
                Write-Error "file(s) up-to-date."
            }

            Sync-FromPerforce -SkipSync:$false

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Current changelist: 12340"
            }
        }

        It "Escribe log verbose antes de ejecutar p4 sync" {
            Mock Get-LatestHaveChangelist { return 12345 }
            Mock p4 {
                $global:LASTEXITCODE = 0
                Write-Error "file(s) up-to-date."
            }

            Sync-FromPerforce -SkipSync:$false

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Executing: p4 sync" -and $Level -eq "VERBOSE"
            }
        }
    }

    Context "Caso: Diferentes tipos de cambios en archivos" {

        It "Detecta archivos updating" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 100
                }
                return 101
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @("//depot/file.cpp - updating C:\file.cpp")
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $true
        }

        It "Detecta archivos added" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 100
                }
                return 101
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @("//depot/newfile.cpp - added as C:\newfile.cpp")
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $true
        }

        It "Detecta archivos deleted" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 100
                }
                return 101
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @("//depot/oldfile.cpp - deleted as C:\oldfile.cpp")
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $true
        }

        It "Maneja mezcla de tipos de cambios" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 100
                }
                return 105
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "//depot/file1.cpp - updating",
                    "//depot/file2.h - added",
                    "//depot/file3.cpp - deleted",
                    "//depot/file4.uasset - updating"
                )
            }

            $result = Sync-FromPerforce -SkipSync:$false

            $result | Should -Be $true
        }
    }

    Context "Caso: Parámetro Verbose" {

        It "Muestra detalles de archivos cuando Verbose es true y hay cambios (<=20 archivos)" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 100
                }
                return 101
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "//depot/Source/File1.cpp - updating C:\Project\Source\File1.cpp",
                    "//depot/Source/File2.h - updating C:\Project\Source\File2.h",
                    "//depot/Content/Asset.uasset - added as C:\Project\Content\Asset.uasset"
                )
            }

            Sync-FromPerforce -SkipSync:$false -Verbose:$true

            # Verifica que Write-Host fue llamado para mostrar cada archivo
            # Se espera al menos 3 llamadas para los archivos individuales
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "//depot/Source/File1.cpp" -and $ForegroundColor -eq "DarkGray"
            }
        }

        It "NO muestra detalles de archivos cuando Verbose es false" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 100
                }
                return 101
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return @(
                    "//depot/Source/File1.cpp - updating C:\Project\Source\File1.cpp",
                    "//depot/Source/File2.h - updating C:\Project\Source\File2.h"
                )
            }

            # Capturar las llamadas a Write-Host
            $writeHostCalls = @()
            Mock Write-Host {
                param($Object, $ForegroundColor)
                $script:writeHostCalls += @{
                    Object = $Object
                    Color = $ForegroundColor
                }
            }

            Sync-FromPerforce -SkipSync:$false -Verbose:$false

            # Verificar que NO se mostraron los detalles de archivos con espacios
            $detailCalls = $script:writeHostCalls | Where-Object {
                $_.Object -match "^\s+//"
            }
            $detailCalls.Count | Should -Be 0
        }

        It "NO muestra detalles cuando hay más de 20 archivos aunque Verbose sea true" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 100
                }
                return 101
            }

            # Crear array con 25 archivos
            $files = @()
            for ($i = 1; $i -le 25; $i++) {
                $files += "//depot/Source/File$i.cpp - updating C:\Project\Source\File$i.cpp"
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return $files
            }

            # Capturar las llamadas a Write-Host
            $writeHostCalls = @()
            Mock Write-Host {
                param($Object, $ForegroundColor)
                $script:writeHostCalls += @{
                    Object = $Object
                    Color = $ForegroundColor
                }
            }

            Sync-FromPerforce -SkipSync:$false -Verbose:$true

            # Verificar que NO se mostraron los detalles con espacios (porque son >20)
            $detailCalls = $script:writeHostCalls | Where-Object {
                $_.Object -match "^\s+//"
            }
            $detailCalls.Count | Should -Be 0
        }

        It "Funciona correctamente cuando no hay archivos cambiados con Verbose true" {
            Mock Get-LatestHaveChangelist { return 12345 }

            Mock p4 {
                $global:LASTEXITCODE = 0
                Write-Error "file(s) up-to-date."
            }

            $result = Sync-FromPerforce -SkipSync:$false -Verbose:$true

            $result | Should -Be $true

            # No debería llamar a Write-Host para mostrar archivos (no hay archivos)
            Should -Not -Invoke Write-Host -ParameterFilter {
                $Object -match "Files changed:"
            }
        }

        It "Límite exacto de 20 archivos muestra detalles con Verbose true" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 100
                }
                return 101
            }

            # Exactamente 20 archivos
            $files = @()
            for ($i = 1; $i -le 20; $i++) {
                $files += "//depot/Source/File$i.cpp - updating"
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return $files
            }

            Sync-FromPerforce -SkipSync:$false -Verbose:$true

            # Con exactamente 20, SÍ debería mostrar detalles
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "^\s+" -and $ForegroundColor -eq "DarkGray"
            }
        }

        It "21 archivos NO muestra detalles aunque Verbose sea true" {
            Mock Get-LatestHaveChangelist {
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 100
                }
                return 101
            }

            # 21 archivos (uno más que el límite)
            $files = @()
            for ($i = 1; $i -le 21; $i++) {
                $files += "//depot/Source/File$i.cpp - updating"
            }

            Mock p4 {
                $global:LASTEXITCODE = 0
                return $files
            }

            # Capturar las llamadas
            $writeHostCalls = @()
            Mock Write-Host {
                param($Object, $ForegroundColor)
                $script:writeHostCalls += @{
                    Object = $Object
                    Color = $ForegroundColor
                }
            }

            Sync-FromPerforce -SkipSync:$false -Verbose:$true

            # Verificar que NO se mostraron detalles
            $detailCalls = $script:writeHostCalls | Where-Object {
                $_.Object -match "^\s+//"
            }
            $detailCalls.Count | Should -Be 0
        }
    }
}

# =============================================================================
# TESTS DE GET LATEST HAVE CHANGELIST
# =============================================================================

Describe "Get-LatestHaveChangelist" -Tag "Perforce" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        $script:projectRoot = "C:\TestProject"

        Mock Write-Log { }
        Mock Push-Location { }
        Mock Pop-Location { }
    }

    Context "Caso: Changelist válido retornado" {

        It "Retorna el número de changelist cuando p4 changes tiene éxito" {
            Mock p4 {
                param([Parameter(ValueFromRemainingArguments)]$Arguments)
                $global:LASTEXITCODE = 0
                return "Change 12345 on 2024/12/25 by user@workspace"
            }

            $result = Get-LatestHaveChangelist

            $result | Should -Be 12345
        }

        It "Extrae correctamente el changelist de diferentes formatos" {
            $testCases = @(
                @{ Output = "Change 100 on 2024/01/01 by user@ws"; Expected = 100 }
                @{ Output = "Change 999999 on 2024/12/31 by admin@main"; Expected = 999999 }
                @{ Output = "Change 1 on 2024/01/01 by test@test"; Expected = 1 }
                @{ Output = "Change 54321 by user"; Expected = 54321 }
            )

            foreach ($case in $testCases) {
                Mock p4 {
                    $global:LASTEXITCODE = 0
                    return $case.Output
                }

                $result = Get-LatestHaveChangelist

                $result | Should -Be $case.Expected
            }
        }

        It "Escribe log con el changelist encontrado" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Change 12345 on 2024/12/25 by user@workspace"
            }

            Get-LatestHaveChangelist

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Latest have changelist: 12345" -and $Level -eq "VERBOSE"
            }
        }
    }

    Context "Caso: No se puede determinar changelist - lanza excepción" {

        It "Lanza excepción cuando LASTEXITCODE no es 0" {
            Mock p4 {
                $global:LASTEXITCODE = 1
                return "error: Connection failed"
            }

            { Get-LatestHaveChangelist } | Should -Throw
        }

        It "Lanza excepción cuando la salida no contiene patrón 'Change'" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "No files to sync"
            }

            { Get-LatestHaveChangelist } | Should -Throw
        }

        It "Lanza excepción cuando la salida no contiene número" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Change ABC on 2024/12/25"
            }

            { Get-LatestHaveChangelist } | Should -Throw
        }

        It "Escribe log verbose cuando no puede determinar changelist antes de lanzar excepción" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "No changes found"
            }

            try {
                Get-LatestHaveChangelist
            } catch { }

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Could not determine changelist" -and $Level -eq "VERBOSE"
            }
        }

        It "Lanza excepción cuando p4 retorna salida vacía" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return ""
            }

            { Get-LatestHaveChangelist } | Should -Throw
        }
    }

    Context "Caso: BuildException cuando hay errores" {

        It "BuildException contiene mensaje original cuando p4 falla" {
            Mock p4 {
                throw "Connection timeout"
            }

            try {
                Get-LatestHaveChangelist
                throw "Test should have thrown"
            } catch [BuildException] {
                $_.Exception.Message | Should -Match "Could not get changelist info"
                $_.Exception.Message | Should -Match "Connection timeout"
            }
        }

        It "BuildException tiene Category 'Perforce'" {
            Mock p4 {
                throw "Network error"
            }

            try {
                Get-LatestHaveChangelist
                throw "Test should have thrown"
            } catch {
                $_.Exception.Category | Should -Be "Perforce"
                $_.Exception.Suggestion | Should -Be "Check your Perforce connection and workspace"
            }
        }

        It "Escribe log de warning cuando hay excepción antes de lanzar BuildException" {
            Mock p4 {
                throw "Connection timeout"
            }

            try {
                Get-LatestHaveChangelist
            } catch { }

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Could not get changelist info" -and
                $Message -match "Connection timeout" -and
                $Level -eq "WARNING"
            }
        }
    }

    Context "Caso: Gestión de ubicación (Push/Pop-Location)" {

        It "Ejecuta Push-Location al project root antes de p4" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Change 12345 on 2024/12/25 by user@workspace"
            }

            Get-LatestHaveChangelist

            Should -Invoke Push-Location -ParameterFilter {
                $Path -eq "C:\TestProject"
            }
        }

        It "Ejecuta Pop-Location después de éxito" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Change 12345 on 2024/12/25 by user@workspace"
            }

            Get-LatestHaveChangelist

            Should -Invoke Pop-Location -Times 1
        }

        It "Ejecuta Pop-Location después de throw de string (finally block)" {
            Mock p4 {
                $global:LASTEXITCODE = 1
                return "error"
            }

            try {
                Get-LatestHaveChangelist
            } catch { }

            Should -Invoke Pop-Location -Times 1
        }

        It "Ejecuta Pop-Location después de BuildException (finally block)" {
            Mock p4 {
                throw "Error"
            }

            try {
                Get-LatestHaveChangelist
            } catch { }

            Should -Invoke Pop-Location -Times 1
        }
    }

    Context "Caso: Comando p4 correcto" {

        It "Ejecuta p4 changes con argumentos correctos" {
            $capturedArgs = $null
            Mock p4 {
                param([Parameter(ValueFromRemainingArguments)]$Arguments)
                $script:capturedArgs = $Arguments
                $global:LASTEXITCODE = 0
                return "Change 12345 on 2024/12/25 by user@workspace"
            }

            Get-LatestHaveChangelist

            $script:capturedArgs | Should -Contain "changes"
            $script:capturedArgs | Should -Contain "-m1"
            $script:capturedArgs | Should -Contain "...#have"
        }

        It "Escribe log verbose del comando ejecutado" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Change 12345 on 2024/12/25 by user@workspace"
            }

            Get-LatestHaveChangelist

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match 'Executing: p4 changes -m1 "\.\.\.#have"' -and $Level -eq "VERBOSE"
            }
        }
    }

    Context "Caso: Edge cases con regex" {

        It "Extrae el primer número cuando hay múltiples" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Change 12345 and 67890 on 2024/12/25"
            }

            $result = Get-LatestHaveChangelist

            $result | Should -Be 12345
        }

        It "Maneja números muy grandes" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Change 2147483647 on 2024/12/25"
            }

            $result = Get-LatestHaveChangelist

            $result | Should -Be 2147483647
        }

        It "Ignora texto antes y después del patrón" {
            Mock p4 {
                $global:LASTEXITCODE = 0
                return "Some text before Change 999 on 2024/12/25 and text after"
            }

            $result = Get-LatestHaveChangelist

            $result | Should -Be 999
        }
    }
}

# =============================================================================
# TESTS DE DETECCIÓN DE CAMBIOS DE CÓDIGO
# =============================================================================

Describe "Test-CodeChanges" -Tag "FuncionesTests" {
    
    BeforeEach {
        # Mock config con extensiones de código
        Mock Get-ConfigValue {
            param($Path, $DefaultValue)

            if ($Path -eq "CodeExtensions") {
                return @('.cpp', '.h', '.build.cs', '.cs')
            }
            return $DefaultValue
        }

        Mock Write-Log {}
        Mock Push-Location {}
        Mock Pop-Location {}
        Mock Write-Host {}

        Mock p4 {
            param([Parameter(ValueFromRemainingArguments)]$Arguments)

            $cmd = $Arguments[0]

            switch ($cmd) {
                'describe' {
                    $clNum = $Arguments[2]
                    $global:LASTEXITCODE = 0

                    switch ($clNum)
                    {
                        12340 {
                            return @(
                               "Change 12343 on 2024/12/20 by user@workspace

                                Fixed player movement bug

                            Affected files ...

                            ... //depot/Source/MyGame/Player.uasset#5 edit
                            ... //depot/Source/MyGame/PlayerController.uasset#3 edit")
                        }
                        12341 {
                            return @("Change 12344 on 2024/12/21 by user@workspace")
                        }
                        12345 {
                            return @("
                            Change 12345 on 2024/12/25 by user@workspace

                                Fixed player movement bug

                            Affected files ...

                            ... //depot/Source/MyGame/Player.cpp#5 edit
                            ... //depot/Source/MyGame/PlayerController.h#3 edit")
                        }
                        12346 {
                            return @("
                            Change 12346 by user@workspace

                            Updated UI textures

                        Affected files ...

                        ... //depot/Content/UI/MainMenu.uasset#2 edit
                        ... //depot/Content/Textures/Logo.png#1 add
                            ")
                        }
                        default {
                            $global:LASTEXITCODE = 1
                            return "Change $clNum by user"
                        }
                    }
                }

                'changes' {
                    $global:LASTEXITCODE = 0

                    # New format: p4 changes -m 100 "//...@>FromCL,@<=ToCL"
                    # Arguments will be: ['changes', '-m', '100', '//...@>12340,@<=12341']
                    $pathSpec = if ($Arguments.Count -ge 4) { $Arguments[3] } else { $Arguments[1] }

                    # Handle new depot syntax //...@>X,@<=Y
                    if ($pathSpec -match "//\.\.\.@>(\d+),@<=(\d+)") {
                        $fromCL = [int]$Matches[1]
                        $toCL = [int]$Matches[2]

                        # Return only CLs in range (excluding fromCL)
                        if ($fromCL -eq 12340 -and $toCL -eq 12341) {
                            return @("Change 12341 on 2024/12/21 by user@workspace")
                        }
                        elseif ($fromCL -eq 12343 -and $toCL -eq 12345) {
                            return @(
                                "Change 12345 on 2024/12/25 by user@workspace",
                                "Change 12344 on 2024/12/24 by user@workspace"
                            )
                        }
                    }
                    # Handle old syntax for backward compatibility
                    elseif ($pathSpec -eq "...@12340,12341") {
                        return @(
                            "Change 12341 on 2024/12/21 by user@workspace",
                            "Change 12340 on 2024/12/20 by user@workspace"
                        )
                    }

                    # Default fallback
                    return @(
                        "Change 12345 on 2024/12/25 by user@workspace",
                        "Change 12344 on 2024/12/24 by user@workspace",
                        "Change 12343 on 2024/12/23 by user@workspace"
                    )
                }

                default {
                    $global:LASTEXITCODE = 0
                    return @()
                }
            }
        }

    }
    
    Context "Caso: Changelist único con código" {
        
        It "Detecta cambios cuando hay archivos .cpp" {
            $result = Test-CodeChanges -Changelist 12345
            
            $result | Should -Be $true
        }
        
        It "No detecta cambios cuando solo hay assets" {
            $result = Test-CodeChanges -Changelist 12346
            
            $result | Should -Be $false
        }
    }
    
    Context "Caso: Rango de changelists (FromCL)" {
        
        It "Detecta cambios en rango de CLs" {
            $result = Test-CodeChanges -Changelist 12345 -FromCL 12343
            
            $result | Should -Be $true
        }
        
        It "No detecta cambios cuando rango solo tiene assets" {
            $result = Test-CodeChanges -Changelist 12341 -FromCL 12340
            
            $result | Should -Be $false
        }
    }
    
    Context "Extracción de números de changelist" {

        It "Extrae correctamente de formato 'Change 12345'" {
            $cl = "Change 12345 on 2024/12/25 by user@workspace"

            $clNum = $null
            if ($cl -match "Change (\d+)") {
                $clNum = [int]$Matches[1]
            }

            $clNum | Should -Be 12345
            $clNum | Should -BeOfType [int]
        }

        It "Maneja int directo sin conversión" {
            $cl = 67890
            $clNum = $cl

            $clNum | Should -Be 67890
        }
    }

    Context "Caso: Manejo de excepciones" {

        It "Retorna true cuando p4 changes lanza excepción" {
            Mock p4 {
                throw "Network timeout"
            }

            $result = Test-CodeChanges -Changelist 12345 -FromCL 12340

            $result | Should -Be $true
        }

        It "Retorna true cuando p4 describe lanza excepción" {
            Mock p4 {
                param([Parameter(ValueFromRemainingArguments)]$Arguments)

                $cmd = $Arguments[0]

                if ($cmd -eq 'describe') {
                    throw "Connection lost"
                } else {
                    $global:LASTEXITCODE = 0
                    return @("Change 12345 on 2024/12/25")
                }
            }

            $result = Test-CodeChanges -Changelist 12345

            $result | Should -Be $true
        }

        It "Escribe log WARNING cuando hay excepción" {
            Mock p4 {
                throw "Access denied"
            }

            Test-CodeChanges -Changelist 12345 -FromCL 12340

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Could not check for code changes" -and
                $Message -match "Access denied" -and
                $Level -eq "WARNING"
            }
        }

        It "Retorna true en caso de error (fail-safe behavior)" {
            Mock p4 {
                throw "Critical error"
            }

            $result = Test-CodeChanges -Changelist 999

            $result | Should -Be $true
        }
    }
}

Describe "Test-ProjectBinariesExist" -Tag "FuncionesTests" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        $script:projectRoot = "C:\MyProject"
        $script:projectName = "MyGame"

        Mock Write-Log { }
    }

    Context "Caso: Binarios existen" {

        It "Retorna true cuando el archivo DLL existe" {
            Mock Test-Path {
                param($Path)
                if ($Path -match "UnrealEditor-MyGame\.dll") {
                    return $true
                }
                return $false
            }

            $result = Test-ProjectBinariesExist

            $result | Should -Be $true
        }

        It "Construye la ruta correcta del binario" {
            $capturedPath = $null
            Mock Test-Path {
                param($Path)
                $script:capturedPath = $Path
                return $true
            }

            Test-ProjectBinariesExist

            $script:capturedPath | Should -Be "C:\MyProject\MyGame\Binaries\Win64\UnrealEditor-MyGame.dll"
        }

        It "Escribe log VERBOSE cuando binario existe" {
            Mock Test-Path { return $true }

            Test-ProjectBinariesExist

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Checking for project binary" -and
                $Message -match "UnrealEditor-MyGame\.dll" -and
                $Message -match "Exists: True" -and
                $Level -eq "VERBOSE"
            }
        }
    }

    Context "Caso: Binarios no existen" {

        It "Retorna false cuando el archivo DLL no existe" {
            Mock Test-Path { return $false }

            $result = Test-ProjectBinariesExist

            $result | Should -Be $false
        }

        It "Escribe log VERBOSE cuando binario no existe" {
            Mock Test-Path { return $false }

            Test-ProjectBinariesExist

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Checking for project binary" -and
                $Message -match "UnrealEditor-MyGame\.dll" -and
                $Message -match "Exists: False" -and
                $Level -eq "VERBOSE"
            }
        }
    }

    Context "Caso: Diferentes nombres de proyecto" {

        It "Construye ruta correcta con nombre simple" {
            $script:projectName = "TestGame"
            $capturedPath = $null
            Mock Test-Path {
                param($Path)
                $script:capturedPath = $Path
                return $true
            }

            Test-ProjectBinariesExist

            $script:capturedPath | Should -Match "UnrealEditor-TestGame\.dll"
        }

        It "Construye ruta correcta con nombre complejo" {
            $script:projectName = "MyAwesomeGame"
            $capturedPath = $null
            Mock Test-Path {
                param($Path)
                $script:capturedPath = $Path
                return $true
            }

            Test-ProjectBinariesExist

            $script:capturedPath | Should -Match "UnrealEditor-MyAwesomeGame\.dll"
        }

        It "Usa el projectRoot configurado" {
            $script:projectRoot = "C:\Projects\GameDev"
            $capturedPath = $null
            Mock Test-Path {
                param($Path)
                $script:capturedPath = $Path
                return $true
            }

            Test-ProjectBinariesExist

            $script:capturedPath | Should -Match "^C:\\Projects\\GameDev\\"
        }
    }

    Context "Caso: Verificación de estructura de ruta" {

        It "Incluye carpeta Binaries en la ruta" {
            $capturedPath = $null
            Mock Test-Path {
                param($Path)
                $script:capturedPath = $Path
                return $true
            }

            Test-ProjectBinariesExist

            $script:capturedPath | Should -Match "\\Binaries\\"
        }

        It "Incluye carpeta Win64 en la ruta" {
            $capturedPath = $null
            Mock Test-Path {
                param($Path)
                $script:capturedPath = $Path
                return $true
            }

            Test-ProjectBinariesExist

            $script:capturedPath | Should -Match "\\Win64\\"
        }

        It "Usa formato UnrealEditor-[ProjectName].dll" {
            $capturedPath = $null
            Mock Test-Path {
                param($Path)
                $script:capturedPath = $Path
                return $true
            }

            Test-ProjectBinariesExist

            $script:capturedPath | Should -Match "UnrealEditor-.*\.dll$"
        }
    }
}

# =============================================================================
# TESTS DE UNREAL ENGINE
# =============================================================================

Describe "Find-UnrealEngine" -Tag "UnrealEngine" {
    
    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }
    
    BeforeEach {
        $script:CONSTANTS = @{
            Paths = @{
                UnrealBuildBat = "Engine\Build\BatchFiles\Build.bat"
            }
        }
        
        Mock Write-Host { }
        Mock Write-Log { }
    }
    
    Context "Caso: No encuentra instalaciones" {
        
        It "Muestra mensaje cuando no hay instalaciones en rutas comunes" {
            
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() }
            
            Mock Read-Host { return "B" }
            
            Mock New-Object {
                param($TypeName)
                
                if ($TypeName -eq "System.Windows.Forms.Form") {
                    $form = [PSCustomObject]@{
                        TopMost = $true
                        WindowState = $null
                        ShowInTaskbar = $null
                    }
                    
                    $form | Add-Member -MemberType ScriptMethod -Name "Dispose" -Value { }
                    return $form
                }
                
                if ($TypeName -eq "System.Windows.Forms.FolderBrowserDialog") {
                    $dialogForm = [PSCustomObject]@{
                        Description = $null
                        RootFolder = $null
                        SelectedPath = ""
                    }

                    $dialogForm | Add-Member -MemberType ScriptMethod -Name "ShowDialog" -Value { return "Cancel" }
                    return $dialogForm
                }
            }
            
            $result = Find-UnrealEngine
            
            $result | Should -Be $null
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "No Unreal Engine installations found"
            }
        }
    }
    
    Context "Caso: Encuentra una instalación" {
        
        It "Retorna la ruta cuando encuentra una sola instalación" {
            Mock Test-Path {
                param($Path)
                
                if ($Path -eq "C:\Program Files\Epic Games") {
                    return $true
                }
                
                if ($Path -match "Build\.bat") {
                    return $true
                }
                
                return $false
            }
            
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        Name = "UE_5.3"
                        FullName = "C:\Program Files\Epic Games\UE_5.3"
                    }
                )
            }
            
            Mock Read-Host { return "1" }
            
            $result = Find-UnrealEngine
            
            $result | Should -Be "C:\Program Files\Epic Games\UE_5.3"
        }
        
        It "Extrae versión correctamente del nombre del directorio" {
            Mock Test-Path {
                param($Path)
                
                if ($Path -eq "C:\UE") {
                    return $true
                }
                
                if ($Path -match "Build\.bat") {
                    return $true
                }
                
                return $false
            }
            
            Mock Get-ChildItem -ParameterFilter {$Directory} {
                return @(
                    [PSCustomObject]@{
                        Name = "UE_5.3"
                        FullName = "C:\UE\UE_5.3"
                    }
                )
            }
            
            Mock Read-Host { return "1" }
            $cmd = Get-Command Get-ChildItem | Format-List *
            $cmd | Should -Not -BeNullOrEmpty
            $result = Find-UnrealEngine
            
            $result | Should -Be "C:\UE\UE_5.3"
        }
    }
    
    Context "Caso: Encuentra múltiples instalaciones" {
        
        It "Permite seleccionar entre múltiples instalaciones" {
            Mock Test-Path { 
                param($Path)
                
                if ($Path -eq "C:\Epic Games") {
                    return $true
                }
                
                if ($Path -match "Build\.bat") {
                    return $true
                }
                
                return $false
            }
            
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        Name = "UE_5.3"
                        FullName = "C:\Epic Games\UE_5.3"
                    },
                    [PSCustomObject]@{
                        Name = "UE_5.4"
                        FullName = "C:\Epic Games\UE_5.4"
                    },
                    [PSCustomObject]@{
                        Name = "UnrealEngine-5.5"
                        FullName = "C:\Epic Games\UnrealEngine-5.5"
                    }
                )
            }
            
            Mock Read-Host { return "2" }
            
            $result = Find-UnrealEngine
            
            $result | Should -Be "C:\Epic Games\UE_5.4"
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Found 3 installation\(s\)"
            }
        }
        
        It "Rechaza selección inválida y pide de nuevo" {
            Mock Test-Path { 
                param($Path)
                
                if ($Path -eq "C:\UE") {
                    return $true
                }
                
                if ($Path -match "Build\.bat") {
                    return $true
                }
                
                return $false
            }
            
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        Name = "UE_5.3"
                        FullName = "C:\UE\UE_5.3"
                    }
                )
            }
            
            $script:callCount = 0
            
            # Primera llamada: selección inválida
            # Segunda llamada: selección válida
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return "99"  # Inválido
                }
                return "1"  # Válido
            }
            
            $result = Find-UnrealEngine
            
            $result | Should -Be "C:\UE\UE_5.3"
            
            # Verificar que pidió dos veces
            Should -Invoke Read-Host -Times 2
            
            # Verificar que mostró mensaje de error
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Invalid choice"
            }
        }
    }
    
    Context "Caso: Browse (selección manual)" {
        
        It "Permite navegar a ubicación personalizada" {
            Mock Test-Path {
                param($Path)
                
                if ($Path -match "Program Files|Epic Games|Apps") {
                    return $false
                }
                
                if ($Path -match "CustomPath.*Build\.bat") {
                    return $true
                }
                
                return $false
            }
            
            Mock Get-ChildItem { return @() }
            
            Mock Read-Host { return "B" }

            Mock Join-Path {
                param($Path, $ChildPath)
                return "$Path\$ChildPath"
            }
            
            Mock New-Object {
                param($TypeName)
                
                if ($TypeName -eq "System.Windows.Forms.Form") {
                    $form = [PSCustomObject]@{
                        TopMost = $null
                        WindowState = $null
                        ShowInTaskbar = $null
                    }

                    $form | Add-Member -MemberType ScriptMethod -Name "Dispose" -Value { }
                    return $form
                }
                
                if ($TypeName -eq "System.Windows.Forms.FolderBrowserDialog") {
                    $form = [PSCustomObject]@{
                        Description = $null
                        RootFolder = $null
                        SelectedPath = "D:\CustomPath\UE_5.6"
                    }
                    $form | Add-Member -MemberType ScriptMethod -Name "ShowDialog" -Value { return "OK" }
                    return $form
                }
            }
            
            $result = Find-UnrealEngine
            
            $result | Should -Be "D:\CustomPath\UE_5.6"
        }
        
        It "Valida que la ruta seleccionada tenga Build.bat" {
            Mock Test-Path {
                param($Path)

                if ($Path -match "Build\.bat") {
                    if ($script:validateCount -eq 0) {
                        $script:validateCount = 1
                        return $false
                    }
                    return $true
                }
                
                return $false
            }
            
            Mock Get-ChildItem { return @() }
            
            $script:validateCount = 0
            
            Mock Read-Host {
                return "B"
            }
            
            Mock New-Object {
                param($TypeName)
                    
                if ($TypeName -eq "System.Windows.Forms.Form") {
                        $form = [PSCustomObject]@{
                            TopMost = $null
                            WindowState = $null
                            ShowInTaskbar = $null
                        }
                        $form | Add-Member -MemberType ScriptMethod -Name "Dispose" -Value { }
                        return $form
                }
                
                if ($TypeName -eq "System.Windows.Forms.FolderBrowserDialog") {
                    $script:dialogCount++
                    
                    # Primera vez: ruta inválida
                    if ($script:dialogCount -eq 1) {
                        $form = [PSCustomObject]@{
                            Description = $null
                            RootFolder = $null
                            SelectedPath = "C:\InvalidPath"
                        }
                        $form | Add-Member -MemberType ScriptMethod -Name "ShowDialog" -Value { return "OK" }
                        return $form
                    }
                }
                        
                # Segunda vez: ruta válida
                $form = [PSCustomObject]@{
                    Description = $null
                    RootFolder = $null
                    SelectedPath = "C:\ValidPath\UE_5.3"
                }
                $form | Add-Member -MemberType ScriptMethod -Name "ShowDialog" -Value { return "OK" }
                return $form
            }
            
            
            $script:dialogCount = 0
            
            Find-UnrealEngine
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Invalid Unreal Engine installation"
            }
            
            # Verificar que pidió dos veces
            $script:dialogCount | Should -Be 2
        }
        
        It "Retorna null si usuario cancela el browse" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() }
            Mock Read-Host { return "B" }
            
            Mock New-Object {
                param($TypeName)
                
                if ($TypeName -eq "System.Windows.Forms.Form") {
                    $form = [PSCustomObject]@{
                        TopMost = $null
                        WindowState = $null
                        ShowInTaskbar = $null
                    }
                    $form | Add-Member -MemberType ScriptMethod -Name "Dispose" -Value { }
                    return $form
                }
                
                if ($TypeName -eq "System.Windows.Forms.FolderBrowserDialog") {
                    $form = [PSCustomObject]@{
                        Description = $null
                        RootFolder = $null
                        SelectedPath = ""
                    }
                    $form | Add-Member -MemberType ScriptMethod -Name "ShowDialog" -Value { return "Cancel" }
                    return $form
                }
            }
            
            Find-UnrealEngine
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Selection cancelled"
            }
        }
    }
    
    Context "Caso: Patrones de nombres de directorios" {
        
        It "Reconoce formato UE_X.X" {
            Mock Test-Path { return $true }
            Mock Read-Host { return "1" }
            
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        Name = "UE_5.3"
                        FullName = "C:\UE\UE_5.3"
                    }
                )
            }
            
            $result = Find-UnrealEngine
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Reconoce formato UnrealEngine-X.X" {
            Mock Test-Path { 
                if ($Path -eq "C:\UE") {
                    return $true
                }
                
                if ($Path -match "Build\.bat") {
                    return $true
                }
                
                return $false
            }

            Mock Read-Host { return "1" }
            
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        Name = "UnrealEngine-5.3"
                        FullName = "C:\UE\UnrealEngine-5.3"
                    }
                )
            }
            
            $result = Find-UnrealEngine
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Reconoce formato UE5.3 (sin guión bajo)" {
            Mock Test-Path { return $true }
            Mock Read-Host { return "1" }
            
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        Name = "UE5.3"
                        FullName = "C:\UE\UE5.3"
                    }
                )
            }
            
            $result = Find-UnrealEngine
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Ignora directorios que no coinciden con el patrón" {
            Mock Test-Path { return $true }
            
            Mock Get-ChildItem {
                return @(
                    [PSCustomObject]@{
                        Name = "SomeOtherFolder"
                        FullName = "C:\Epic Games\SomeOtherFolder"
                    },
                    [PSCustomObject]@{
                        Name = "UE_5.3"
                        FullName = "C:\Epic Games\UE_5.3"
                    }
                )
            }
            
            Mock Read-Host { return "1" }
            
            Find-UnrealEngine
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Found 1 installation"
            }
        }
    }
    
    Context "Caso: Búsqueda en múltiples rutas" {
        
        It "Busca en todas las rutas predefinidas" {
            $script:pathsChecked = @()
            
            Mock Test-Path {
                param($Path)
                
                if ($Path -notmatch "Build\.bat") {
                    $script:pathsChecked += $Path
                }
                
                return $false
            }
            
            Mock Get-ChildItem { return @() }
            Mock Read-Host { return "B" }
            
            Mock New-Object {
                if ($TypeName -eq "System.Windows.Forms.FolderBrowserDialog") {
                    $form = [PSCustomObject]@{
                        RootFolder = $null
                        Description = $null
                        SelectedPath = $null
                    }
                    $form | Add-Member -MemberType ScriptMethod -Name "ShowDialog" -Value { return "Cancel" }
                    return $form
                }

                $form = [PSCustomObject]@{
                    TopMost = $null
                    WindowState = $null
                    ShowInTaskbar = $null
                }
                $form | Add-Member -MemberType ScriptMethod -Name "Dispose" -Value { }
                return $form
            }
            
            Find-UnrealEngine
            
            $script:pathsChecked | Should -Contain "C:\Program Files\Epic Games"
            $script:pathsChecked | Should -Contain "C:\Epic Games"
            $script:pathsChecked | Should -Contain "C:\UE"
        }
    }
    
    Context "Caso: Form TopMost" {
        
        It "Crea Form con TopMost para que el diálogo aparezca al frente" {
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() }
            Mock Read-Host { return "B" }
            
            $script:formCreated = $null
            
            Mock New-Object {
                param($TypeName)
                
                if ($TypeName -eq "System.Windows.Forms.Form") {
                    $form = [PSCustomObject]@{
                        TopMost = $null
                        WindowState = $null
                        ShowInTaskbar = $null
                    }
                    $form | Add-Member -MemberType ScriptMethod -Name "Dispose" -Value { }
                    $script:formCreated = $form
                    return $form
                }
                
                if ($TypeName -eq "System.Windows.Forms.FolderBrowserDialog") {
                    $form = [PSCustomObject]@{
                        Description = $null
                        RootFolder = $null
                        SelectedPath = ""
                    }
                    $form | Add-Member -MemberType ScriptMethod -Name "ShowDialog" -Value { return "Cancel" }
                    return $form
                }
            }
            
            Find-UnrealEngine
            
            $script:formCreated | Should -Not -BeNullOrEmpty
            
            # Verificar que se configuró TopMost
            # (Nota: Esto verifica que se ASIGNÓ, no el valor específico)
            $script:formCreated.PSObject.Properties.Name | Should -Contain "TopMost"
        }
    }
}

Describe "Get-UnrealEngineRoot" -Tag "UnrealEngine" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        $script:CONSTANTS = @{
            ConfigKeys = @{
                EnginePath = "UnrealEnginePath"
                EngineVersion = "UnrealEngineVersion"
            }
            Paths = @{
                UnrealBuildBat = "Engine\Build\BatchFiles\Build.bat"
            }
        }

        Mock Write-Host { }
        Mock Write-Log { }
        Mock Write-Header { }
    }

    Context "Caso: Ruta guardada válida en config" {

        It "Retorna ruta guardada cuando existe y es válida" {
            $script:validPath = "C:\UE_5.3"

            Mock Get-ConfigValue {
                param($Key)
                return $script:validPath
            }

            Mock Test-Path {
                param($Path)
                return $true
            }

            $result = Get-UnrealEngineRoot

            $result | Should -Be $validPath

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Using UE installation" -and $Level -eq "VERBOSE"
            }
        }

        It "No llama a Find-UnrealEngine cuando la ruta guardada es válida" {
            Mock Get-ConfigValue { return "C:\UE_5.3" }
            Mock Test-Path { return $true }
            Mock Find-UnrealEngine { }

            Get-UnrealEngineRoot

            Should -Not -Invoke Find-UnrealEngine
        }
    }

    Context "Caso: Ruta guardada inválida o no existe" {

        It "Solicita nueva selección cuando Build.bat no existe en ruta guardada" {
            $script:invalidPath = "C:\InvalidUE"
            $script:newValidPath = "C:\UE_5.4"

            Mock Get-ConfigValue {
                param($Key)
                return $script:invalidPath
            }

            Mock Test-Path {
                param($Path)

                if ($Path -match "InvalidUE.*Build\.bat") {
                    return $false
                }
                return $true
            }

            Mock Find-UnrealEngine { return $script:newValidPath }
            Mock Set-ConfigValue { }

            $result = Get-UnrealEngineRoot

            $result | Should -Be $script:newValidPath

            Should -Invoke Find-UnrealEngine -Times 1

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Saved UE path is invalid" -and $Level -eq "WARNING"
            }
        }
    }

    Context "Caso: Configuración de nueva instalación" {

        It "Guarda la nueva ruta en config cuando se selecciona" {
            $script:selectedPath = "C:\UE_5.3"

            Mock Get-ConfigValue { return $null }
            Mock Find-UnrealEngine { return $script:selectedPath }

            $script:capturedVersion = $null
            $script:capturedPath = $null
            
            Mock Set-ConfigValue {
                param($Path, $Value)
                if ($Path -eq $script:CONSTANTS.ConfigKeys.EnginePath) {
                    $script:capturedPath = $Value
                }
                elseif ($Path -eq $script:CONSTANTS.ConfigKeys.EngineVersion) {
                    $script:capturedVersion = $Value
                }
            }

            $result = Get-UnrealEngineRoot

            $result | Should -Be $script:selectedPath

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "UE path saved to config" -and $Level -eq "INFO"
            }

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Detected UE version: 5\.3"
            }

            $script:capturedPath | Should -Be $script:selectedPath

            $script:capturedVersion | Should -Be "5.3"
        }

        It "Detecta versiones con diferentes formatos" {
            $testCases = @(
                @{ Path = "C:\UE_5.4.1"; ExpectedVersion = "5.4.1" }
                @{ Path = "C:\UnrealEngine-5.3"; ExpectedVersion = "5.3" }
                @{ Path = "C:\Epic Games\UE 5.2"; ExpectedVersion = "5.2" }
                @{ Path = "C:\Apps\UE_Engines\5.1.0"; ExpectedVersion = "5.1.0" }
            )

            foreach ($case in $testCases) {
                Mock Get-ConfigValue { return $null }
                Mock Find-UnrealEngine { return $case.Path }

                $capturedVersion = $null
                Mock Set-ConfigValue {
                    param($Path, $Value)
                    if ($Path -eq $script:CONSTANTS.ConfigKeys.EngineVersion) {
                        $script:capturedVersion = $Value
                    }
                }

                Get-UnrealEngineRoot

                $script:capturedVersion | Should -Be $case.ExpectedVersion
            }
        }
    }

    Context "Caso: Usuario cancela selección" {

        It "Lanza BuildException con detalles correctos" {
            Mock Get-ConfigValue { return $null }
            Mock Find-UnrealEngine { return $null }

            try {
                Get-UnrealEngineRoot
                Should -Fail "Excepcion esperada no fue lanzada"
            }
            catch{
                $_.Exception.Message | Should -Match "Setup cancelled or no valid Unreal Engine found"
                $_.Exception.Category | Should -Be "Configuration"
                $_.Exception.Suggestion | Should -Match "Install Unreal Engine and run the script again"
            }
        }
    }
}

Describe "Test-UnrealEngineValid" -Tag "UnrealEngine" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        $script:CONSTANTS = @{
            Paths = @{
                UnrealBuildBat = "Engine\Build\BatchFiles\Build.bat"
                UnrealEditorExe = "Engine\Binaries\Win64\UnrealEditor.exe"
            }
        }
    }

    Context "Caso: Instalación válida de Unreal Engine" {

        It "Retorna true cuando Build.bat y UnrealEditor.exe existen" {
            $ueRoot = "C:\UE_5.3"

            Mock Test-Path {
                param($Path)
                if ($Path -match "Build\.bat$" -or $Path -match "UnrealEditor\.exe$") {
                    return $true
                }
                return $false
            }

            $result = Test-UnrealEngineValid -UERoot $ueRoot

            $result | Should -Be $true
        }

        It "Valida las rutas correctas construidas con Join-Path" {
            $ueRoot = "C:\Epic Games\UE_5.4"
            $expectedBuildBat = "C:\Epic Games\UE_5.4\Engine\Build\BatchFiles\Build.bat"
            $expectedEditorExe = "C:\Epic Games\UE_5.4\Engine\Binaries\Win64\UnrealEditor.exe"

            $capturedPaths = @()
            Mock Test-Path {
                param($Path)
                $script:capturedPaths += $Path
                return $true
            }

            Test-UnrealEngineValid -UERoot $ueRoot

            $script:capturedPaths | Should -Contain $expectedBuildBat
            $script:capturedPaths | Should -Contain $expectedEditorExe
        }
    }

    Context "Caso: Build.bat no existe" {

        It "Lanza BuildException con mensaje específico para Build.bat" {
            Mock Test-Path {
                param($Path)
                if ($Path -match "Build\.bat$") {
                    return $false
                }
                return $true
            }

            try {
                Test-UnrealEngineValid -UERoot "C:\UE"
                Should -Fail "Excepcion esperada no fue lanzada"
            }
            catch{
                $_.Exception.Message | Should -Match "Build\.bat not found in UE installation"
                $_.Exception.Category | Should -Be "Unreal Engine"
                $_.Exception.Suggestion | Should -Match "Ensure you selected a valid UE installation folder"
            }
        }
    }

    Context "Caso: UnrealEditor.exe no existe" {

        It "Lanza BuildException con mensaje específico para UnrealEditor.exe" {
            Mock Test-Path {
                param($Path)
                if ($Path -match "Build\.bat$") {
                    return $true
                }
                return $false
            }

            try {
                Test-UnrealEngineValid -UERoot "C:\UE"
                Should -Fail "Excepcion esperada no fue lanzada"
            }
            catch{
                $_.Exception.Message | Should -Match "UnrealEditor\.exe not found"
                $_.Exception.Category | Should -Be "Unreal Engine"
                $_.Exception.Suggestion | Should -Match "Ensure you compile the Engine"
            }
        }
    }

    Context "Caso: Diferentes rutas de UERoot" {

        It "Funciona con rutas que contienen espacios" {
            $ueRoot = "C:\Program Files\Epic Games\UE_5.3"

            Mock Test-Path { return $true }

            $result = Test-UnrealEngineValid -UERoot $ueRoot

            $result | Should -Be $true
        }

        It "Funciona con rutas sin espacios" {
            $ueRoot = "C:\UE_5.3"

            Mock Test-Path { return $true }

            $result = Test-UnrealEngineValid -UERoot $ueRoot

            $result | Should -Be $true
        }

        It "Funciona con rutas en diferentes unidades" {
            $testCases = @(
                "D:\UnrealEngine\UE_5.3",
                "E:\Development\UE_5.4",
                "C:\Apps\UE_Engines\5.1"
            )

            Mock Join-Path {
                param($Path, $ChildPath)
                return "$Path\$ChildPath"
            }

            Mock Test-Path { return $true }

            foreach ($ueRoot in $testCases) {

                $result = Test-UnrealEngineValid -UERoot $ueRoot

                $result | Should -Be $true
            }
        }
    }
}

Describe "Find-UnrealProject" -Tag "UnrealEngine"{

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach{
        Mock Write-Host { }
        Mock Write-Log { }
    }

    Context "Caso: Encuentra el archivo .uproject" {

        It "Retorna la ruta del archivo .uproject si existe" {
            Mock Get-ChildItem { 
                param()
                return @(
                    [PSCustomObject]@{
                        Name = "myproject.uproject"
                        FullName = "C:\MyProject\UnrealProject\ExtraFolder\myproject.uproject"
                    }
                )
            }

            $result = Find-UnrealProject -SearchPath "C:\MyProject"
            
            $result.FullName | Should -Be "C:\MyProject\UnrealProject\ExtraFolder\myproject.uproject"
        }

        It "Encuentra multiples archivos .uproject y permite seleccionar" {
            Mock Get-ChildItem {
                param()
                return @(
                    [PSCustomObject]@{
                        Name = "ProjectA.uproject"
                        FullName = "C:\MyProject\ProjectA.uproject"
                    },
                    [PSCustomObject]@{
                        Name = "ProjectB.uproject"
                        FullName = "C:\MyProject\ProjectB.uproject"
                    }
                )
            }
            
            Mock Read-Host { return "2" }
            
            $result = Find-UnrealProject -SearchPath "C:\MyProject"
            
            $result.FullName | Should -Be "C:\MyProject\ProjectB.uproject"
        }

        It "Maneja selección inválida y pide de nuevo" {
            Mock Test-Path { return $false }
            
            Mock Get-ChildItem {
                param()
                return @(
                    [PSCustomObject]@{
                        Name = "ProjectA.uproject"
                        FullName = "C:\MyProject\ProjectA.uproject"
                    },
                    [PSCustomObject]@{
                        Name = "ProjectB.uproject"
                        FullName = "C:\MyProject\ProjectB.uproject"
                    }
                )
            }
            
            $script:callCount = 0
            
            Mock Read-Host {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return "99"  # Inválido
                }
                return "1"  # Válido
            }
            
            $result = Find-UnrealProject -SearchPath "C:\MyProject"
            
            $result.FullName | Should -Be "C:\MyProject\ProjectA.uproject"
            
            Should -Invoke Read-Host -Times 2
            
            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Invalid choice"
            }
        }
    }

    Context "Caso: No encuentra el archivo .uproject" {

        It "lanza excepción si no encuentra archivo .uproject" {
            Mock Get-ChildItem { 
                param()
                return @() 
            }

            try {
                $result = Find-UnrealProject -SearchPath "C:\MyProject"
            
                $result | Should -Be $null
            }
            catch {
                $_.Exception.Message | Should -Be "No Unreal project (.uproject) found in: C:\MyProject"
                $_.Exception.Category | Should -Be "Project Detection"
                $_.Exception.Suggestion | Should -Be "Ensure there is a .uproject in the search path"
            }
        }
    }
}

# =============================================================================
# TESTS DE BUILD
# =============================================================================

Describe "Invoke-ProjectBuild" -Tag "Build" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        $script:CONSTANTS = @{
            Paths = @{
                UnrealBuildBat = "Engine\Build\BatchFiles\Build.bat"
            }
            ConfigKeys = @{
                UseUBTLogging = "UseUBTLogging"
            }
            FileNames = @{
                BuildLogFileName = "Build.log"
            }
        }

        $script:projectName = "MyGame"
        $script:projectFile = "C:\MyProject\MyGame.uproject"
        $script:logsDir = "C:\Logs"

        Mock Write-Header { }
        Mock Write-Host { }
        Mock Write-Log { }
        Mock Get-ConfigValue {
            param($Path, $DefaultValue)
            return $DefaultValue
        }
    }

    Context "Caso: Build exitoso (incremental)" {

        It "Retorna true cuando el build termina con ExitCode 0" {
            Mock Start-Process {
                return [PSCustomObject]@{
                    ExitCode = 0
                }
            }

            $result = Invoke-ProjectBuild -UERoot "C:\UE_5.3" -CleanBuild:$false

            $result | Should -Be $true
        }

        It "Construye la ruta correcta del Build.bat" {
            $capturedFilePath = $null
            Mock Start-Process {
                param($FilePath, $ArgumentList, $NoNewWindow, $Wait, $PassThru)
                $script:capturedFilePath = $FilePath
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            $script:capturedFilePath | Should -Be "C:\UE_5.3\Engine\Build\BatchFiles\Build.bat"
        }

        It "Pasa argumentos correctos sin -Clean" {
            $capturedArgs = $null
            Mock Start-Process {
                param($FilePath, $ArgumentList, $NoNewWindow, $Wait, $PassThru)
                $script:capturedArgs = $ArgumentList
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            $script:capturedArgs | Should -Contain "MyGameEditor"
            $script:capturedArgs | Should -Contain "Win64"
            $script:capturedArgs | Should -Contain "Development"
            $script:capturedArgs | Should -Contain "`"C:\MyProject\MyGame.uproject`""
            $script:capturedArgs | Should -Not -Contain "-Clean"
        }

        It "Ejecuta Start-Process con -Wait y -PassThru" {
            $capturedWait = $null
            $capturedPassThru = $null
            Mock Start-Process {
                param($FilePath, $ArgumentList, $NoNewWindow, $Wait, $PassThru)
                $script:capturedWait = $Wait
                $script:capturedPassThru = $PassThru
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            $script:capturedWait | Should -Be $true
            $script:capturedPassThru | Should -Be $true
        }

        It "Muestra mensaje de build incremental cuando no se usa -CleanBuild" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Performing incremental build"
            }
        }
    }

    Context "Caso: Build exitoso (clean build)" {

        It "Agrega -Clean a los argumentos cuando se usa -CleanBuild" {
            $capturedArgs = $null
            Mock Start-Process {
                param($FilePath, $ArgumentList, $NoNewWindow, $Wait, $PassThru)
                $script:capturedArgs = $ArgumentList
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3" -CleanBuild

            $script:capturedArgs | Should -Contain "-Clean"
        }

        It "Muestra mensaje de clean build cuando se usa -CleanBuild" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3" -CleanBuild

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Clean build requested"
            }
        }

        It "Retorna true cuando clean build exitoso" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            $result = Invoke-ProjectBuild -UERoot "C:\UE_5.3" -CleanBuild

            $result | Should -Be $true
        }
    }

    Context "Caso: Build con UBT logging habilitado" {

        It "Agrega -Log cuando UseUBTLogging es true" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "UseUBTLogging") {
                    return $true
                }
                return $DefaultValue
            }

            $capturedArgs = $null
            Mock Start-Process {
                param($FilePath, $ArgumentList, $NoNewWindow, $Wait, $PassThru)
                $script:capturedArgs = $ArgumentList
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            $logArg = $script:capturedArgs | Where-Object { $_ -match '^-Log=' }
            $logArg | Should -Not -BeNullOrEmpty
            $logArg | Should -Match 'Build\.log'
        }

        It "No agrega -Log cuando UseUBTLogging es false" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "UseUBTLogging") {
                    return $false
                }
                return $DefaultValue
            }

            $capturedArgs = $null
            Mock Start-Process {
                param($FilePath, $ArgumentList, $NoNewWindow, $Wait, $PassThru)
                $script:capturedArgs = $ArgumentList
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            $logArg = $script:capturedArgs | Where-Object { $_ -match '^-Log=' }
            $logArg | Should -BeNullOrEmpty
        }

        It "Escribe log VERBOSE con ruta del build log cuando UBT logging habilitado" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "UseUBTLogging") {
                    return $true
                }
                return $DefaultValue
            }

            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Build log will be saved to" -and $Level -eq "VERBOSE"
            }
        }
    }

    Context "Caso: Build fallido" {

        It "Retorna false cuando ExitCode no es 0" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 1 }
            }

            $result = Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            $result | Should -Be $false
        }

        It "Escribe log ERROR cuando build falla" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 5 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Build failed" -and
                $Message -match "Exit code: 5" -and
                $Level -eq "ERROR"
            }
        }

        It "Muestra mensaje BUILD FAILED cuando falla" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 1 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "BUILD FAILED"
            }
        }

        It "Muestra mensaje con ruta del log cuando UBT logging habilitado y build falla" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "UseUBTLogging") {
                    return $true
                }
                return $DefaultValue
            }

            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 1 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Check the build log for details"
            }
        }

        It "Retorna false para diferentes códigos de error" {
            $errorCodes = @(1, 2, 5, 10, 127, 255)

            foreach ($code in $errorCodes) {
                Mock Start-Process {
                    return [PSCustomObject]@{ ExitCode = $code }
                }

                $result = Invoke-ProjectBuild -UERoot "C:\UE_5.3"

                $result | Should -Be $false
            }
        }
    }

    Context "Caso: Excepciones durante el build" {

        It "Retorna false cuando Start-Process lanza excepción" {
            Mock Start-Process {
                throw "Process failed to start"
            }

            $result = Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            $result | Should -Be $false
        }

        It "Escribe log ERROR cuando hay excepción" {
            Mock Start-Process {
                throw "Build.bat not found"
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Build error" -and
                $Message -match "Build.bat not found" -and
                $Level -eq "ERROR"
            }
        }

        It "Llama Write-DetailedError cuando hay excepción" {
            Mock Start-Process {
                throw "Access denied"
            }
            Mock Write-DetailedError { }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-DetailedError -ParameterFilter {
                $Message -match "Build process crashed" -and
                $Message -match "Access denied" -and
                $Category -eq "Build" -and
                $Suggestion -match "Visual Studio Build Tools"
            }
        }

        It "Maneja excepción con mensaje vacío" {
            Mock Start-Process {
                throw [System.Exception]::new()
            }

            $result = Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            $result | Should -Be $false
        }
    }

    Context "Caso: Mensajes informativos" {

        It "Muestra header BUILDING PROJECT" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Header -ParameterFilter {
                $Text -eq "BUILDING PROJECT"
            }
        }

        It "Muestra tiempo estimado de build" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Estimated time: 5-15 minutes"
            }
        }

        It "Escribe log VERBOSE con comando completo ejecutado" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Executing:.*Build\.bat" -and
                $Message -match "MyGameEditor" -and
                $Level -eq "VERBOSE"
            }
        }

        It "Muestra BUILD SUCCESSFUL cuando exitoso" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }

            Invoke-ProjectBuild -UERoot "C:\UE_5.3"

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "BUILD SUCCESSFUL"
            }
        }
    }
}

# =============================================================================
# TESTS DE EDITOR
# =============================================================================

Describe "Start-UnrealEditor" -Tag "Editor" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        $script:CONSTANTS = @{
            Paths = @{
                UnrealEditorExe = "Engine\Binaries\Win64\UnrealEditor.exe"
            }
            ConfigKeys = @{
                EditorAutoLaunch = "EditorAutoLaunch"
            }
        }

        $script:projectFile = "C:\MyProject\MyGame.uproject"
        $script:NoPrompt = $false

        Mock Write-Header { }
        Mock Write-Host { }
        Mock Write-Log { }
        Mock Get-ConfigValue {
            param($Path, $DefaultValue)
            return $DefaultValue
        }
        Mock Set-ConfigValue { }
    }

    Context "Caso: Editor no existe" {

        It "Retorna false cuando UnrealEditor.exe no existe" {
            Mock Test-Path { return $false }

            $result = Start-UnrealEditor -UERoot "C:\UE_5.3"

            $result | Should -Be $false
        }

        It "Escribe log WARNING cuando editor no existe" {
            Mock Test-Path { return $false }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Editor executable not found" -and
                $Level -eq "WARNING"
            }
        }

        It "Muestra mensaje de advertencia cuando editor no existe" {
            Mock Test-Path { return $false }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "UnrealEditor.exe not found"
            }
        }

        It "Verifica la ruta correcta del ejecutable" {
            $capturedPath = $null
            Mock Test-Path {
                param($Path)
                $script:capturedPath = $Path
                return $false
            }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            $script:capturedPath | Should -Be "C:\UE_5.3\Engine\Binaries\Win64\UnrealEditor.exe"
        }
    }

    Context "Caso: Usuario acepta lanzar editor (prompt manual)" {

        It "Retorna true cuando usuario responde Y y lanzamiento exitoso" {
            Mock Test-Path { return $true }
            Mock Read-Host {
                # Primera llamada: Launch? -> Y
                # Segunda llamada: Save? -> N
                if ($script:readHostCallCount -eq $null) { $script:readHostCallCount = 0 }
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }
                return "N"
            }
            Mock Start-Process { }

            $result = Start-UnrealEditor -UERoot "C:\UE_5.3"

            $result | Should -Be $true
        }

        It "Lanza el editor con la ruta correcta cuando usuario acepta" {
            Mock Test-Path { return $true }
            $script:readHostCallCount = 0
            Mock Read-Host {
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }
                return "N"
            }
            Mock Join-Path {
                param($Path, $ChildPath)
                return "$Path\$ChildPath"
            }
            $capturedFilePath = $null
            Mock Start-Process {
                param($FilePath, $ArgumentList)
                $script:capturedFilePath = $FilePath
            }

            $result = Start-UnrealEditor -UERoot "C:\UE_5.3"

            $result | Should -Be $true

            Should -Invoke Start-Process -Times 1

            $script:capturedFilePath | Should -Be "C:\UE_5.3\Engine\Binaries\Win64\UnrealEditor.exe"
        }

        It "Pasa el archivo de proyecto como argumento cuando lanza editor" {
            Mock Test-Path { return $true }
            $script:readHostCallCount = 0
            Mock Read-Host {
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }
                return "N"
            }
            $capturedArgs = $null
            Mock Start-Process {
                param($FilePath, $ArgumentList)
                $script:capturedArgs = $ArgumentList
            }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            $script:capturedArgs | Should -Match "MyGame\.uproject"
        }

        It "Acepta respuesta en minúscula (y)" {
            Mock Test-Path { return $true }
            $script:readHostCallCount = 0
            Mock Read-Host {
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "y" }
                return "n"
            }
            Mock Start-Process { }

            $result = Start-UnrealEditor -UERoot "C:\UE_5.3"

            $result | Should -Be $true
            Should -Invoke Start-Process -Times 1
        }
    }

    Context "Caso: Usuario rechaza lanzar editor" {

        It "Retorna true cuando usuario responde N (no es error)" {
            Mock Test-Path { return $true }
            Mock Read-Host { return "N" }

            $result = Start-UnrealEditor -UERoot "C:\UE_5.3"

            $result | Should -Be $true
        }

        It "No lanza el editor cuando usuario responde N" {
            Mock Test-Path { return $true }
            Mock Read-Host { return "N" }
            Mock Start-Process { }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Start-Process -Times 0
        }

        It "Escribe log INFO cuando usuario rechaza lanzar" {
            Mock Test-Path { return $true }
            Mock Read-Host { return "N" }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "User chose not to launch editor" -and
                $Level -eq "INFO"
            }
        }

        It "Acepta respuesta en minúscula (n)" {
            Mock Test-Path { return $true }
            Mock Read-Host { return "n" }
            Mock Start-Process { }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Start-Process -Times 0
        }
    }

    Context "Caso: AutoLaunch habilitado" {

        It "Lanza automáticamente cuando EditorAutoLaunch es true" {
            Mock Test-Path { return $true }
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "EditorAutoLaunch") {
                    return $true
                }
                return $DefaultValue
            }
            Mock Read-Host { return "N" }  # Save response
            Mock Start-Process { }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Start-Process -Times 1
        }

        It "No pregunta 'Launch Editor?' cuando autoLaunch habilitado" {
            Mock Test-Path { return $true }
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "EditorAutoLaunch") {
                    return $true
                }
                return $DefaultValue
            }
            Mock Read-Host { return "N" }
            Mock Start-Process { }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            # No debe preguntar nada cuando autoLaunch está habilitado
            Should -Invoke Read-Host -Times 0
        }
    }

    Context "Caso: Guardar preferencia de usuario" {

        It "Guarda EditorAutoLaunch cuando usuario responde Y a 'Save Response'" {
            Mock Test-Path { return $true }
            Mock Read-Host {
                if ($script:readHostCallCount -eq $null) { $script:readHostCallCount = 0 }
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }  # Launch
                return "Y"  # Save
            }
            Mock Start-Process { }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Set-ConfigValue -ParameterFilter {
                $Path -eq "EditorAutoLaunch" -and $Value -eq $true
            }
        }

        It "No guarda preferencia cuando usuario responde N a 'Save Response'" {
            Mock Test-Path { return $true }
            Mock Read-Host {
                if ($script:readHostCallCount -eq $null) { $script:readHostCallCount = 0 }
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }  # Launch
                return "N"  # Don't save
            }
            Mock Start-Process { }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Set-ConfigValue -Times 0
        }

        It "Acepta respuesta en minúscula (y) para guardar" {
            Mock Test-Path { return $true }
            Mock Read-Host {
                if ($script:readHostCallCount -eq $null) { $script:readHostCallCount = 0 }
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }  # Launch
                return "y"  # Save (lowercase)
            }
            Mock Start-Process { }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Set-ConfigValue -Times 1
        }
    }

    Context "Caso: Excepción al lanzar editor" {

        It "Retorna false cuando Start-Process lanza excepción" {
            Mock Test-Path { return $true }
            $script:readHostCallCount = 0
            Mock Read-Host {
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }
                return "N"
            }
            Mock Start-Process {
                throw "File not found"
            }

            $result = Start-UnrealEditor -UERoot "C:\UE_5.3"

            $result | Should -Be $false
        }

        It "Escribe log ERROR cuando falla el lanzamiento" {
            Mock Test-Path { return $true }
            $script:readHostCallCount = 0
            Mock Read-Host {
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }
                return "N"
            }
            Mock Start-Process {
                throw "Access denied"
            }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Failed to launch editor" -and
                $Message -match "Access denied" -and
                $Level -eq "ERROR"
            }
        }

        It "Muestra mensaje de error cuando falla el lanzamiento" {
            Mock Test-Path { return $true }
            $script:readHostCallCount = 0
            Mock Read-Host {
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }
                return "N"
            }
            Mock Start-Process {
                throw "Process error"
            }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Failed to launch editor" -and
                $Object -match "Process error"
            }
        }
    }

    Context "Caso: Mensajes informativos" {

        It "Muestra header READY TO LAUNCH" {
            Mock Test-Path { return $false }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Write-Header -ParameterFilter {
                $Text -eq "READY TO LAUNCH"
            }
        }

        It "Muestra mensaje de éxito cuando lanza" {
            Mock Test-Path { return $true }
            $script:readHostCallCount = 0
            Mock Read-Host {
                $script:readHostCallCount++
                if ($script:readHostCallCount -eq 1) { return "Y" }
                return "N"
            }
            Mock Start-Process { }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Editor launched successfully"
            }
        }

        It "Muestra mensaje 'Skipping editor launch' cuando usuario rechaza" {
            Mock Test-Path { return $true }
            Mock Read-Host { return "N" }

            Start-UnrealEditor -UERoot "C:\UE_5.3"

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Skipping editor launch"
            }
        }
    }
}

# =============================================================================
# TESTS DE REGEX DE EXTENSIONES
# =============================================================================

Describe "Detección de extensiones de código" -Tag "Helpers" {
    
    Context "Regex patterns" {
        
        It "Detecta .cpp con formato Perforce (file.cpp#5)" {
            $description = "... //depot/Source/Player.cpp#5 edit"
            $ext = ".cpp"
            $pattern = [regex]::Escape($ext) + '#\d+'
            
            $description -match $pattern | Should -Be $true
        }
        
        It "NO hace false positive con 'cpp' en texto" {
            $description = "See cppreference.com for C++ documentation"
            $ext = ".cpp"
            $pattern = [regex]::Escape($ext) + '#\d+'
            
            $description -match $pattern | Should -Be $false
        }
        
        It "Detecta múltiples extensiones en mismo changelist" {
            $description = @"
... //depot/Source/Player.cpp#5 edit
... //depot/Source/Game.h#3 edit
... //depot/Source/Build.cs#2 edit
... //depot/Content/UI.uasset#1 add
"@
            
            $codeExtensions = @('.cpp', '.h', '.cs')
            $foundExtensions = @()
            
            foreach ($ext in $codeExtensions) {
                $pattern = [regex]::Escape($ext) + '#\d+'
                if ($description -match $pattern) {
                    $foundExtensions += $ext
                }
            }
            
            $foundExtensions.Count | Should -Be 3
            $foundExtensions | Should -Contain '.cpp'
            $foundExtensions | Should -Contain '.h'
            $foundExtensions | Should -Contain '.cs'
        }
        
        It "Distingue entre .cs y .build.cs" {
            $description = "... //depot/Source/MyGame.build.cs#1 edit"
            
            $pattern1 = [regex]::Escape('.cs') + '#\d+'
            $pattern2 = [regex]::Escape('.build.cs') + '#\d+'
            
            # Ambos deberían hacer match (build.cs contiene .cs)
            $description -match $pattern1 | Should -Be $true
            $description -match $pattern2 | Should -Be $true
        }
    }
    
    Context "Edge cases" {
        
        It "Maneja descripción vacía sin error" {
            $description = ""
            $ext = ".cpp"
            $pattern = [regex]::Escape($ext) + '#\d+'
            
            $description -match $pattern | Should -Be $false
        }
        
        It "Maneja descripción con caracteres especiales" {
            $description = "... //depot/Source/My$pecial.cpp#5 edit"
            $ext = ".cpp"
            $pattern = [regex]::Escape($ext) + '#\d+'
            
            $description -match $pattern | Should -Be $true
        }
    }
}

# =============================================================================
# TESTS DE UTILIDADES
# =============================================================================

Describe "Split-Path para project root" -Tag "Helpers" {
    
    It "Sube un nivel desde script directory" {
        $scriptDir = "C:\MyProject\src\scripts"
        $projectRoot = Split-Path $scriptDir -Parent
        
        $projectRoot | Should -Be "C:\MyProject\src"
    }
    
    It "Sube dos niveles correctamente" {
        $scriptDir = "C:\MyProject\src\scripts"
        $parent1 = Split-Path $scriptDir -Parent  # C:\MyProject\src
        $parent2 = Split-Path $parent1 -Parent    # C:\MyProject
        
        $parent2 | Should -Be "C:\MyProject"
    }
}

Describe "Array handling" -Tag "Helpers" {
    
    Context "Conversión a array con @()" {
        
        It "Convierte int único a array de 1 elemento" {
            $changelist = 12345
            $changes = @($changelist)
            
            $changes -is [array] | Should -Be $true
            $changes.Count | Should -Be 1
            $changes[0] | Should -Be 12345
        }
        
        It "Mantiene array como array" {
            $changelist = @(111, 222, 333)
            $changes = @($changelist)
            
            $changes.Count | Should -Be 3
        }
        
        It "Convierte $null a array vacío" {
            $changelist = $null
            $changes = @($changelist)
            
            $changes.Count | Should -Be 1
        }
    }
    
    Context "Empty arrays en if" {
        
        It "Array vacío se evalúa como false" {
            $emptyArray = @()
            
            if ($emptyArray) {
                $result = "not empty"
            } else {
                $result = "empty"
            }
            
            $result | Should -Be "empty"
        }
        
        It "Array con elementos se evalúa como true" {
            $arrayWithItems = @(1, 2, 3)
            
            if ($arrayWithItems) {
                $result = "not empty"
            } else {
                $result = "empty"
            }
            
            $result | Should -Be "not empty"
        }
    }
}

# =============================================================================
# TESTS DE INTEGRACIÓN
# =============================================================================

Describe "Workflow completo" -Tag "Integration" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        $script:projectRoot = "C:\TestProject"
        
        if (-not $script:CONSTANTS) {
            $script:CONSTANTS = @{
                PerforceUpToDate = "file\(s\) up-to-date\."
            }
        }

        Mock Get-ConfigValue {
            param($Path, $DefaultValue)
            
            if ($Path -eq "CodeExtensions") {
                return @('.cpp', '.h', '.build.cs', '.cs')
            }
            return $DefaultValue
        }
    }
    
    It "Flujo: Sync, Detecta cambios, Build" {
        Mock Test-PerforceEnvironment { return "test-workspace" }
        Mock Get-LatestHaveChangelist { 
                if ($script:callCount -eq 0) {
                    $script:callCount = 1
                    return 12340
                }
                
                return 12345
            }
        Mock Push-Location { }
        Mock Pop-Location { }
        Mock Write-Host { }
        Mock Write-Log { }
        Mock Write-Header { }
        
        Mock p4 {
            param([Parameter(ValueFromRemainingArguments)]$Arguments)
            
            $cmd = $Arguments[0]
            
            $global:LASTEXITCODE = 0
            
            switch ($cmd) {
                'sync' {
                    Write-Output "//depot/Source/Player.cpp#5 - updating C:\Project\Source\Player.cpp"
                    Write-Output "//depot/Source/Game.h#3 - updating C:\Project\Source\Game.h"
                }
                
                'describe' {
                    $clNum = $Arguments[2]
                    Write-Host "  Describing CL: $clNum" -ForegroundColor Yellow
                    
                    return @"
Change $clNum by user@workspace on 2024/12/25

    Fixed player movement bug

Affected files ...

... //depot/Source/MyGame/Player.cpp#5 edit
... //depot/Source/MyGame/PlayerController.h#3 edit
"@
                }
                
                'changes' {
                    return "Change 12345 on 2024/12/25 by user@workspace"
                }
                
                default {
                    Write-Warning "Mock p4: comando desconocido: $cmd"
                    return @()
                }
            }
        }
        
        
        $syncResult = Sync-FromPerforce -SkipSync:$false
        $hasCodeChanges = Test-CodeChanges -Changelist 12345
        
        
        $syncResult | Should -Be $true
        $hasCodeChanges | Should -Be $true
    }
}

# =============================================================================
# TESTS DE MAIN FUNCTION
# =============================================================================

Describe "Main" -Tag "MainFunc" {

    BeforeAll {
        . "$PSScriptRoot\..\Source\sync_and_build.ps1"
    }

    BeforeEach {
        $script:projectName = "MyGame"
        $script:projectRoot = "C:\MyProject"
        $script:projectFile = "C:\MyProject\MyGame.uproject"
        $script:logFile = "C:\Logs\build.log"
        $script:NoPrompt = $false

        Mock Initialize-Log { }
        Mock Write-Header { }
        Mock Write-Host { }
        Mock Write-Log { }
        Mock Initialize-ProjectPaths { }
        Mock Get-UnrealEngineRoot { return "C:\UE_5.3" }
        Mock Test-UnrealEngineValid { }
        Mock Test-ProjectBinariesExist { return $true }
        Mock Sync-FromPerforce { return $true }
        Mock Get-LatestHaveChangelist { return 12345 }
        Mock Test-CodeChanges { return $false }
        Mock Invoke-ProjectBuild { return $true }
        Mock Start-UnrealEditor { return $true }
        Mock Get-ConfigValue { return 0 }
        Mock Set-ConfigValue { }
        Mock Out-File { }
        Mock Get-Date { return [DateTime]::new(2024, 12, 25, 10, 30, 0) }
        Mock Write-DetailedError { }
    }

    Context "Caso: Flujo exitoso sin cambios de código" {

        It "Completa exitosamente cuando no hay cambios de código" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltChangelist") { return 12345 }
                return $DefaultValue
            }

            { Main $false $false $false $false} | Should -Not -Throw
        }

        It "Llama Initialize-ProjectPaths al inicio" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltChangelist") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Initialize-ProjectPaths -Times 1
        }

        It "Obtiene y valida UE Root" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltChangelist") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Get-UnrealEngineRoot -Times 1
            Should -Invoke Test-UnrealEngineValid -Times 1
        }

        It "Verifica existencia de binarios" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltChangelist") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Test-ProjectBinariesExist -Times 1
        }

        It "Sincroniza desde Perforce cuando no se usa -SkipSync" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltChangelist") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Sync-FromPerforce -ParameterFilter { -not $SkipSync } -Times 1
        }

        It "No construye cuando CL actual ya fue construido" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltChangelist") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Invoke-ProjectBuild -Times 0
        }

        It "Intenta lanzar el editor al final" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltChangelist") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Start-UnrealEditor -Times 1
        }
    }

    Context "Caso: Build inicial requerido" {

        It "Ejecuta build inicial cuando binarios no existen" {
            Mock Test-ProjectBinariesExist { return $false }

            Main

            Should -Invoke Invoke-ProjectBuild -Times 1
        }

        It "Muestra mensaje de build inicial requerido" {
            Mock Test-ProjectBinariesExist { return $false }

            Main

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "INITIAL BUILD REQUIRED" -or $Object -match "Project binaries not found"
            }
        }
    }

    Context "Caso: Cambios de código detectados" {

        It "Construye cuando hay cambios de código" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltChangelist") { return 12340 }
                return $DefaultValue
            }
            Mock Test-CodeChanges { return $true }

            Main

            Should -Invoke Invoke-ProjectBuild -Times 1
        }

        It "Guarda el CL después de build exitoso" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -Match "lastBuiltCl") { return 12340 }
                return $DefaultValue
            }
            Mock Test-CodeChanges { return $true }

            Main

            Should -Invoke Set-ConfigValue -ParameterFilter {
                $Path -Match "lastBuiltCl" -and $Value -eq 12345
            }
        }

        It "Verifica cambios de código entre CLs" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -Match "lastBuiltCl") { return 12340 }
                return $DefaultValue
            }

            Main

            Should -Invoke Test-CodeChanges -ParameterFilter {
                $Changelist -eq 12345 -and $FromCL -eq 12340
            }
        }
    }

    Context "Caso: Sin cambios de código pero CL diferente" {

        It "No construye cuando no hay cambios de código" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltChangelist") { return 12340 }
                return $DefaultValue
            }
            Mock Test-CodeChanges { return $false }

            Main

            Should -Invoke Invoke-ProjectBuild -Times 0
        }

        It "Actualiza lastBuiltCL aunque no se construya" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -match "lastBuiltCL") { return 12340 }
                return $DefaultValue
            }
            Mock Test-CodeChanges { return $false }

            Main

            Should -Invoke Set-ConfigValue -ParameterFilter {
                $Path -match "lastBuiltCL" -and $Value -eq 12345
            }
        }
    }

    Context "Caso: Parámetro -ForceBuild" {

        It "Construye aunque no haya cambios cuando se usa -ForceBuild" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltCL") { return 12345 }
                return $DefaultValue
            }

            Main -ForceBuild

            Should -Invoke Invoke-ProjectBuild -Times 1
        }

        It "No verifica cambios de código cuando se usa -ForceBuild" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltCL") { return 12345 }
                return $DefaultValue
            }

            Main -ForceBuild

            Should -Invoke Test-CodeChanges -Times 0
        }
    }

    Context "Caso: Parámetro -Clean" {

        It "Pasa -CleanBuild al Invoke-ProjectBuild cuando se usa -Clean" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltCL") { return 12340 }
                return $DefaultValue
            }
            Mock Test-CodeChanges { return $true }

            Main -Clean

            Should -Invoke Invoke-ProjectBuild -ParameterFilter { $CleanBuild -eq $true }
        }

        It "Fuerza build aunque no haya cambios cuando se usa -Clean" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "lastBuiltCL") { return 12345 }
                return $DefaultValue
            }

            Main -Clean

            Should -Invoke Invoke-ProjectBuild -Times 1
        }
    }

    Context "Caso: Parámetro -SkipSync" {

        It "Pasa -SkipSync a Sync-FromPerforce" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltCL") { return 12345 }
                return $DefaultValue
            }

            Main -SkipSync

            Should -Invoke Sync-FromPerforce -ParameterFilter { $SkipSync -eq $true }
        }
    }

    Context "Caso: Errores y manejo de excepciones" {

        It "Captura excepciones genéricas y muestra SCRIPT FAILED" {
            Mock Initialize-ProjectPaths {
                throw "Generic error"
            }

            Main

            Should -Invoke Write-Host -ParameterFilter { $Object -match "SCRIPT FAILED" }
        }

        It "Escribe log ERROR cuando hay excepción" {
            Mock Initialize-ProjectPaths {
                throw "Test error"
            }

            Main

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Script failed" -and $Level -eq "ERROR"
            }
        }
    }

    Context "Caso: No se puede determinar changelist" {

        It "No construye si no hay CL y no hay -ForceBuild" {
            Mock Get-LatestHaveChangelist { throw "Cannot determine CL" }

            Main

            Should -Invoke Invoke-ProjectBuild -Times 0
        }

        It "Construye si no hay CL pero hay -ForceBuild" {
            Mock Get-LatestHaveChangelist { throw "Cannot determine CL" }

            Main -ForceBuild:$true

            Should -Invoke Invoke-ProjectBuild -Times 1
        }

        It "Muestra advertencia cuando no puede determinar CL" {
            Mock Get-LatestHaveChangelist { throw "Cannot determine CL" }

            Main

            Should -Invoke Write-Host -ParameterFilter {
                $Object -match "Cannot determine CL"
            }
        }
    }

    Context "Caso: Mensajes y logs" {

        It "Muestra header de inicio" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltCL") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Write-Header -ParameterFilter {
                $Text -match "UNREAL ENGINE - SYNC AND BUILD TOOL"
            }
        }

        It "Muestra header de completado" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltCL") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Write-Header -ParameterFilter {
                $Text -eq "COMPLETE"
            }
        }

        It "Escribe log SUCCESS al completar" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltCL") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Write-Log -ParameterFilter {
                $Message -match "Script completed successfully" -and $Level -eq "SUCCESS"
            }
        }

        It "Escribe footer al archivo de log" {
            Mock Get-ConfigValue {
                param($Path, $DefaultValue)
                if ($Path -eq "LastBuiltCL") { return 12345 }
                return $DefaultValue
            }

            Main

            Should -Invoke Out-File -ParameterFilter {
                $FilePath -match "build\.log" -and $Append -eq $true
            }
        }
    }
}