# Open Notebook Installer
# Запускать от Администратора: powershell -ExecutionPolicy Bypass -File setup.ps1
# Всё устанавливается автоматически. Никаких ручных действий.

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSCommandPath
$AppName = "Open Notebook"
$InstallDir = Join-Path $env:LOCALAPPDATA $AppName
$StartMenuDir = Join-Path $env:USERPROFILE "AppData\Roaming\Microsoft\Windows\Start Menu\Programs\$AppName"
$DesktopDir = Join-Path $env:USERPROFILE "Desktop"
$UninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${AppName}"

# Проверка администратора
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Запустите от Администратора!" -ForegroundColor Red; pause; exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Open Notebook - Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Проверка зависимостей
Write-Host "[1/6] Проверка системы..." -ForegroundColor Yellow
$surrealPaths = @((Get-Command "surreal" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
    "$env:LOCALAPPDATA\SurrealDB\surreal.exe", "C:\Program Files\SurrealDB\surreal.exe")
$surrealFound = $false; foreach ($p in $surrealPaths) { if ($p -and (Test-Path $p)) { $surrealFound = $true; break } }
if (-not $surrealFound) {
    Write-Host "  [!] SurrealDB не найден. Скачиваю..." -ForegroundColor Yellow
    Invoke-WebRequest "https://windows.surrealdb.com" -UseBasicParsing -OutFile "$env:TEMP\surreal-install.ps1"
    & "$env:TEMP\surreal-install.ps1"
}
Write-Host "  [+] SurrealDB: OK" -ForegroundColor Green

if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Host "  [!] uv не найден. Скачиваю..." -ForegroundColor Yellow
    Invoke-WebRequest "https://astral.sh/uv/install.ps1" -UseBasicParsing -OutFile "$env:TEMP\uv-install.ps1"; & "$env:TEMP\uv-install.ps1"
    $env:Path = [Environment]::GetEnvironmentVariable("Path","User") + ";" + [Environment]::GetEnvironmentVariable("Path","Machine")
}
Write-Host "  [+] uv: OK" -ForegroundColor Green

if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) { Write-Host "  [!] Node.js не найден. Скачайте с https://nodejs.org" -ForegroundColor Red; exit 1 }
Write-Host "  [+] Node.js: OK" -ForegroundColor Green

# 2. Python-зависимости
Write-Host "[2/6] Установка Python-зависимостей..." -ForegroundColor Yellow
Set-Location $ProjectRoot; uv sync --no-progress
Write-Host "  [+] Python зависимости: OK" -ForegroundColor Green

# 3. .env
Write-Host "[3/6] Настройка .env..." -ForegroundColor Yellow
$envFile = Join-Path $ProjectRoot ".env"
if (-not (Test-Path $envFile)) {
    $envExample = Join-Path $ProjectRoot ".env.example"
    if (Test-Path $envExample) { Copy-Item $envExample $envFile -Force }
    $key = -join ((48..57)+(65..90)+(97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    (Get-Content $envFile) -replace 'change-me-to-a-secret-string', $key | Set-Content $envFile
    (Get-Content $envFile) -replace 'ws://surrealdb:8000/rpc', 'ws://localhost:8000/rpc' | Set-Content $envFile
    Write-Host "  [+] .env создан" -ForegroundColor Green
} else { Write-Host "  [*] .env уже есть" -ForegroundColor Gray }

# 4. Frontend-зависимости
Write-Host "[4/6] Установка Frontend-зависимостей..." -ForegroundColor Yellow
Set-Location (Join-Path $ProjectRoot "frontend"); npm install --silent; Set-Location $ProjectRoot
Write-Host "  [+] Frontend зависимости: OK" -ForegroundColor Green

# 5. Установка приложения
Write-Host "[5/6] Установка приложения..." -ForegroundColor Yellow
$null = New-Item -ItemType Directory -Path $InstallDir -Force
$null = New-Item -ItemType Directory -Path $StartMenuDir -Force

# Копируем .exe (уже предварительно собран, пересборка не требуется)
$installExe = Join-Path $ProjectRoot "OpenNotebook.exe"
if (Test-Path $installExe) { Copy-Item $installExe (Join-Path $InstallDir "OpenNotebook.exe") -Force }

# Ярлыки
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut((Join-Path $StartMenuDir "Open Notebook.lnk"))
$sc.TargetPath = Join-Path $InstallDir "OpenNotebook.exe"; $sc.WorkingDirectory = $ProjectRoot; $sc.Save()
$sc2 = $ws.CreateShortcut((Join-Path $DesktopDir "Open Notebook.lnk"))
$sc2.TargetPath = Join-Path $InstallDir "OpenNotebook.exe"; $sc2.WorkingDirectory = $ProjectRoot; $sc2.Save()

# Регистрация в Add/Remove Programs
$null = New-Item -Path $UninstallKey -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $UninstallKey -Name "DisplayName" -Value "Open Notebook"
Set-ItemProperty -Path $UninstallKey -Name "Publisher" -Value "Open Notebook"
Set-ItemProperty -Path $UninstallKey -Name "DisplayVersion" -Value "1.0.0"
Set-ItemProperty -Path $UninstallKey -Name "InstallDate" -Value (Get-Date -Format "yyyyMMdd")
Set-ItemProperty -Path $UninstallKey -Name "UninstallString" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ProjectRoot\uninstall.ps1`""

# 6. Готово
Write-Host "[6/6] Готово!" -ForegroundColor Yellow
Write-Host ""; Write-Host "============================================" -ForegroundColor Green
Write-Host "  Установка завершена!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""; Write-Host "  Ярлык на рабочем столе: Open Notebook.lnk" -ForegroundColor White
Write-Host "  Пуск > Open Notebook > Open Notebook.lnk" -ForegroundColor White
Write-Host ""; Write-Host "  Запуск: дважды кликнуть на ярлык" -ForegroundColor Cyan
Write-Host "  Удаление: Параметры > Приложения > Open Notebook" -ForegroundColor Cyan
Write-Host ""
