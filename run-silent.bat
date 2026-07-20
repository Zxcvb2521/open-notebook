@echo off
setlocal

set PROJECT_ROOT=%~dp0
set PROJECT_ROOT=%PROJECT_ROOT:~0,-1%

title Open Notebook

:: Auto-detect tools
set "SURREAL_EXE="
for %%s in (surreal.exe) do (
    for %%d in ("%LOCALAPPDATA%\SurrealDB" "%PROGRAMFILES%\SurrealDB" "%USERPROFILE%\.surrealdb") do (
        if exist "%%~d\%%s" if not defined SURREAL_EXE set "SURREAL_EXE=%%~d\%%s"
    )
)
if not defined SURREAL_EXE (
    where surreal.exe >nul 2>nul && for /f "delims=" %%i in ('where surreal.exe') do if not defined SURREAL_EXE set "SURREAL_EXE=%%i"
)

set "EDGE_EXE="
for %%e in ("%PROGRAMFILES%\Microsoft\Edge\Application\msedge.exe" "%PROGRAMFILES(X86)%\Microsoft\Edge\Application\msedge.exe") do (
    if exist "%%~e" if not defined EDGE_EXE set "EDGE_EXE=%%~e"
)
if not defined EDGE_EXE (
    where msedge.exe >nul 2>nul && for /f "delims=" %%i in ('where msedge.exe') do if not defined EDGE_EXE set "EDGE_EXE=%%i"
)

set "UV_EXE=uv"
where uv.exe >nul 2>nul || (
    for %%d in ("%USERPROFILE%\.local\bin" "%LOCALAPPDATA%\uv") do (
        if exist "%%~d\uv.exe" set "UV_EXE=%%~d\uv.exe"
    )
)

set "NPM_CMD=npm"
where npm.cmd >nul 2>nul || (
    if exist "%PROGRAMFILES%\nodejs\npm.cmd" set "NPM_CMD=%PROGRAMFILES%\nodejs\npm.cmd"
)

:: Check required tools
if not defined SURREAL_EXE exit /b 1

:: Kill old instances
taskkill /im surreal.exe /f >nul 2>nul
taskkill /im uvicorn.exe /f >nul 2>nul
if exist "%PROJECT_ROOT%\surreal_data\mydatabase.db\LOCK" del /f /q "%PROJECT_ROOT%\surreal_data\mydatabase.db\LOCK" >nul 2>nul

:: ============ 1. SurrealDB ============
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath '%SURREAL_EXE%' -ArgumentList 'start --log info --user root --pass root rocksdb:%PROJECT_ROOT%\surreal_data\mydatabase.db'"
ping -n 3 127.0.0.1 >nul
for /l %%i in (1,1,40) do (
    powershell -Command "try{$s=(Invoke-WebRequest 'http://localhost:8000/health' -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode;if($s-eq200){exit 0}}catch{};exit 1" && goto :silent_db_ok
    ping -n 2 127.0.0.1 >nul
)
exit /b 1
:silent_db_ok

:: ============ 2. FastAPI ============
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -ArgumentList '/c title FastAPI && cd /d \"%PROJECT_ROOT%\" && uv run --env-file .env uvicorn api.main:app --host 127.0.0.1 --port 5055'"
for /l %%i in (1,1,40) do (
    powershell -Command "try{$s=(Invoke-WebRequest 'http://localhost:5055/docs' -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode;if($s-eq200){exit 0}}catch{};exit 1" && goto :silent_fastapi_ok
    ping -n 2 127.0.0.1 >nul
)
exit /b 1
:silent_fastapi_ok

:: ============ 3. Worker ============
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -ArgumentList '/c title Worker && cd /d \"%PROJECT_ROOT%\" && uv run --env-file .env surreal-commands-worker --import-modules commands'"

:: ============ 4. Frontend (standalone production mode) ============
set "FRONTEND_PORT=3000"
set "FRONTEND_DIR=%PROJECT_ROOT%\frontend"
set "FRONTEND_LOG=%PROJECT_ROOT%\logs\frontend.log"
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -ArgumentList '/c title Frontend && cd /d \"%FRONTEND_DIR%\" && set PORT=%FRONTEND_PORT% && node start-server.js > \"%FRONTEND_LOG%\" 2>&1'"
ping -n 3 127.0.0.1 >nul
for /l %%i in (1,1,20) do (
    powershell -Command "try{$s=(Invoke-WebRequest 'http://localhost:%FRONTEND_PORT%' -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode;if($s-eq200){exit 0}}catch{};exit 1" && goto :silent_frontend_ok
    ping -n 2 127.0.0.1 >nul
)
:silent_frontend_ok

:: ============ Open Edge ============
set EDGE_DATA=%PROJECT_ROOT%\.edge_profile
if not exist "%EDGE_DATA%" mkdir "%EDGE_DATA%"

if not defined EDGE_EXE exit /b 0

powershell -NoProfile -Command "$p=Start-Process -FilePath '%EDGE_EXE%' -ArgumentList '--app=http://localhost:3000 --user-data-dir=%EDGE_DATA% --no-first-run --no-default-browser-check' -PassThru -WindowStyle Normal; $p.Id | Out-File -FilePath '%TEMP%\opennotebook_edge_pid.txt' -NoNewline"

set /p EDGE_PID=<"%TEMP%\opennotebook_edge_pid.txt"

:: Start background watcher
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%PROJECT_ROOT%\stop-watcher.ps1\" -EdgePID %EDGE_PID% -ProjectRoot \"%PROJECT_ROOT%\"'"

:: Exit CMD — services and Edge are running independently
exit /b 0
