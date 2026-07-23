@echo off
title Update Open Notebook
cd /d "%~dp0"

echo ========================================
echo   Update Open Notebook
echo ========================================
echo.

echo [1/4] Fetching from original repo...
git fetch origin
echo.

echo [2/4] Fetching from fork...
git fetch fork
echo.

echo Original repo changes:
git log HEAD..origin/main --oneline 2>nul
if errorlevel 1 (
    git log HEAD..origin/win --oneline 2>nul
)
echo.

echo Fork changes:
git log HEAD..fork/win --oneline 2>nul
echo.

echo [3/4] Merging and updating...
git merge origin/main --no-edit 2>nul || git merge origin/win --no-edit 2>nul
echo.

echo [4/4] Installing dependencies and building...
call install.bat
echo.

echo ========================================
echo   Done! Run run.bat to start.
echo ========================================
echo.
pause
