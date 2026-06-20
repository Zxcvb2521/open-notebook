@echo off
setlocal enabledelayedexpansion

set PROJECT_ROOT=F:\XTTS\zxcvb2521\Open_Notebook

cls
echo ============================================
echo   Open Notebook - Uninstall
echo ============================================
echo.
echo Will be removed:
echo   1. .venv           - Python virtual env (~200MB)
echo   2. node_modules    - frontend dependencies (~300MB)
echo   3. .next           - frontend build cache
echo   4. .env            - configuration file
echo   5. surreal_data    - SurrealDB database (YOUR DATA!)
echo   6. logs            - log files
echo   7. .service_pids.* - PID files
echo   (source code and .git will stay)
echo.
set /p CONFIRM="Proceed? (y/n): "
if /i not "!CONFIRM!"=="y" (
    echo Cancelled.
    pause
    exit /b 0
)

rem ============= 1. Stop services =============
echo.
echo --- 1/6. Stopping services ---
taskkill /fi "WINDOWTITLE eq SurrealDB" /f >nul 2>nul && echo   SurrealDB stopped
taskkill /fi "WINDOWTITLE eq FastAPI" /f >nul 2>nul && echo   FastAPI stopped
taskkill /fi "WINDOWTITLE eq Worker" /f >nul 2>nul && echo   Worker stopped
taskkill /im surreal.exe /f >nul 2>nul
taskkill /im uvicorn.exe /f >nul 2>nul
echo [+] All services stopped

rem ============= 2. .venv =============
echo.
echo --- 2/6. Virtual env (.venv) ---
if exist "%PROJECT_ROOT%\.venv" (
    rmdir /s /q "%PROJECT_ROOT%\.venv"
    echo [+] .venv removed
) else (
    echo [*] not found
)

rem ============= 3. node_modules + .next =============
echo.
echo --- 3/6. Frontend dependencies ---
if exist "%PROJECT_ROOT%\frontend\node_modules" (
    rmdir /s /q "%PROJECT_ROOT%\frontend\node_modules"
    echo [+] node_modules removed
) else (
    echo [*] not found
)

if exist "%PROJECT_ROOT%\frontend\.next" (
    rmdir /s /q "%PROJECT_ROOT%\frontend\.next"
    echo [+] .next (build cache) removed
) else (
    echo [*] not found
)

rem ============= 4. .env =============
echo.
echo --- 4/6. Configuration (.env) ---
if exist "%PROJECT_ROOT%\.env" (
    del /q "%PROJECT_ROOT%\.env" >nul 2>nul
    echo [+] .env removed
) else (
    echo [*] not found
)

rem ============= 5. surreal_data =============
echo.
echo --- 5/6. Database (surreal_data) ---
if exist "%PROJECT_ROOT%\surreal_data" (
    rmdir /s /q "%PROJECT_ROOT%\surreal_data"
    echo [+] surreal_data removed
) else (
    echo [*] not found
)

rem ============= 6. Other artifacts =============
echo.
echo --- 6/6. Temporary files ---

if exist "%PROJECT_ROOT%\.service_pids.json" del /q "%PROJECT_ROOT%\.service_pids.json" >nul 2>nul
if exist "%PROJECT_ROOT%\.service_pids.csv" del /q "%PROJECT_ROOT%\.service_pids.csv" >nul 2>nul

if exist "%PROJECT_ROOT%\logs" (
    rmdir /s /q "%PROJECT_ROOT%\logs"
    echo [+] logs removed
)

if exist "%PROJECT_ROOT%\uv.lock" del /q "%PROJECT_ROOT%\uv.lock" >nul 2>nul

rem ---- Launcher files ----
if exist "%PROJECT_ROOT%\run.bat" del /q "%PROJECT_ROOT%\run.bat" >nul 2>nul && echo   run.bat removed
if exist "%PROJECT_ROOT%\OpenNotebook.ps1" del /q "%PROJECT_ROOT%\OpenNotebook.ps1" >nul 2>nul && echo   OpenNotebook.ps1 removed
if exist "%PROJECT_ROOT%\OpenNotebook.bat" del /q "%PROJECT_ROOT%\OpenNotebook.bat" >nul 2>nul && echo   OpenNotebook.bat removed
if exist "%PROJECT_ROOT%\install-shortcuts.bat" del /q "%PROJECT_ROOT%\install-shortcuts.bat" >nul 2>nul && echo   install-shortcuts.bat removed
if exist "%PROJECT_ROOT%\install-service.bat" del /q "%PROJECT_ROOT%\install-service.bat" >nul 2>nul && echo   install-service.bat removed
if exist "%PROJECT_ROOT%\uninstall-service.bat" del /q "%PROJECT_ROOT%\uninstall-service.bat" >nul 2>nul && echo   uninstall-service.bat removed
if exist "%PROJECT_ROOT%\open-notebook-service.py" del /q "%PROJECT_ROOT%\open-notebook-service.py" >nul 2>nul && echo   open-notebook-service.py removed
if exist "%PROJECT_ROOT%\desktop" rmdir /s /q "%PROJECT_ROOT%\desktop" >nul 2>nul && echo   desktop folder removed
if exist "%PROJECT_ROOT%\logs" rmdir /s /q "%PROJECT_ROOT%\logs" >nul 2>nul && echo   logs removed

rem ---- Desktop shortcuts ----
if exist "%USERPROFILE%\Desktop\Open Notebook.lnk" del /q "%USERPROFILE%\Desktop\Open Notebook.lnk" >nul 2>nul && echo   Desktop shortcut removed
if exist "%USERPROFILE%\Desktop\Open Notebook - Stop.lnk" del /q "%USERPROFILE%\Desktop\Open Notebook - Stop.lnk" >nul 2>nul && echo   Stop shortcut removed
if exist "%USERPROFILE%\Desktop\Open Notebook - Start.lnk" del /q "%USERPROFILE%\Desktop\Open Notebook - Start.lnk" >nul 2>nul && echo   Start shortcut removed
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Open Notebook" rmdir /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Open Notebook" >nul 2>nul && echo   Start Menu shortcuts removed

echo [+] Temporary files cleaned

rem ============= Summary =============
echo.
echo ============================================
echo   Uninstall complete.
echo.
echo   Kept intact:
echo     - Source code (api/, frontend/, ...)
echo     - .git (version history)
echo     - start-all.bat, install.bat, uninstall.bat
echo.
echo   For clean reinstall: install.bat
echo ============================================
echo.
pause
