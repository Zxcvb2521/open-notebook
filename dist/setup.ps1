# Open Notebook Installer
# Запускать от Администратора: powershell -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSCommandPath
$AppName = "Open Notebook"
$CompanyName = "Open Notebook"
$InstallDir = Join-Path $env:LOCALAPPDATA $AppName
$StartMenuDir = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\$AppName"
$DesktopDir = [Environment]::GetFolderPath("Desktop")
$UninstallKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\${AppName}"

# Проверка администратора
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[!] Запустите от Администратора!" -ForegroundColor Red
    Write-Host "    powershell -ExecutionPolicy Bypass -File setup.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Open Notebook - Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Проверка зависимостей
Write-Host "[1/6] Проверка системы..." -ForegroundColor Yellow

# SurrealDB
$surrealPaths = @(
    [Environment]::GetEnvironmentVariable("LOCALAPPDATA") + "\SurrealDB\surreal.exe",
    "C:\Program Files\SurrealDB\surreal.exe",
    "C:\Program Files (x86)\SurrealDB\surreal.exe"
)
$surrealFound = $false
foreach ($p in $surrealPaths) {
    if (Test-Path $p) { $surrealFound = $true; break }
}
if (-not $surrealFound) {
    $surrealFound = !! (Get-Command "surreal" -ErrorAction SilentlyContinue)
}
if (-not $surrealFound) {
    Write-Host "  [!] SurrealDB не найден. Скачиваю..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest "https://windows.surrealdb.com" -UseBasicParsing -OutFile "$env:TEMP\surreal-install.ps1"
        & "$env:TEMP\surreal-install.ps1"
        Write-Host "  [+] SurrealDB установлен" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Не удалось скачать SurrealDB. Установите вручную:" -ForegroundColor Red
        Write-Host "      iwr https://windows.surrealdb.com -useb | iex" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "  [+] SurrealDB: OK" -ForegroundColor Green
}

# uv
if (-not (Get-Command "uv" -ErrorAction SilentlyContinue)) {
    Write-Host "  [!] uv не найден. Скачиваю..." -ForegroundColor Yellow
    Invoke-WebRequest "https://astral.sh/uv/install.ps1" -UseBasicParsing -OutFile "$env:TEMP\uv-install.ps1"
    & "$env:TEMP\uv-install.ps1"
    # Обновляем PATH для текущей сессии
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")
}
Write-Host "  [+] uv: OK" -ForegroundColor Green

# Node.js
if (-not (Get-Command "node" -ErrorAction SilentlyContinue)) {
    Write-Host "  [!] Node.js не найден. Скачайте с https://nodejs.org" -ForegroundColor Red
    exit 1
}
Write-Host "  [+] Node.js: OK" -ForegroundColor Green

# 2. Установка venv + зависимостей
Write-Host "[2/6] Установка Python-зависимостей..." -ForegroundColor Yellow
Set-Location $ProjectRoot
uv sync --no-progress
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [!] uv sync failed" -ForegroundColor Red
    exit 1
}
Write-Host "  [+] Python зависимости: OK" -ForegroundColor Green

# 3. npm install
Write-Host "[3/6] Установка Frontend-зависимостей..." -ForegroundColor Yellow
Set-Location (Join-Path $ProjectRoot "frontend")
npm install --silent
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [!] npm install failed" -ForegroundColor Red
    exit 1
}
Set-Location $ProjectRoot
Write-Host "  [+] Frontend зависимости: OK" -ForegroundColor Green

# 4. Сборка .exe через PyInstaller
Write-Host "[4/6] Сборка OpenNotebook.exe..." -ForegroundColor Yellow
.venv\Scripts\pip install pyinstaller -q
.venv\Scripts\pyinstaller --onefile --windowed --name "OpenNotebook" --distpath "." --noconfirm --clean "desktop\app.py" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  [!] Сборка .exe не удалась. Буду использовать run.bat" -ForegroundColor Yellow
} else {
    Write-Host "  [+] OpenNotebook.exe собран" -ForegroundColor Green
}

