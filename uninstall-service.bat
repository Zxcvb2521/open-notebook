@echo off
setlocal enabledelayedexpansion

set PROJECT_ROOT=%~dp0
set PROJECT_ROOT=%PROJECT_ROOT:~0,-1%
set PYTHON=%PROJECT_ROOT%\.venv\Scripts\python.exe
set SERVICE_NAME=OpenNotebook

title Open Notebook - Uninstall Service

echo ============================================
echo   Open Notebook - Uninstall Service
echo ============================================
echo.

:: Check admin rights
net session >nul 2>nul
if !errorlevel! neq 0 (
    echo [!] Administrator privileges required!
    echo     Right-click and select "Run as administrator".
    pause
    exit /b 1
)

:: Confirm
set /p CONFIRM="Remove Open Notebook service and all shortcuts? (y/n): "
if /i not "!CONFIRM!"=="y" (
    echo Cancelled.
    pause
    exit /b 0
)

echo.

:: Stop service
echo [1/4] Stopping service...
net stop !SERVICE_NAME! >nul 2>nul
echo   [+] Service stopped

:: Remove service
echo [2/4] Removing service...
if exist "!PYTHON!" (
    "!PYTHON!" "!PROJECT_ROOT!\open-notebook-service.py" remove
) else (
    sc delete !SERVICE_NAME! >nul
)
echo   [+] Service removed

:: Remove shortcuts
echo [3/4] Removing shortcuts...

if exist "%USERPROFILE%\Desktop\Open Notebook.lnk" (
    del /q "%USERPROFILE%\Desktop\Open Notebook.lnk" >nul 2>nul
    echo   [+] Desktop\Open Notebook.lnk removed
)
if exist "%USERPROFILE%\Desktop\Open Notebook - Start.lnk" (
    del /q "%USERPROFILE%\Desktop\Open Notebook - Start.lnk" >nul 2>nul
    echo   [+] Desktop\Open Notebook - Start.lnk removed
)
if exist "%USERPROFILE%\Desktop\Open Notebook - Stop.lnk" (
    del /q "%USERPROFILE%\Desktop\Open Notebook - Stop.lnk" >nul 2>nul
    echo   [+] Desktop\Open Notebook - Stop.lnk removed
)
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Open Notebook" (
    rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Open Notebook" >nul 2>nul
    echo   [+] Start Menu\Open Notebook folder removed
)

:: Clean temp files
echo [4/4] Cleaning up...
if exist "%PROJECT_ROOT%\logs" (
    rmdir /s /q "%PROJECT_ROOT%\logs" >nul 2>nul
    echo   [+] Logs removed
)

echo.
echo ============================================
echo   Uninstall complete!
echo.
echo   To remove ALL project files:
echo     uninstall.bat
echo ============================================
echo.
pause
