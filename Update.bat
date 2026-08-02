@echo off
chcp 65001 >nul
cd /d "%~dp0"

title Open Notebook - Update

echo ========================================
echo    Open Notebook - Update
echo ========================================
echo.

set "SCRIPT=%~dp0Update.ps1"
if not exist "%SCRIPT%" (
    echo [ERROR] Update.ps1 not found!
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
