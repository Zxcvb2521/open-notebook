@echo off
setlocal

set PROJECT_ROOT=F:\XTTS\zxcvb2521\Open_Notebook

:: ============================================================
:: STOP MODE
:: ============================================================
if /i "%1"=="-stop" goto :stop_all
if /i "%1"=="--stop" goto :stop_all

:: ============================================================
:: MAIN
:: ============================================================
cls
echo ============================================
echo   Open Notebook - запуск без Docker
echo ============================================
echo.

:: ============================================================
:: 1. CHECK PREREQUISITES
:: ============================================================
echo [*] Проверка системы...

where surreal >nul 2>nul
if errorlevel 1 (
    echo [!] SurrealDB не найден!
    echo     Запустите PowerShell от Администратора:
    echo     iwr https://windows.surrealdb.com -useb ^| iex
    pause
    exit /b 1
)
echo [+] SurrealDB: найдено

where uv >nul 2>nul
if errorlevel 1 (
    echo [!] uv не найден!
    pause
    exit /b 1
)
echo [+] uv: найдено

where node >nul 2>nul
if errorlevel 1 (
    echo [!] Node.js не найден!
    pause
    exit /b 1
)
echo [+] Node.js: найдено

:: ============================================================
:: 2. ENV FILE
:: ============================================================
echo.
echo --- Настройка .env ---

if not exist "%PROJECT_ROOT%\.env" (
    if not exist "%PROJECT_ROOT%\.env.example" (
        echo [!] .env.example не найден!
        pause
        exit /b 1
    )
    copy "%PROJECT_ROOT%\.env.example" "%PROJECT_ROOT%\.env" >nul
    echo [+] .env создан из .env.example

    :: Меняем surrealdb на localhost
    powershell -Command "(Get-Content '%PROJECT_ROOT%\.env') -replace 'ws://surrealdb:8000/rpc','ws://localhost:8000/rpc' | Set-Content '%PROJECT_ROOT%\.env'"

    :: Генерируем ключ шифрования
    powershell -Command "$f='%PROJECT_ROOT%\.env'; $c=Get-Content $f; if($c-match'change-me'){$chars=[char[]]@(0x30..0x39)+(0x41..0x5a)+(0x61..0x7a);$k=-join($chars|Get-Random -Count 32|%%{[char]$_});(Get-Content $f)-replace 'OPEN_NOTEBOOK_ENCRYPTION_KEY=change-me-to-a-secret-string',('OPEN_NOTEBOOK_ENCRYPTION_KEY='+$k)|Set-Content $f}"
    echo [+] Ключ шифрования сгенерирован
) else (
    echo [*] .env уже существует
)

:: ============================================================
:: 3. DEPENDENCIES
:: ============================================================
echo.
echo --- Python-зависимости (uv sync) ---
cd /d "%PROJECT_ROOT%"
uv sync --no-progress
if errorlevel 1 (
    echo [!] uv sync завершился с ошибкой
    pause
    exit /b 1
)
echo [+] uv sync завершён

echo.
echo --- Frontend-зависимости (npm install) ---
if not exist "%PROJECT_ROOT%\frontend\node_modules" (
    cd /d "%PROJECT_ROOT%\frontend"
    call npm install
    if errorlevel 1 (
        echo [!] npm install завершился с ошибкой
        pause
        exit /b 1
    )
    echo [+] npm install завершён
) else (
    echo [*] node_modules уже существует
)

:: ============================================================
:: 4. DATA DIR
:: ============================================================
if not exist "%PROJECT_ROOT%\surreal_data" mkdir "%PROJECT_ROOT%\surreal_data"

:: ============================================================
:: 5. START SERVICES
:: ============================================================
echo.
echo --- Запуск сервисов ---

:: 5.1 SurrealDB
echo [1/4] SurrealDB (порт 8000)...
start "SurrealDB" cmd /k "title SurrealDB && surreal start --log info --user root --pass root rocksdb:%PROJECT_ROOT%\surreal_data\mydatabase.db"
echo   Запущено в отдельном окне

:: Ждём готовность SurrealDB
echo   Ожидание запуска (до 20 сек)...
powershell -Command "$r=$false;for($i=0;$i-lt20;$i++){sleep 1;try{$x=Invoke-WebRequest 'http://localhost:8000/health' -TimeoutSec 1 -ErrorAction SilentlyContinue;if($x.StatusCode-eq200){$r=$true;break}}catch{}};if($r){Write-Host '[+] SurrealDB готова'}else{Write-Host '[*] SurrealDB запущена (health-check не прошёл)'}"

:: 5.2 FastAPI
echo [2/4] FastAPI (порт 5055)...
start "FastAPI" cmd /k "title FastAPI && cd /d %PROJECT_ROOT% && uv run --env-file .env uvicorn api.main:app --host 127.0.0.1 --port 5055 --reload"
echo   Запущено в отдельном окне

:: Ждём готовность FastAPI (чтобы миграции успели выполниться)
echo   Ожидание 10 сек перед запуском Worker...
ping -n 11 127.0.0.1 >nul

:: 5.3 Worker
echo [3/4] Worker (фоновые задачи)...
start "Worker" cmd /k "title Worker && cd /d %PROJECT_ROOT% && uv run --env-file .env surreal-commands-worker --import-modules commands"
echo   Запущено в отдельном окне

:: ============================================================
:: 6. FRONTEND (в этом окне)
:: ============================================================
echo.
echo ============================================
echo   Frontend:  http://localhost:3000
echo   API:       http://localhost:5055
echo   API Docs:  http://localhost:5055/docs
echo ============================================
echo   Закройте это окно чтобы остановить Frontend.
echo   Для остановки ВСЕХ сервисов запустите:
echo     start-all.bat -stop
echo ============================================
echo.

cd /d "%PROJECT_ROOT%\frontend"
npm run dev

:: Когда npm run dev завершается (Ctrl+C / закрытие окна):
echo.
echo [*] Frontend остановлен.
echo [*] Выполняется остановка остальных сервисов...
goto :stop_all

:: ============================================================
:: STOP ALL
:: ============================================================
:stop_all
echo.
echo --- Остановка сервисов ---

:: Убиваем по заголовку окна (надёжнее всего)
echo   Killing SurrealDB...
taskkill /fi "WINDOWTITLE eq SurrealDB" /f >nul 2>nul

echo   Killing FastAPI...
taskkill /fi "WINDOWTITLE eq FastAPI" /f >nul 2>nul

echo   Killing Worker...
taskkill /fi "WINDOWTITLE eq Worker" /f >nul 2>nul

:: Добиваем по имени процесса (на случай если заголовок не совпал)
taskkill /im surreal.exe /f >nul 2>nul
taskkill /im python.exe /fi "WINDOWTITLE eq FastAPI" /f >nul 2>nul
taskkill /im python.exe /fi "WINDOWTITLE eq Worker" /f >nul 2>nul

echo [+] Все сервисы остановлены
echo.

if /i "%1"=="-stop" exit /b 0
if /i "%1"=="--stop" exit /b 0
pause
exit /b 0
