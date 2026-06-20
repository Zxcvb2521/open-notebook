@echo off
setlocal enabledelayedexpansion

set PROJECT_ROOT=%~dp0
set PROJECT_ROOT=%PROJECT_ROOT:~0,-1%
set PYTHON=%PROJECT_ROOT%\.venv\Scripts\python.exe
set DESKTOP=%USERPROFILE%\Desktop
set STARTMENU=%APPDATA%\Microsoft\Windows\Start Menu\Programs
set SERVICE_NAME=OpenNotebook

title Open Notebook - Installer

echo ============================================
echo   Open Notebook - Install Service
echo ============================================
echo.

:: Check admin rights
net session >nul 2>nul
if !errorlevel! neq 0 (
    echo [!] Administrator privileges required!
    echo     Right-click and select "Run as administrator".
    echo.
    pause
    exit /b 1
)

:: Check python
if not exist "!PYTHON!" (
    echo [!] Virtual environment not found.
    echo     Run install.bat first.
    pause
    exit /b 1
)

echo [1/4] Installing Windows Service...
"!PYTHON!" "!PROJECT_ROOT!\open-notebook-service.py" install

if !errorlevel! neq 0 (
    echo [!] Service installation failed.
    pause
    exit /b 1
)
echo   [+] Service installed: Open Notebook

:: Set service to auto-start
echo [2/4] Configuring auto-start...
sc config !SERVICE_NAME! start= auto >nul
echo   [+] Service set to auto-start

:: Create desktop shortcuts
echo [3/4] Creating shortcuts...

:: Use PowerShell for shortcut creation
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ws = New-Object -ComObject WScript.Shell;" ^
"" ^
$net = '%SystemRoot%\System32\net.exe';" ^
"" ^
"$sc = $ws.CreateShortcut('%DESKTOP%\Open Notebook - Start.lnk');" ^
"$sc.TargetPath = $net;" ^
"$sc.Arguments = 'start !SERVICE_NAME!';" ^
"$sc.WorkingDirectory = '!PROJECT_ROOT!';" ^
"$sc.Description = 'Start Open Notebook service';" ^
"$sc.IconLocation = '%SystemRoot%\System32\imageres.dll,199';" ^
"$sc.Save();" ^
"Write-Host '  [+] Desktop\Open Notebook - Start.lnk';" ^
"" ^
"$sc2 = $ws.CreateShortcut('%DESKTOP%\Open Notebook - Stop.lnk');" ^
"$sc2.TargetPath = $net;" ^
"$sc2.Arguments = 'stop !SERVICE_NAME!';" ^
"$sc2.WorkingDirectory = '!PROJECT_ROOT!';" ^
"$sc2.Description = 'Stop Open Notebook service';" ^
"$sc2.IconLocation = '%SystemRoot%\System32\imageres.dll,201';" ^
"$sc2.Save();" ^
"Write-Host '  [+] Desktop\Open Notebook - Stop.lnk';" ^
"" ^
"$sc3 = $ws.CreateShortcut('%DESKTOP%\Open Notebook.lnk');" ^
"$sc3.TargetPath = '!PROJECT_ROOT!\OpenNotebook.bat';" ^
"$sc3.WorkingDirectory = '!PROJECT_ROOT!';" ^
"$sc3.Description = 'Open Notebook - open frontend';" ^
"$sc3.IconLocation = '%SystemRoot%\System32\imageres.dll,199';" ^
"$sc3.Save();" ^
"Write-Host '  [+] Desktop\Open Notebook.lnk';" ^
"" ^
"$startMenu = '%STARTMENU%\Open Notebook';" ^
"if (!(Test-Path $startMenu)) { New-Item -ItemType Directory -Path $startMenu -Force | Out-Null };" ^
"" ^
"$sc4 = $ws.CreateShortcut($startMenu + '\Open Notebook.lnk');" ^
"$sc4.TargetPath = '!PROJECT_ROOT!\OpenNotebook.bat';" ^
"$sc4.WorkingDirectory = '!PROJECT_ROOT!';" ^
"$sc4.Description = 'Open Notebook - AI-powered research assistant';" ^
"$sc4.IconLocation = '%SystemRoot%\System32\imageres.dll,199';" ^
"$sc4.Save();" ^
"Write-Host '  [+] Start Menu\Open Notebook\Open Notebook.lnk';" ^
"" ^
"$sc5 = $ws.CreateShortcut($startMenu + '\Start Service.lnk');" ^
"$sc5.TargetPath = $net;" ^
"$sc5.Arguments = 'start !SERVICE_NAME!';" ^
"$sc5.WorkingDirectory = '!PROJECT_ROOT!';" ^
"$sc5.Description = 'Start Open Notebook service';" ^
"$sc5.IconLocation = '%SystemRoot%\System32\imageres.dll,199';" ^
"$sc5.Save();" ^
"Write-Host '  [+] Start Menu\Open Notebook\Start Service.lnk';" ^
"" ^
"$sc6 = $ws.CreateShortcut($startMenu + '\Stop Service.lnk');" ^
"$sc6.TargetPath = $net;" ^
"$sc6.Arguments = 'stop !SERVICE_NAME!';" ^
"$sc6.WorkingDirectory = '!PROJECT_ROOT!';" ^
"$sc6.Description = 'Stop Open Notebook service';" ^
"$sc6.IconLocation = '%SystemRoot%\System32\imageres.dll,201';" ^
"$sc6.Save();" ^
"Write-Host '  [+] Start Menu\Open Notebook\Stop Service.lnk';"

echo.
echo [4/4] Starting service...
net start !SERVICE_NAME! >nul 2>nul
if !errorlevel! equ 0 (
    echo   [+] Service started!
) else (
    echo   [*] Service installed but not started (start manually)
)

echo.
echo ============================================
echo   Installation complete!
echo.
echo   Desktop shortcuts:
echo     Open Notebook ^<-- tray icon, open frontend
echo     Open Notebook - Start
echo     Open Notebook - Stop
echo.
echo   Start Menu:
echo     Open Notebook\Open Notebook
echo     Open Notebook\Start Service
echo     Open Notebook\Stop Service
echo.
echo   Administration:
echo     services.msc ^-^> Open Notebook
echo     net start OpenNotebook
echo     net stop OpenNotebook
echo.
echo   Uninstall:
echo     uninstall-service.bat (Run as Admin)
echo ============================================
echo.
pause
