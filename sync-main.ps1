# ============================================================
#  Open Notebook - sync-main.ps1
#  Sync manager: tracks how far the Tauri build (win-tauri) is
#  synced with the upstream `main` branch, classifies new commits
#  (portable UI vs non-portable backend/docs), and writes a report.
#
#  Marker file  <repo>\main-sync.txt  holds the commit hash up
#  to which win-tauri is synced. Update it with -MarkSynced once
#  you have ported the reported changes.
#
#  Usage:
#    sync-main.ps1               show changes since the sync marker
#    sync-main.ps1 -MarkSynced   advance the marker to origin/main
#    sync-main.ps1 -InstallCron  register a daily scheduled task
#    sync-main.ps1 -UninstallCron  remove the scheduled task
# ============================================================

param(
    [switch]$MarkSynced,
    [switch]$InstallCron,
    [switch]$UninstallCron
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$repo      = 'E:\Program\open-notebook-tauri'
$markerFile = Join-Path $repo 'main-sync.txt'
$reportFile = Join-Path $repo 'sync-report.md'
$taskName  = 'OpenNotebook-SyncCheck'

Write-Host ''
Write-Host '  ============================================' -ForegroundColor DarkCyan
Write-Host '     Open Notebook - sync: main -> win-tauri' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor DarkCyan
Write-Host ''

# ---- Scheduled task --------------------------------------------
if ($InstallCron) {
    $action = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $repo 'sync-main.ps1')`""
    schtasks /Create /F /TN $taskName /TR $action /SC DAILY /ST 09:00 | Out-Null
    Write-Host '  Scheduled task installed (daily 09:00).' -ForegroundColor Green
    Write-Host '  Runs sync-main.ps1; the report is written to sync-report.md' -ForegroundColor Gray
    exit 0
}
if ($UninstallCron) {
    schtasks /Delete /F /TN $taskName 2>$null | Out-Null
    Write-Host '  Scheduled task removed.' -ForegroundColor Green
    exit 0
}
if ($MarkSynced) {
    $head = (git -C $repo rev-parse origin/main).Trim()
    Set-Content -Path $markerFile -Value $head -NoNewline
    Write-Host ("  Marker advanced to origin/main ({0})." -f $head.Substring(0,7)) -ForegroundColor Green
    Write-Host '  Следующий запуск покажет изменения только после этой точки.' -ForegroundColor Gray
    exit 0
}

# ---- Fetch remote state ---------------------------------------------
Write-Host '  Fetch origin...' -ForegroundColor Gray
git -C $repo fetch origin --prune 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

# ---- Read the sync marker -------------------------------------------
if (Test-Path $markerFile) {
    $marker = (Get-Content $markerFile -Raw).Trim()
} else {
    $marker = $null
}
if (-not $marker) {
    Write-Host '  Маркер синхронизации не задан. Устанавливаю базовую точку...' -ForegroundColor Yellow
    # Baseline: commit up to which the Tauri build is already ported/considered.
    $marker = 'ee0ea5ebaa8b29d29b68af753d2f0edce5acab4b'
    Set-Content -Path $markerFile -Value $marker -NoNewline
    Write-Host ("  Marker = {0}" -f $marker.Substring(0,7)) -ForegroundColor Gray
}

$head = (git -C $repo rev-parse origin/main).Trim()
Write-Host ''
Write-Host ("  Синхронизировано до:  {0}" -f $marker.Substring(0,7))
Write-Host ("  Актуальный main:       {0}" -f $head.Substring(0,7))

# ---- Commits since the marker ---------------------------------------
$commits = @(git -C $repo log "$marker..origin/main" --format='%H%x09%s' 2>$null | Where-Object { $_ -match '^[0-9a-f]{40}\t' })
if ($commits.Count -eq 0) {
    Write-Host ''
    Write-Host '  win-tauri синхронизирован с main. Новых изменений нет.' -ForegroundColor Green
    Write-Host ''
    exit 0
}

# Classify each commit by the files it touches
$port = @()   # portable UI -> src/
$skip = @()   # non-portable backend
$ign  = @()   # docs / infra / tests

foreach ($line in $commits) {
    $sp = $line.IndexOf("`t")
    $hash = $line.Substring(0,7)
    $full = $line.Substring(0,40)
    $subject = $line.Substring($sp+1)

    $files = @(git -C $repo show --name-only --format='' $full 2>$null | Where-Object { $_ })
    $fc = ($files -join "`n")

    # Priority: any frontend/ touch -> portable UI. Otherwise backend -> skip.
    # Otherwise (docs/tests/infra only) -> ignore.
    $cat = 'IGN'
    if ($fc -match 'frontend/') {
        $cat = 'UI'
    } elseif ($fc -match 'open_notebook/|(^|\n)api/|run_api\.py|cubic\.yaml|supervisord') {
        $cat = 'SKIP'
    }

    $entry = [pscustomobject]@{ Cat=$cat; Hash=$hash; Subject=$subject }
    switch ($cat) {
        'UI'   { $port += $entry }
        'SKIP' { $skip += $entry }
        default { $ign  += $entry }
    }
}

Write-Host ''
Write-Host '  Новые коммиты main после точки синхронизации:' -ForegroundColor Cyan
foreach ($e in ($port + $skip + $ign)) {
    $color = switch ($e.Cat) { 'UI' {'Cyan'} 'SKIP' {'DarkGray'} default {'Gray'} }
    Write-Host ("    [{0}] {1} {2}" -f $e.Cat, $e.Hash, $e.Subject) -ForegroundColor $color
}

Write-Host ''
Write-Host '  Итог:' -ForegroundColor Yellow
Write-Host ("    {0}  UI-фичи — портировать в src/ (вручную, адаптировать)" -f $port.Count) -ForegroundColor Cyan
Write-Host ("    {0}  Backend — НЕ применимо (отдельный Rust/Python бэкенд)" -f $skip.Count) -ForegroundColor DarkYellow
Write-Host ("    {0}  Docs/infra — игнорировать" -f $ign.Count) -ForegroundColor Gray
Write-Host ''
Write-Host '  После портирования запустите:  sync-main.ps1 -MarkSynced' -ForegroundColor Green
Write-Host ''

# ---- Write report file ----------------------------------------------
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Open Notebook - sync report")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Сформировано: $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
[void]$sb.AppendLine("Синхронизировано до: $($marker.Substring(0,7)). Актуальный main: $($head.Substring(0,7))")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## UI - портировать в src/")
if ($port.Count -eq 0) { [void]$sb.AppendLine("- нет") }
foreach ($p in $port) { [void]$sb.AppendLine("- $($p.Hash) $($p.Subject)") }
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Backend - пропустить")
if ($skip.Count -eq 0) { [void]$sb.AppendLine("- нет") }
foreach ($s in $skip) { [void]$sb.AppendLine("- $($s.Hash) $($s.Subject)") }
[void]$sb.AppendLine("")
[void]$sb.AppendLine("## Docs/infra - игнорировать")
foreach ($i in $ign) { [void]$sb.AppendLine("- $($i.Hash) $($i.Subject)") }
Set-Content -Path $reportFile -Value $sb.ToString() -Encoding UTF8
Write-Host "  Отчёт сохранён: $reportFile" -ForegroundColor Gray
Write-Host ''