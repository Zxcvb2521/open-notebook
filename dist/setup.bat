@echo off
title Open Notebook - Installer

:: Request admin rights
net session >nul 2>nul
if %errorlevel% neq 0 (
    echo Open Notebook Installer
    echo ======================
    echo.
    echo This installer requires Administrator privileges.
    echo Please run as Administrator.
    echo.
    echo Right-click ^> "Run as administrator"
    pause
    exit /b 1
)

echo Open Notebook Installer
echo ======================
echo.
echo Installing Open Notebook...
echo.

:: Run PowerShell installer
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"

echo.
echo If installation succeeded, you can now launch Open Notebook
echo from the Start Menu or Desktop shortcut.
echo.
pause
