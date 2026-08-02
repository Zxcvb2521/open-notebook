# ============================================================
#  Open Notebook - Check main branch updates
#  Fetches the MAIN repo (Zxcvb2521/open-notebook), shows the
#  newest commits on `main` (upstream original features) and
#  which files they touch, so you can decide what to port
#  into the Tauri build (win-tauri). Read-only, nothing is
#  changed or merged.
# ============================================================

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$repo = 'E:\Program\open-notebook-tauri'

Write-Host ''
Write-Host '  ============================================' -ForegroundColor DarkCyan
Write-Host '     Open Notebook - что нового в main' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor DarkCyan
Write-Host ''

# 1. Fetch latest state of the remote
Write-Host '  Fetch origin...' -ForegroundColor Gray
git -C $repo fetch origin --prune 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

Write-Host ''
Write-Host '  Последние коммиты main (оригинал):' -ForegroundColor Cyan
git -C $repo log origin/main --oneline -20 | ForEach-Object { Write-Host "  $_" }

Write-Host ''
Write-Host '  Какие файлы затронуты в последних 5 коммитах:' -ForegroundColor Cyan
git -C $repo log origin/main -5 --stat --format='  %h %s' | ForEach-Object { Write-Host "  $_" }

Write-Host ''
Write-Host '  Как портировать изменения в Tauri (win-tauri):' -ForegroundColor Yellow
Write-Host '    frontend/  ->  src/ (Vite React, адаптировать вручную)' -ForegroundColor Gray
Write-Host '    open_notebook/, api/  ->  plugins/ai_service.py (при необходимости)' -ForegroundColor Gray
Write-Host '    docs/, tests/, docker/...  ->  игнорировать' -ForegroundColor Gray
Write-Host ''
