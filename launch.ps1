# launch.ps1 — Single script: splash screen + start services + open Edge
param([string]$ProjectRoot = "")

if (-not $ProjectRoot) {
    $ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

# ==================== SPLASH SCREEN ====================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Open Notebook"
$form.Size = New-Object System.Drawing.Size(400, 180)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.ShowInTaskbar = $true
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 32)

# Icon
$icon = New-Object System.Windows.Forms.Label
$icon.Text = [char]::ConvertFromUtf32(0x1F4D6)
$icon.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 32)
$icon.AutoSize = $true
$icon.Location = New-Object System.Drawing.Point(170, 10)
$form.Controls.Add($icon)

# Title
$title = New-Object System.Windows.Forms.Label
$title.Text = "Open Notebook"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::White
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(120, 60)
$form.Controls.Add($title)

# Status
$status = New-Object System.Windows.Forms.Label
$status.Text = "Starting services..."
$status.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$status.ForeColor = [System.Drawing.Color]::FromArgb(140, 140, 160)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(150, 95)
$form.Controls.Add($status)

# Progress bar
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Style = "Marquee"
$progress.MarqueeAnimationSpeed = 30
$progress.Size = New-Object System.Drawing.Size(300, 4)
$progress.Location = New-Object System.Drawing.Point(50, 130)
$form.Controls.Add($progress)

$form.Add_Shown({ $form.Activate() })
$form.Show()
[System.Windows.Forms.Application]::DoEvents()

# ==================== AUTO-DETECT TOOLS ====================
function Find-Exe {
    param($Name, $Paths)
    foreach ($p in $Paths) {
        if (Test-Path $p) { return $p }
    }
    $found = Get-Command $Name -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    return $null
}

$surreal = Find-Exe "surreal.exe" @(
    "$env:LOCALAPPDATA\SurrealDB\surreal.exe",
    "$env:USERPROFILE\.surrealdb\surreal.exe"
)
$edge = Find-Exe "msedge.exe" @(
    "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
)
$uv = Find-Exe "uv.exe" @(
    "$env:USERPROFILE\.local\bin\uv.exe",
    "$env:LOCALAPPDATA\uv\uv.exe"
)

if (-not $surreal -or -not $uv) {
    $status.Text = "Error: surreal or uv not found"
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Seconds 2
    $form.Close()
    exit 1
}

# ==================== START SERVICES ====================
# Kill old instances
& taskkill /f /im surreal.exe 2>$null
& taskkill /f /im uvicorn.exe 2>$null
$lockFile = Join-Path $ProjectRoot "surreal_data\mydatabase.db\LOCK"
if (Test-Path $lockFile) { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue }

# 1. SurrealDB
$status.Text = "Starting SurrealDB..."
[System.Windows.Forms.Application]::DoEvents()
Start-Process -WindowStyle Hidden -FilePath $surreal -ArgumentList "start --log info --user root --pass root rocksdb:$(Join-Path $ProjectRoot 'surreal_data\mydatabase.db')"
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    try {
        $r = Invoke-WebRequest "http://localhost:8000/health" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($r.StatusCode -eq 200) { break }
    } catch {}
}

# 2. FastAPI
$status.Text = "Starting API server..."
[System.Windows.Forms.Application]::DoEvents()
$batDir = $ProjectRoot
Start-Process -WindowStyle Hidden -FilePath "cmd.exe" -ArgumentList "/c cd /d `"$batDir`" && uv run --env-file .env uvicorn api.main:app --host 127.0.0.1 --port 5055"
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    try {
        $r = Invoke-WebRequest "http://localhost:5055/docs" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($r.StatusCode -eq 200) { break }
    } catch {}
}

# 3. Worker
$status.Text = "Starting worker..."
[System.Windows.Forms.Application]::DoEvents()
Start-Process -WindowStyle Hidden -FilePath "cmd.exe" -ArgumentList "/c cd /d `"$batDir`" && uv run --env-file .env surreal-commands-worker --import-modules commands"

# 4. Frontend
$status.Text = "Starting frontend..."
[System.Windows.Forms.Application]::DoEvents()
$frontendDir = Join-Path $ProjectRoot "frontend"
Start-Process -WindowStyle Hidden -FilePath "cmd.exe" -ArgumentList "/c cd /d `"$frontendDir`" && npm run dev"
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    try {
        $r = Invoke-WebRequest "http://localhost:3000" -TimeoutSec 2 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($r.StatusCode -eq 200) { break }
    } catch {}
}

# ==================== OPEN EDGE ====================
$status.Text = "Opening app..."
[System.Windows.Forms.Application]::DoEvents()

$edgeData = Join-Path $ProjectRoot ".edge_profile"
if (-not (Test-Path $edgeData)) { New-Item -Path $edgeData -ItemType Directory -Force | Out-Null }

if ($edge) {
    $p = Start-Process -FilePath $edge -ArgumentList "--app=http://localhost:3000 --user-data-dir=$edgeData --no-first-run --no-default-browser-check" -PassThru -WindowStyle Normal

    # Start watcher in background
    $watcherScript = Join-Path $ProjectRoot "stop-watcher.ps1"
    if (Test-Path $watcherScript) {
        Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$watcherScript`" -EdgePID $($p.Id) -ProjectRoot `"$ProjectRoot`""
    }
} else {
    Start-Process "http://localhost:3000"
}

# ==================== CLOSE SPLASH ====================
$status.Text = "All ready!"
[System.Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 500

$form.Close()
$form.Dispose()
