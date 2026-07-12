@echo off
setlocal
cd /d "%~dp0"

cls
echo ============================================
echo   Open Notebook - Install
echo ============================================
echo.

rem ============= 1. SurrealDB =============
echo --- 1/4. SurrealDB ---

where surreal >nul 2>nul
if errorlevel 1 (
    echo [!] SurrealDB not found.
    echo     Install via PowerShell ^(Admin^):
    echo     iwr https://windows.surrealdb.com -useb ^| iex
    echo.
    set WAIT_SURREAL=1
) else (
    echo [+] SurrealDB already installed
)

rem ============= 2. uv + Python =============
echo.
echo --- 2/4. Python and uv ---

where uv >nul 2>nul
if errorlevel 1 (
    echo [!] uv not found.
    echo     Install:
    echo     powershell -c "irm https://astral.sh/uv/install.ps1 ^| iex"
    pause
    exit /b 1
)
echo [+] uv found

uv python list 2>nul | findstr "3.12" >nul
if errorlevel 1 (
    echo [*] Downloading Python 3.12 via uv...
    uv python install 3.12
) else (
    echo [+] Python 3.12 already available via uv
)

rem ============= 3. Python dependencies =============
echo.
echo --- 3/4. Python dependencies (uv sync) ---

if exist ".venv" (
    echo [*] .venv exists, updating...
) else (
    echo [*] Creating virtual environment...
)

uv sync --no-progress
if errorlevel 1 (
    echo [!] uv sync failed
    pause
    exit /b 1
)
echo [+] Python dependencies installed

rem ============= 4. Frontend dependencies =============
echo.
echo --- 4/4. Frontend dependencies (npm install) ---

cd /d "%~dp0frontend"
call npm install
if errorlevel 1 (
    echo [!] npm install failed
    pause
    exit /b 1
)
echo [+] Frontend dependencies installed

rem ============= 5. .env config =============
echo.
echo --- 5/5. Config (.env) ---

cd /d "%~dp0"

if not exist ".env" (
    if not exist ".env.example" (
        echo [!] .env.example not found!
        pause
        exit /b 1
    )
    copy ".env.example" ".env" >nul
    echo [+] .env created from .env.example

    powershell -Command "(Get-Content '.env') -replace 'ws://surrealdb:8000/rpc','ws://localhost:8000/rpc' | Set-Content '.env'"

    powershell -Command "$f='.env';$c=Get-Content $f;if($c-match'change-me'){$chars=[char[]]@(0x30..0x39)+(0x41..0x5a)+(0x61..0x7a);$k=-join($chars|Get-Random -Count 32|%%{[char]$_});(Get-Content $f)-replace 'OPEN_NOTEBOOK_ENCRYPTION_KEY=change-me-to-a-secret-string',('OPEN_NOTEBOOK_ENCRYPTION_KEY='+$k)|Set-Content $f}"

    echo [+] Encryption key generated
) else (
    echo [*] .env already exists
)

rem ============= Summary =============
echo.
echo ============================================
echo   Install complete!
echo   Run: run.bat
echo ============================================
echo.

if defined WAIT_SURREAL (
    echo [!] Remember to install SurrealDB before first run^!
)

pause