# 5. Копирование в Program Files
Write-Host "[5/6] Установка приложения..." -ForegroundColor Yellow

# Создаём папки
$null = New-Item -ItemType Directory -Path $InstallDir -Force
$null = New-Item -ItemType Directory -Path $StartMenuDir -Force

# Копируем файлы
$installExe = Join-Path $ProjectRoot "OpenNotebook.exe"
if (Test-Path $installExe) {
    Copy-Item $installExe (Join-Path $InstallDir "OpenNotebook.exe") -Force
}
Copy-Item (Join-Path $ProjectRoot "run.bat") (Join-Path $InstallDir "run.bat") -Force
Copy-Item (Join-Path $ProjectRoot "start-all.bat") (Join-Path $InstallDir "start-all.bat") -Force

# Находим и копируем SurrealDB
$surrealSrc = Get-Command "surreal" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $surrealSrc) {
    $surrealSrc = Get-ChildItem -Path "$env:LOCALAPPDATA\SurrealDB" -Filter "surreal.exe" -Recurse | Select-Object -First 1 -ExpandProperty FullName
}
if ($surrealSrc -and (Test-Path $surrealSrc)) {
    Copy-Item $surrealSrc (Join-Path $InstallDir "surreal.exe") -Force
    Write-Host "  [+] SurrealDB скопирован" -ForegroundColor Green
}

# 6. Создание ярлыков и регистрация
Write-Host "[6/6] Создание ярлыков..." -ForegroundColor Yellow

$ws = New-Object -ComObject WScript.Shell

# Start Menu
$sc = $ws.CreateShortcut((Join-Path $StartMenuDir "Open Notebook.lnk"))
$sc.TargetPath = Join-Path $InstallDir "OpenNotebook.exe"
$sc.WorkingDirectory = $ProjectRoot
$sc.Description = "Open Notebook - AI-powered research assistant"
$sc.Save()

$sc2 = $ws.CreateShortcut((Join-Path $StartMenuDir "Stop.lnk"))
$sc2.TargetPath = Join-Path $InstallDir "run.bat"
$sc2.Arguments = "-stop"
$sc2.Save()

# Desktop
$sc3 = $ws.CreateShortcut((Join-Path $DesktopDir "Open Notebook.lnk"))
$sc3.TargetPath = Join-Path $InstallDir "OpenNotebook.exe"
$sc3.WorkingDirectory = $ProjectRoot
$sc3.Description = "Open Notebook - AI-powered research assistant"
$sc3.Save()

# Регистрация в Add/Remove Programs
$null = New-Item -Path $UninstallKey -Force -ErrorAction SilentlyContinue
Set-ItemProperty -Path $UninstallKey -Name "DisplayName" -Value "Open Notebook"
Set-ItemProperty -Path $UninstallKey -Name "Publisher" -Value "Open Notebook"
Set-ItemProperty -Path $UninstallKey -Name "DisplayIcon" -Value (Join-Path $InstallDir "OpenNotebook.exe")
Set-ItemProperty -Path $UninstallKey -Name "UninstallString" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$ProjectRoot\uninstall.ps1`""
Set-ItemProperty -Path $UninstallKey -Name "DisplayVersion" -Value "1.0.0"
Set-ItemProperty -Path $UninstallKey -Name "InstallDate" -Value (Get-Date -Format "yyyyMMdd")

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Установка завершена!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Open Notebook.lnk - на рабочем столе" -ForegroundColor White
Write-Host "  Пуск > Open Notebook > Open Notebook.lnk" -ForegroundColor White
Write-Host ""
Write-Host "  Запуск: дважды кликнуть на ярлык" -ForegroundColor Cyan
Write-Host "  Удаление: Панель управления > Программы > Open Notebook" -ForegroundColor Cyan
Write-Host ""
