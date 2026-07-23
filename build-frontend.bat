@echo off
setlocal
cd /d "%~dp0frontend"

echo ============================================
echo   Frontend Build (Next.js standalone)
echo ============================================
echo.

echo [1/3] next build ...
call npx next build
if errorlevel 1 (
    echo [!] next build failed
    pause
    exit /b 1
)
echo [+] Build complete

echo.
echo [2/3] Copying static assets to standalone ...

:: Copy .next/static → .next/standalone/.next/static
robocopy ".next\static" ".next\standalone\.next\static" /E /NFL /NDL /NJH /NJS >nul
if %errorlevel% geq 8 (
    echo [!] Failed to copy .next/static
    pause
    exit /b 1
)
echo [+] .next/static copied

:: Copy public → .next/standalone/public
if exist "public" (
    robocopy "public" ".next\standalone\public" /E /NFL /NDL /NJH /NJS >nul
    echo [+] public copied
) else (
    echo [*] No public directory, skipping
)

echo.
echo [3/3] Verifying ...
if exist ".next\standalone\server.js" (
    echo [+] server.js found
) else (
    echo [!] server.js NOT found!
    pause
    exit /b 1
)

if exist ".next\standalone\.next\static" (
    echo [+] static assets present
) else (
    echo [!] static assets NOT found!
    pause
    exit /b 1
)

echo.
echo ============================================
echo   Frontend ready for production!
echo   Run run.bat to start.
echo ============================================
