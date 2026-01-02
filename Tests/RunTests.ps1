<#
.SYNOPSIS
    Run Pester tests
    
.EXAMPLE
    .\RunTests.ps1
    .\RunTests.ps1 -Coverage
#>

param(
    [switch]$Coverage,
    [string]$SectionTag
)

$ErrorActionPreference = "Stop"

# Instalar Pester si no existe
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
}

Import-Module Pester

$config = New-PesterConfiguration
$config.Run.Path = $PSScriptRoot
$config.Output.Verbosity = 'Detailed'
$config.Output.StackTraceVerbosity = 'FirstLine'

if ($Coverage) {
    $config.CodeCoverage.Enabled = $true
    $config.Run.PassThru = $true
    $ParentFolder = Split-Path -Path $PSScriptRoot -Parent
    $config.CodeCoverage.Path = "$ParentFolder\Source\sync_and_build.ps1"
    
    $result = Invoke-Pester -Configuration $config

    if ($result.CodeCoverage.CommandsAnalyzedCount -gt 0) 
    {
        $coveragePercent = [math]::Round(($result.CodeCoverage.CommandsExecutedCount / $result.CodeCoverage.CommandsAnalyzedCount) * 100, 2)
    }
    else 
    {
        $coveragePercent = 0
    }

    Write-Host "Code Coverage: $coveragePercent%" -ForegroundColor $(
        if ($coveragePercent -ge 80) { 'Green' } 
        elseif ($coveragePercent -ge 60) { 'Yellow' } 
        else { 'Red' }
    )
    
} else {
    
    if ($SectionTag) {
        $config.Filter.Tag = $SectionTag
    }
    
    Invoke-Pester -Configuration $config
}