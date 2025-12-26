@echo off
REM ==========================================
REM Unreal Engine - Sync and Build Tool v2.0
REM ==========================================

echo.
echo ==========================================
echo Sync and Build Tool v2.0
echo ==========================================
echo.

REM Run the PowerShell script with execution policy bypass
PowerShell.exe -ExecutionPolicy Bypass -NoProfile -Command "& { . '%~dp0sync_and_build.ps1'; Main }" %*

REM Check if PowerShell script succeeded
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ==========================================
    echo Script encountered an error!
    echo ==========================================
    echo.
    echo Check the log file for details.
    echo.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Press any key to exit...
pause >nul
exit /b 0
