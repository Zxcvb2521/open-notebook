@echo off
setlocal

set PROJECT_ROOT=%~dp0
set PROJECT_ROOT=%PROJECT_ROOT:~0,-1%

title Open Notebook

:: Если передан ключ -stop - останавливаем всё
if /i "%1"=="-stop" goto :stop_all
if /i "%1"=="--stop" goto :stop_all

:: ============ 1. SurrealDB ============
echo [1/4] SurrealDB...
start "SurrealDB" /min cmd /c "title SurrealDB && surreal start --log info --user root --pass root rocksdb:%PROJECT_ROOT%\surreal_data\mydatabase.db"

:: Ожидание SurrealDB (до 15 сек)
echo   Wait for SurrealDB...
ping -n 2 127.0.0.1 >nul
for /l %%i in (1,1,15) do (
    >nul 2>&1 powershell -Command "&{try{exit (Invoke-WebRequest 'http://localhost:8000/health' -TimeoutSec 1 -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode}catch{exit 1}}" && echo   [+] SurrealDB ready && goto :db_ok
    ping -n 2 127.0.0.1 >nul
)
echo   [*] SurrealDB started (health-check skipped)
:db_ok

:: ============ 2. FastAPI ============
echo [2/4] FastAPI...
start "FastAPI" /min cmd /c "title FastAPI && cd /d %PROJECT_ROOT% && uvicorn api.main:app --host 127.0.0.1 --port 5055"

:: ============ 3. Worker ============
echo [3/4] Worker...
ping -n 4 127.0.0.1 >nul
start "Worker" /min cmd /c "title Worker && cd /d %PROJECT_ROOT% && uv run --env-file .env surreal-commands-worker --import-modules commands"

:: ============ 4. Frontend ============
echo [4/4] Frontend...
start "Frontend" /min cmd /c "title Frontend && cd /d %PROJECT_ROOT%\frontend && npm run dev"

:: Ожидание Frontend (до 20 сек)
echo   Wait for Frontend...
ping -n 3 127.0.0.1 >nul
for /l %%i in (1,1,20) do (
    >nul 2>&1 powershell -Command "&{try{exit (Invoke-WebRequest 'http://localhost:3000' -TimeoutSec 1 -UseBasicParsing -ErrorAction SilentlyContinue).StatusCode}catch{exit 1}}" && echo   [+] Frontend ready && goto :frontend_ok
    ping -n 2 127.0.0.1 >nul
)
:frontend_ok

:: ============ Открыть браузер ============
echo.
echo ============================================
echo   Open Notebook is RUNNING
echo.
echo   Frontend: http://localhost:3000
echo   API:      http://localhost:5055
echo ============================================
echo   Close this window to stop all services.
echo   Or run: run.bat -stop
echo ============================================
echo.

start "" "http://localhost:3000"

:: Ожидание закрытия
echo Press any key to stop all services...
pause >nul
goto :stop_all

:: ============ STOP ============
:stop_all
echo.
echo Stopping all services...
taskkill /fi "WINDOWTITLE eq SurrealDB" /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq FastAPI" /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq Worker" /f >nul 2>nul
taskkill /fi "WINDOWTITLE eq Frontend" /f >nul 2>nul
taskkill /im surreal.exe /f >nul 2>nul
taskkill /im node.exe /fi "WINDOWTITLE eq Frontend" /f >nul 2>nul
echo [+] All services stopped

if /i "%1"=="-stop" exit /b 0
pause
exit /b 0
