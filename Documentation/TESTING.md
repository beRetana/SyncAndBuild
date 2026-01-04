# Testing Guide - AutoSyncBuild v2.0

This document provides comprehensive information about the testing infrastructure for the AutoSyncBuild tool.

---

## Table of Contents
- [Overview](#overview)
- [Test Coverage](#test-coverage)
- [Getting Started](#getting-started)
- [Running Tests](#running-tests)
- [Test Organization](#test-organization)
- [Writing Tests](#writing-tests)
- [Mock Patterns](#mock-patterns)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Overview

The AutoSyncBuild tool uses **Pester** (PowerShell testing framework) for unit testing. Our test suite provides:

- **97.3% code coverage** across all critical paths
- **240+ comprehensive tests** covering all functionality
- **Tag-based organization** for running specific test suites
- **Automated coverage reporting** to track test quality
- **Mock-based testing** for external dependencies (Perforce, file system, processes)

---

## Test Coverage

### Current Statistics
- **Lines Covered:** 97.3% (542/557 lines)
- **Functions Covered:** 100% (23/23 functions)
- **Total Tests:** 240+

### Coverage by Module

| Module | Function Count | Coverage | Tests |
|--------|---------------|----------|-------|
| Perforce Integration | 5 | 100% | 80+ |
| Unreal Engine | 3 | 100% | 45+ |
| Build System | 4 | 100% | 50+ |
| Editor Launch | 1 | 100% | 28 |
| Configuration | 4 | 100% | 30+ |
| Main Workflow | 1 | 95% | 30 |

### What's Not Covered
The remaining ~2.7% consists of:
- Unreachable error paths in deeply nested try-catch blocks
- Edge cases in external command error handling
- PowerShell language limitations (e.g., `exit` keyword cannot be tested)

---

## Getting Started

### Prerequisites
- PowerShell 5.0 or higher
- Pester module (will be auto-installed if missing)

### First-Time Setup

The test runner will automatically install Pester if it's not present:

```powershell
# Navigate to project root
cd C:\Path\To\AutoSyncBuild_v2.0\SyncAndBuild

# Run tests (Pester will be installed if needed)
.\Tests\RunTests.ps1
```

### Manual Pester Installation

If you prefer to install Pester manually:

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
```

---

## Running Tests

### Basic Test Runs

**Run all tests:**
```powershell
.\Tests\RunTests.ps1
```

**Run with coverage report:**
```powershell
.\Tests\RunTests.ps1 -Coverage
```

**Run verbose output:**
```powershell
.\Tests\RunTests.ps1 -Verbose
```

### Tag-Based Test Runs

Run specific test suites using tags:

```powershell
# Perforce integration tests
.\Tests\RunTests.ps1 -SectionTag Perforce

# Build system tests
.\Tests\RunTests.ps1 -SectionTag Build

# Unreal Engine tests
.\Tests\RunTests.ps1 -SectionTag UnrealEngine

# Editor launch tests
.\Tests\RunTests.ps1 -SectionTag Editor

# Main workflow tests
.\Tests\RunTests.ps1 -SectionTag MainFunc

# Configuration tests
.\Tests\RunTests.ps1 -SectionTag Configuracion

# Logging tests
.\Tests\RunTests.ps1 -SectionTag Logging

# Project initialization tests
.\Tests\RunTests.ps1 -SectionTag IniciacionProyecto
```

### VSCode Integration

Launch configurations are available in `.vscode/launch.json`:

1. Open the **Run and Debug** panel (Ctrl+Shift+D)
2. Select a configuration:
   - **Run Tests** - All tests
   - **Run Tests (Coverage)** - With coverage report
   - **Run Tests (Perforce)** - Perforce tests only
   - **Run Tests (Build)** - Build tests only
   - **Run Tests (Editor)** - Editor tests only
   - **Run Tests (MainFunc)** - Main workflow tests
   - And more...
3. Press F5 to run

---

## Test Organization

### Test File Structure

```
Tests/
├── RunTests.ps1                    ← Test runner script
└── SyncAndBuild.Tests.ps1          ← Main test file (4,760+ lines)
    ├── Describe: Initialize-ProjectPaths
    ├── Describe: Get-Config
    ├── Describe: Save-Config
    ├── Describe: Write-DetailedError
    ├── Describe: Write-Log
    ├── Describe: Sync-PerforceWorkspace
    ├── Describe: Get-CurrentChangelist
    ├── Describe: Get-LatestHaveChangelist
    ├── Describe: Test-CodeChanges
    ├── Describe: Get-UnrealEnginePaths
    ├── Describe: Select-UnrealEngine
    ├── Describe: Test-UnrealEngineInstallation
    ├── Describe: Invoke-ProjectBuild
    ├── Describe: Test-ProjectBinariesExist
    ├── Describe: Start-UnrealEditor
    └── Describe: Main
```

### Test Tags

Tests are organized with the following tags:

| Tag | Purpose | Test Count |
|-----|---------|------------|
| `IniciacionProyecto` | Project path detection and initialization | 25+ |
| `Configuracion` | Config file loading and saving | 30+ |
| `Logging` | Logging system and error reporting | 20+ |
| `Perforce` | Perforce integration (sync, changelist detection) | 80+ |
| `UnrealEngine` | UE installation detection and validation | 45+ |
| `Build` | Build execution and binary verification | 50+ |
| `Editor` | Editor launch and user interaction | 28 |
| `MainFunc` | Main workflow orchestration | 30 |

---

## Troubleshooting

### Common Issues

#### Issue: "Could not find Command exit"

**Problem:** Tests trying to mock the `exit` keyword fail because `exit` is a PowerShell language keyword, not a function.

**Solution:** Don't mock or verify `exit`. Remove from Main function if testing is required.

```powershell
# ❌ This will fail
Mock exit { }

# ✅ Remove exit or accept it can't be tested
```

#### Issue: "No se encuentra ninguna sobrecarga para Add"

**Problem:** Trying to add tags to Pester configuration incorrectly.

**Solution:** Use direct assignment instead of `.Add()`:

```powershell
# ❌ This may fail
$config.Filter.Tag.Add($SectionTag)

# ✅ This works
$config.Filter.Tag = $SectionTag
```

#### Issue: Tests pass individually but fail when run together

**Problem:** Shared state between tests (script-scoped variables).

**Solution:** Reset all script variables in `BeforeEach`:

```powershell
BeforeEach {
    $script:PROJECT_NAME = "TestProject"
    $script:PROJECT_ROOT = "C:\TestProject"
    $script:UPROJECT_PATH = "C:\TestProject\TestProject.uproject"
    # Reset all other script variables
}
```

#### Issue: "Exception was not thrown" when testing error cases

**Problem:** Function catches exceptions internally instead of re-throwing.

**Solution:** Test error handling behavior instead of expecting throws:

```powershell
# ❌ If function catches exceptions internally
{ SomeFunction } | Should -Throw

# ✅ Verify error handling instead
Mock Write-DetailedError { }
SomeFunction
Should -Invoke Write-DetailedError -Times 1
```

### Coverage Report Issues

#### Coverage appears lower than expected

**Check these:**
1. Run with `-Coverage` flag: `.\Tests\RunTests.ps1 -Coverage`
2. Ensure all `Describe` blocks have appropriate tags
3. Verify mocks are set up correctly (unmocked functions won't execute)
4. Check if functions are actually being called in tests

#### "Commands not analyzed" message

**Cause:** Pester couldn't find the source file or path is incorrect.

**Solution:** Verify the path in `RunTests.ps1`:

```powershell
$ParentFolder = Split-Path -Path $PSScriptRoot -Parent
$config.CodeCoverage.Path = "$ParentFolder\Source\sync_and_build.ps1"
```
---

## Performance

### Test Execution Times

Typical execution times on modern hardware:

| Test Suite | Test Count | Execution Time |
|------------|------------|----------------|
| All Tests | 240+ | ~15-20 seconds |
| Perforce | 80+ | ~5 seconds |
| Build | 50+ | ~4 seconds |
| UnrealEngine | 45+ | ~3 seconds |
| MainFunc | 30 | ~3 seconds |
| Configuration | 30+ | ~2 seconds |
| Editor | 28 | ~2 seconds |

### Optimization Tips

1. **Use `BeforeAll` for expensive setup** that doesn't change between tests
2. **Mock external commands** to avoid actual file system or network operations
3. **Run specific tags** during development instead of full suite
4. **Parallel execution** - Pester 5.x supports parallel test runs (not configured by default)

---

## Continuous Integration

### Running Tests in CI/CD

Example PowerShell script for CI:

```powershell
# ci-test.ps1
$ErrorActionPreference = "Stop"

# Run tests with coverage
.\Tests\RunTests.ps1 -Coverage

# Check if tests passed
if ($LASTEXITCODE -ne 0) {
    Write-Error "Tests failed"
    exit 1
}

# Verify minimum coverage threshold
$result = Invoke-Pester -Configuration $config -PassThru
$coverage = ($result.CodeCoverage.CommandsExecutedCount / $result.CodeCoverage.CommandsAnalyzedCount) * 100

if ($coverage -lt 90) {
    Write-Error "Coverage $coverage% is below threshold of 90%"
    exit 1
}

Write-Host "✅ All tests passed with $coverage% coverage" -ForegroundColor Green
```

---

## Contributing

### Adding New Tests

When adding new functionality to `sync_and_build.ps1`:

1. **Write tests first** (TDD approach recommended)
2. **Add appropriate tags** to the `Describe` block
3. **Update this documentation** if adding new test categories
4. **Run coverage report** to ensure new code is tested
5. **Update VSCode launch.json** if adding new tags

### Test Review Checklist

Before committing tests:
- [ ] All tests pass individually
- [ ] All tests pass when run together
- [ ] Coverage report shows new code is tested
- [ ] Test names are descriptive
- [ ] Mocks are set up correctly
- [ ] Edge cases are covered
- [ ] Tests are tagged appropriately
- [ ] No hardcoded paths (use variables)

---

## Reference

### Pester Documentation
- [Pester Official Docs](https://pester.dev/)
- [Pester Quick Start](https://pester.dev/docs/quick-start)
- [Mocking in Pester](https://pester.dev/docs/usage/mocking)

### PowerShell Testing Resources
- [PowerShell Testing Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/testing-best-practices)
- [Pester Code Coverage](https://pester.dev/docs/usage/code-coverage)

---

## Support

### Getting Help
1. Check this guide first
2. Review existing tests for patterns
3. Run tests with `-Verbose` for detailed output
4. Check Pester documentation
5. Contact the tool maintainer

### Reporting Test Issues
Include:
- Full error message
- Test output with `-Verbose`
- PowerShell version (`$PSVersionTable`)
- Pester version (`Get-Module Pester -ListAvailable`)

---

*Last updated: 2026-01-03 | Version: 2.0 | Coverage: 97.3%*
