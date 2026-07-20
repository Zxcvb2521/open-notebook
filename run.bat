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
if not defined SURREAL_EXE (
    echo [!] surreal.exe not found. Install SurrealDB first.
    pause
    exit /b 1
)

set "EDGE_EXE="
for %%e in ("%PROGRAMFILES%\Microsoft\Edge\Application\msedge.exe" "%PROGRAMFILES(X86)%\Microsoft\Edge\Application\msedge.exe") do (
    if exist "%%~e" if not defined EDGE_EXE set "EDGE_EXE=%%~e"
)
if not defined EDGE_EXE (
    where msedge.exe >nul 2>nul && for /f "delims=" %%i in ('where msedge.exe') do if not defined EDGE_EXE set "EDGE_EXE=%%i"
)
if not defined EDGE_EXE (
    echo [!] Edge not found. Will open in default browser.
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

if /i "%1"=="-stop" goto :stop_all
if /i "%1"=="--stop" goto :stop_all

:: ============ 1. SurrealDB ============
echo [1/4] SurrealDB...
echo   Using: %SURREAL_EXE%
taskkill /im surreal.exe /f >nul 2>nul
if exist "%PROJECT_ROOT%\surreal_data\mydatabase.db\LOCK" del /f /q "%PROJECT_ROOT%\surreal_data\mydatabase.db\LOCK" >nul 2>nul

:: Start SurrealDB (hidden)
echo   Starting SurrealDB...
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath '%SURREAL_EXE%' -ArgumentList 'start --log info --user root --pass root rocksdb:%PROJECT_ROOT%\surreal_data\mydatabase.db'"

:: Wait for SurrealDB (up to 40 sec)
echo   Wait for SurrealDB...
ping -n 3 127.0.0.1 >nul
for /l %%i in (1,1,40) do (
    powershell -Command "try{$s=(Invoke-WebRequest 'http://localhost:8000/health' -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode;if($s-eq200){exit 0}}catch{};exit 1" && echo   [+] SurrealDB ready && goto :db_ok
    ping -n 2 127.0.0.1 >nul
)
echo   [!] SurrealDB failed
pause
exit /b 1
:db_ok

:: ============ 2. FastAPI ============
echo [2/4] FastAPI...
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -ArgumentList '/c title FastAPI && cd /d \"%PROJECT_ROOT%\" && uv run --env-file .env uvicorn api.main:app --host 127.0.0.1 --port 5055'"

:: Wait for FastAPI (up to 40 sec)
echo   Wait for FastAPI...
for /l %%i in (1,1,40) do (
    powershell -Command "try{$s=(Invoke-WebRequest 'http://localhost:5055/docs' -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode;if($s-eq200){exit 0}}catch{};exit 1" && echo   [+] FastAPI ready && goto :fastapi_ok
    ping -n 2 127.0.0.1 >nul
)
echo   [!] FastAPI failed
pause
exit /b 1
:fastapi_ok

:: ============ 3. Worker ============
echo [3/4] Worker...
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -ArgumentList '/c title Worker && cd /d \"%PROJECT_ROOT%\" && uv run --env-file .env surreal-commands-worker --import-modules commands'"

:: ============ 4. Frontend ============
echo [4/4] Frontend...
powershell -NoProfile -Command "Start-Process -WindowStyle Hidden -FilePath 'cmd.exe' -ArgumentList '/c title Frontend && cd /d \"%PROJECT_ROOT%\frontend\" && npm run dev'"

:: Wait for Frontend (up to 20 sec)
ping -n 3 127.0.0.1 >nul
for /l %%i in (1,1,20) do (
    powershell -Command "try{$s=(Invoke-WebRequest 'http://localhost:3000' -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode;if($s-eq200){exit 0}}catch{};exit 1" && echo   [+] Frontend ready && goto :frontend_ok
    ping -n 2 127.0.0.1 >nul
)
:frontend_ok

echo.
echo ============================================
echo   Open Notebook is RUNNING
echo.
echo   Frontend: http://localhost:3000
echo   API:      http://localhost:5055
echo ============================================
echo.
echo   Opening app window...
echo   Close it to stop all services.
echo ============================================

:: Open Edge app mode with isolated profile
set EDGE_DATA=%PROJECT_ROOT%\.edge_profile

if not exist "%EDGE_DATA%" mkdir "%EDGE_DATA%"
if defined EDGE_EXE goto :launch_edge

:: Fallback: open in browser
start "" "http://localhost:3000"
echo   Opened in browser. Press any key to stop...
pause >nul
goto :stop_all

:launch_edge
echo   Using: %EDGE_EXE%
echo   Opening app window (separate from your browser)...
echo   Close it to stop all services.
echo.
powershell -NoProfile -Command "$p=Start-Process -FilePath '%EDGE_EXE%' -ArgumentList '--app=http://localhost:3000 --user-data-dir=%EDGE_DATA% --no-first-run --no-default-browser-check' -PassThru -WindowStyle Normal; $id=$p.Id; Write-Host ('  [+] Edge PID: '+$id); $p.WaitForExit(); Write-Host '  [*] Edge closed'"

:: Edge closed, stop everything
echo.
echo   Stopping services...
goto :stop_all

:: ============ STOP ============
:stop_all
echo.
echo Stopping all services...
taskkill /im surreal.exe /f >nul 2>nul
taskkill /im uvicorn.exe /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq Frontend" /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq FastAPI" /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq Worker" /f >nul 2>nul

:: Cleanup isolated Edge profile
if exist "%EDGE_DATA%" rmdir /s /q "%EDGE_DATA%" >nul 2>nul

echo [+] All services stopped
if /i "%1"=="-stop" exit /b 0
pause
exit /b 0
