@echo off
chcp 65001 >nul
cd /d "%~dp0"

title Open Notebook - Sync main -> win-tauri

echo ========================================
echo    Open Notebook - Sync main -> win-tauri
echo ========================================
echo.

set "SCRIPT=%~dp0sync-main.ps1"
if not exist "%SCRIPT%" (
    echo [ERROR] sync-main.ps1 not found!
    echo Expected: %SCRIPT%
    echo.
    pause
    exit /b 1
)

where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
)

echo.
pause
exit /b 0