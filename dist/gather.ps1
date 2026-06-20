$src = "F:\XTTS\zxcvb2521\Open_Notebook"
$dst = "F:\XTTS\zxcvb2521\Open_Notebook\dist"

# Batch launchers
@(
    "run.bat", "start-all.bat", "stop-all.ps1",
    "setup.bat", "setup.ps1", "uninstall.ps1",
    "install.bat", "install-shortcuts.bat",
    "install-service.bat", "uninstall-service.bat"
) | ForEach-Object {
    Copy-Item (Join-Path $src $_) (Join-Path $dst $_) -Force
    Write-Host "  $_"
}

# Core files
@(
    ".env.example", "pyproject.toml",
    "open-notebook-service.py"
) | ForEach-Object {
    Copy-Item (Join-Path $src $_) (Join-Path $dst $_) -Force
    Write-Host "  $_"
}

# Desktop app
New-Item -ItemType Directory -Path (Join-Path $dst "desktop") -Force | Out-Null
Copy-Item (Join-Path $src "desktop\app.py") (Join-Path $dst "desktop\app.py") -Force
Write-Host "  desktop\app.py"

# Open Notebook Python package
Copy-Item (Join-Path $src "open_notebook") (Join-Path $dst "open_notebook") -Recurse -Force -Exclude "__pycache__"
Write-Host "  open_notebook/"

# API package
Copy-Item (Join-Path $src "api") (Join-Path $dst "api") -Recurse -Force -Exclude "__pycache__"
Write-Host "  api/"

# Prompts
Copy-Item (Join-Path $src "prompts") (Join-Path $dst "prompts") -Recurse -Force
Write-Host "  prompts/"

# Frontend (no node_modules)
Copy-Item (Join-Path $src "frontend") (Join-Path $dst "frontend") -Recurse -Force -Exclude "node_modules"
Write-Host "  frontend/"

Write-Host ""
Write-Host "Done. Files gathered in dist/"
