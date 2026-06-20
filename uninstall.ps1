# Open Notebook Uninstaller
$AppName = "Open Notebook"
$InstallDir = Join-Path $env:LOCALAPPDATA $AppName
$StartMenuDir = Join-Path $env:USERPROFILE "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\$AppName"
$DesktopDir = Join-Path $env:USERPROFILE "Desktop"
$UninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${AppName}"

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Запустите от Администратора!" -ForegroundColor Red
    pause
    exit 1
}

Write-Host "Удаление Open Notebook..." -ForegroundColor Yellow

# Stop if running
taskkill /im OpenNotebook.exe /f 2>$null
taskkill /im surreal.exe /f 2>$null

# Remove shortcuts
if (Test-Path $DesktopDir\Open Notebook.lnk) { Remove-Item "$DesktopDir\Open Notebook.lnk" -Force }
if (Test-Path $StartMenuDir) { Remove-Item $StartMenuDir -Recurse -Force }
Write-Host "  [+] Ярлыки удалены" -ForegroundColor Green

# Remove files
if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
Write-Host "  [+] Программа удалена" -ForegroundColor Green

# Remove from registry
if (Test-Path $UninstallKey) { Remove-Item $UninstallKey -Recurse -Force }
Write-Host "  [+] Регистрация удалена" -ForegroundColor Green

Write-Host ""
Write-Host "Готово!" -ForegroundColor Green
pause
