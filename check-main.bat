@echo off
chcp 65001 >nul
cd /d "%~dp0"

title Open Notebook - Check main updates

echo ========================================
echo    Open Notebook - Check main updates
echo ========================================
echo.

set "SCRIPT=%~dp0check-main.ps1"
if not exist "%SCRIPT%" (
    echo [ERROR] check-main.ps1 not found!
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
