@echo off
setlocal

set PROJECT_ROOT=%~dp0
set PROJECT_ROOT=%PROJECT_ROOT:~0,-1%

set DESKTOP=%USERPROFILE%\Desktop

echo ============================================
echo   Open Notebook - Install Shortcuts
echo ============================================
echo.

:: Create shortcuts using PowerShell (most reliable method)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ws = New-Object -ComObject WScript.Shell;" ^
"$sc = $ws.CreateShortcut('%DESKTOP%\Open Notebook.lnk');" ^
"$sc.TargetPath = '%PROJECT_ROOT%\OpenNotebook.bat';" ^
"$sc.WorkingDirectory = '%PROJECT_ROOT%';" ^
"$sc.Description = 'Open Notebook - AI-powered research assistant';" ^
"$sc.IconLocation = '%SystemRoot%\System32\imageres.dll,199';" ^
"$sc.Save();" ^
"Write-Host '  [+] Shortcut created: Desktop\Open Notebook.lnk';" ^
"" ^
"$sc2 = $ws.CreateShortcut('%DESKTOP%\Open Notebook - Stop.lnk');" ^
"$sc2.TargetPath = '%PROJECT_ROOT%\run.bat';" ^
"$sc2.Arguments = '-stop';" ^
"$sc2.WorkingDirectory = '%PROJECT_ROOT%';" ^
"$sc2.Description = 'Stop all Open Notebook services';" ^
"$sc2.IconLocation = '%SystemRoot%\System32\imageres.dll,201';" ^
"$sc2.Save();" ^
"Write-Host '  [+] Shortcut created: Desktop\Open Notebook - Stop.lnk';" ^
"" ^
"$sc3 = $ws.CreateShortcut('%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Open Notebook.lnk');" ^
"$sc3.TargetPath = '%PROJECT_ROOT%\OpenNotebook.bat';" ^
"$sc3.WorkingDirectory = '%PROJECT_ROOT%';" ^
"$sc3.Description = 'Open Notebook - AI-powered research assistant';" ^
"$sc3.IconLocation = '%SystemRoot%\System32\imageres.dll,199';" ^
"$sc3.Save();" ^
"Write-Host '  [+] Shortcut created: Start Menu\Open Notebook.lnk';"

echo.
echo ============================================
echo   Shortcuts installed!
echo.
echo   Desktop:
echo     Open Notebook.lnk       - Launch (tray)
echo     Open Notebook - Stop.lnk - Stop all
echo.
echo   Start Menu:
echo     Open Notebook.lnk
echo ============================================
echo.
pause
