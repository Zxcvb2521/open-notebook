# ============================================================
#  Open Notebook - Update (Tauri / Windows build)
#  Checks the LAST win-* release on the MAIN repo
#  (https://github.com/Zxcvb2521/open-notebook) and installs it.
#  Only win-* releases apply to this app (the web build has its
#  own releases in the same repo and must be ignored).
# ============================================================

$ErrorActionPreference = 'Stop'

# Force UTF-8 console output (works with `chcp 65001` from Update.bat)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Owner = 'Zxcvb2521'
$Repo  = 'open-notebook'
$ApiUrl     = "https://api.github.com/repos/$Owner/$Repo/releases?per_page=20"
$ReleasesPage = "https://github.com/$Owner/$Repo/releases"

function Get-LocalVersion {
    # 1) Registry (NSIS per-user install / MSI)
    $uninstPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($p in $uninstPaths) {
        $items = Get-ItemProperty $p -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            if ($item.DisplayName -like '*Open Notebook*') {
                if ($item.DisplayVersion) { return $item.DisplayVersion }
            }
        }
    }
    # 2) Fallback: version of the release exe inside this repo
    $exe = Join-Path $PSScriptRoot 'src-tauri\target\release\open-notebook.exe'
    if (Test-Path $exe) {
        $v = (Get-Item $exe).VersionInfo.FileVersion
        if ($v) { return $v }
    }
    return $null
}

function ConvertTo-Version {
    param([string]$Tag)
    $s = $Tag -replace '^win-', '' -replace '^v', ''
    if ($s -match '^(\d+)\.(\d+)\.(\d+)') {
        return [version]::new([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
    }
    return $null
}

function Get-LatestWinRelease {
    $headers = @{ 'User-Agent' = 'Open-Notebook-Update/1.0' }
    $rels = Invoke-RestMethod -Uri $ApiUrl -Headers $headers -TimeoutSec 15
    foreach ($r in $rels) {
        if ($r.tag_name -like 'win-*') {
            $asset = $r.assets | Where-Object { $_.name -like '*x64-setup.exe' -or $_.name -like '*setup.exe' } | Select-Object -First 1
            return [pscustomobject]@{
                Tag       = $r.tag_name
                Version   = ConvertTo-Version -Tag $r.tag_name
                Url       = $r.html_url
                AssetName = if ($asset) { $asset.name } else { '' }
                AssetUrl  = if ($asset) { $asset.browser_download_url } else { '' }
            }
        }
    }
    return $null
}

Write-Host ''
Write-Host '  ============================================' -ForegroundColor DarkCyan
Write-Host '     Open Notebook - проверка обновлений' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor DarkCyan
Write-Host ''

$local = Get-LocalVersion
if ($local) { Write-Host ("  Установленная версия: {0}" -f $local) }
else        { Write-Host '  Установленная версия: не найдена' -ForegroundColor Yellow }

Write-Host '  Проверка GitHub (Zxcvb2521/open-notebook, win-релизы)...' 
try {
    $latest = Get-LatestWinRelease
} catch {
    Write-Host ''
    Write-Host "  ОШИБКА: не удалось получить релизы: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Проверьте подключение к интернету." -ForegroundColor Red
    Write-Host ''
    Start-Process $ReleasesPage
    Write-Host '  Открыта страница релизов в браузере.' -ForegroundColor Gray
    exit 1
}

if (-not $latest) {
    Write-Host ''
    Write-Host '  win-релизы (Tauri-сборки) пока не опубликованы.' -ForegroundColor Yellow
    Start-Process $ReleasesPage
    exit 1
}

Write-Host ("  Доступная версия:      {0}  ({1})" -f $latest.Tag, $latest.Version)

$upToDate = $false
if ($local) {
    $lv = $null
    try { $lv = [version]$local } catch { $lv = $null }
    if ($lv -and $latest.Version -and $lv -ge $latest.Version) { $upToDate = $true }
}

if ($upToDate) {
    Write-Host ''
    Write-Host '  У вас установлена последняя версия. Обновление не требуется.' -ForegroundColor Green
    Write-Host ''
    exit 0
}

Write-Host ''
Write-Host '  Доступно обновление!' -ForegroundColor Green

# Warn if the app is currently running (installer cannot overwrite a running exe)
$running = Get-Process -Name 'open-notebook' -ErrorAction SilentlyContinue
if ($running) {
    Write-Host ''
    Write-Host '  ВНИМАНИЕ: приложение Open Notebook сейчас запущено.' -ForegroundColor Red
    Write-Host '  Перед установкой его нужно закрыть.' -ForegroundColor Red
}

Write-Host ''
$answer = Read-Host '  Скачать и запустить установщик? (y/n)'
if ($answer -notmatch '^[yYдД]') {
    Write-Host '  Отменено. Скачать вручную можно здесь:' -ForegroundColor Gray
    Write-Host "  $($latest.Url)" -ForegroundColor Gray
    exit 0
}

if (-not $latest.AssetUrl) {
    Write-Host '  У релиза нет установщика (.exe) в файлах. Открываю страницу релиза...' -ForegroundColor Yellow
    Start-Process $latest.Url
    exit 0
}

# Download the installer to a temp file
$tmp = Join-Path $env:TEMP $latest.AssetName
Write-Host ''
Write-Host ("  Скачивание: {0}" -f $latest.AssetName) -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $latest.AssetUrl -OutFile $tmp -UseBasicParsing -TimeoutSec 300
} catch {
    Write-Host "  ОШИБКА при скачивании: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$size = [math]::Round((Get-Item $tmp).Length / 1MB, 1)
Write-Host ("  Скачано: {0} МБ" -f $size) -ForegroundColor Green

Write-Host '  Запуск установщика...' -ForegroundColor Cyan
Start-Process $tmp

Write-Host ''
Write-Host '  Установщик запущен. Следуйте инструкциям установки.' -ForegroundColor Green
Write-Host '  После установки приложение можно запустить как обычно.' -ForegroundColor Gray
Write-Host ''
