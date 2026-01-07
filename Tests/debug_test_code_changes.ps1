# Debug script for Test-CodeChanges function
param(
    [int]$FromCL = 332,
    [int]$ToCL = 333
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Debug Test-CodeChanges Function" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Testing with FromCL: $FromCL, ToCL: $ToCL" -ForegroundColor Yellow
Write-Host ""

# Test 1: Check what changes are returned
Write-Host "[1] Testing p4 changes command:" -ForegroundColor Green
$command = "...@>$FromCL,@<=$ToCL"
Write-Host "    Command: p4 changes '$command'" -ForegroundColor Gray

try {
    $changes = p4 changes $command 2>&1
    Write-Host "    Result type: $($changes.GetType().Name)" -ForegroundColor Gray
    Write-Host "    Count: $($changes.Count)" -ForegroundColor Gray
    Write-Host "    Content:" -ForegroundColor Gray
    $changes | ForEach-Object { Write-Host "      $_" -ForegroundColor White }
} catch {
    Write-Host "    ERROR: $_" -ForegroundColor Red
}

Write-Host ""

# Test 2: Process each change
Write-Host "[2] Processing each changelist:" -ForegroundColor Green

$codeExtensions = @(".cpp", ".h")
$foundChanges = $false

foreach ($cl in $changes) {
    Write-Host "  Processing: $cl" -ForegroundColor Cyan

    $clNum = $cl

    if ($cl -match "Change (\d+)") {
        $clNum = [int]$Matches[1]
        Write-Host "    Extracted CL number: $clNum" -ForegroundColor Gray
    } else {
        Write-Host "    WARNING: Could not extract CL number from: $cl" -ForegroundColor Yellow
    }

    Write-Host "    Running: p4 describe -s $clNum" -ForegroundColor Gray
    $description = p4 describe -s $clNum 2>&1 | Out-String

    Write-Host "    Description (first 500 chars):" -ForegroundColor Gray
    $preview = if ($description.Length -gt 500) { $description.Substring(0, 500) + "..." } else { $description }
    Write-Host "      $preview" -ForegroundColor White

    Write-Host "    Testing patterns:" -ForegroundColor Gray
    foreach ($ext in $codeExtensions) {
        $pattern = [regex]::Escape($ext) + "#\d+"
        Write-Host "      Pattern: $pattern" -ForegroundColor DarkGray

        if ($description -match $pattern) {
            Write-Host "        ✓ MATCH FOUND for $ext" -ForegroundColor Green
            $foundChanges = $true

            # Show what matched
            $matches = [regex]::Matches($description, $pattern)
            foreach ($match in $matches) {
                Write-Host "          Matched: $($match.Value)" -ForegroundColor Green
            }
        } else {
            Write-Host "        ✗ No match for $ext" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "FINAL RESULT: $foundChanges" -ForegroundColor $(if ($foundChanges) { "Green" } else { "Red" })
Write-Host "============================================" -ForegroundColor Cyan
