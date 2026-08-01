@echo off
chcp 65001 >nul
cd /d "%~dp0"

title Open Notebook

set "EXE=%~dp0src-tauri\target\release\open-notebook.exe"

if not exist "%EXE%" (
    echo [ERROR] open-notebook.exe not found!
    echo Expected: %EXE%
    echo.
    echo Build it first: cargo build --release --manifest-path src-tauri\Cargo.toml
    echo.
    pause
    exit /b 1
)

echo ========================================
echo    Open Notebook
echo ========================================
echo.
echo Starting application...
echo.

start "" "%EXE%"
exit /b 0
