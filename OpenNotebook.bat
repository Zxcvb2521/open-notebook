@echo off
setlocal

set PROJECT_ROOT=%~dp0
set PROJECT_ROOT=%PROJECT_ROOT:~0,-1%

if /i "%1"=="-stop" goto :stop_all
if /i "%1"=="--stop" goto :stop_all

echo Open Notebook Launcher
echo ======================
echo.
echo Starting services hidden...
echo Right-click tray icon to control.
echo.

:: Use Windows PowerShell 5.1 (supports tray icons via WinForms)
:: Fallback to PowerShell 7 if 5.1 not found
set PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
if not exist "%PS_EXE%" set PS_EXE=powershell.exe

"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%PROJECT_ROOT%\OpenNotebook.ps1"

:: If PowerShell script exited, stop remaining services
echo.
echo Shutting down...
goto :stop_all

:stop_all
taskkill /fi "WINDOWTITLE eq SurrealDB" /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq FastAPI" /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq Worker" /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq Frontend" /f >nul 2>nul
taskkill /im surreal.exe /f >nul 2>nul
taskkill /im uvicorn.exe /f >nul 2>nul
taskkill /im node.exe /f >nul 2>nul
echo [+] All services stopped
if /i "%1"=="-stop" exit /b 0
pause
exit /b 0
