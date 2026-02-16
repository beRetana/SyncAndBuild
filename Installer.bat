@echo off
where pythonw >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Python was not found. Download it at https://www.python.org/downloads/
    pause >nul
    exit /b 1
)
start "" pythonw "%~dp0Installer.pyw"
exit /b 0