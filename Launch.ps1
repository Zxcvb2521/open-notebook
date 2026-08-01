<#
  Open Notebook — One-Click Launcher
  Запускает Tauri exe в скрытом режиме (без консольного окна).
  Python AI сервис автоматически стартует/останавливается Rust-бэкендом.
#>

$ErrorActionPreference = 'SilentlyContinue'
$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

$exe = Join-Path $projectDir 'src-tauri\target\release\open-notebook.exe'

# --- Проверяем что exe существует ---
if (-not (Test-Path $exe)) {
    Write-Host "exe не найден: $exe" -ForegroundColor Red
    Write-Host "Сначала собери: cargo tauri build" -ForegroundColor Yellow
    pause
    exit 1
}

# --- Убиваем предыдущие экземпляры ---
Get-Process -Name 'open-notebook' -ErrorAction SilentlyContinue | Stop-Process -Force
# Освобождаем порт 8421 (AI service)
$occupied = Get-NetTCPConnection -LocalPort 8421 -ErrorAction SilentlyContinue
if ($occupied) {
    $occupied.OwningProcess | ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
}

# --- Запуск в скрытом режиме (без окна консоли) ---
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe
$psi.WorkingDirectory = $projectDir
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

[System.Diagnostics.Process]::Start($psi) | Out-Null
