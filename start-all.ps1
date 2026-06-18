#!/usr/bin/env pwsh
# start-all.ps1 - Start Open Notebook without Docker on Windows
# Usage: .\start-all.ps1          -> start all services
#        .\start-all.ps1 -Stop    -> stop all services

param([switch]$Stop)

$ErrorActionPreference = "Stop"
$ProjectRoot = "F:\XTTS\zxcvb2521\Open_Notebook"
$PidFile    = Join-Path $ProjectRoot ".service_pids.json"

function Write-Info  { Write-Host "[*] $args" -ForegroundColor Cyan }
function Write-Ok    { Write-Host "[+] $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "[!] $args" -ForegroundColor Yellow }
function Write-Err   { Write-Host "[x] $args" -ForegroundColor Red }
function Write-Step  { Write-Host "`n--- $args" -ForegroundColor Yellow }

function Start-CmdWindow {
    param([string]$Title, [string]$Cmd)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/k title $Title " + [char]38 + " $Cmd"
    $psi.WorkingDirectory = $ProjectRoot
    $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
    $psi.UseShellExecute = $true
    return [System.Diagnostics.Process]::Start($psi)
}

# ===============================================================
# STOP
# ===============================================================
function Stop-All {
    Write-Step "Stopping services..."
    $stopped = @()
    if (Test-Path $PidFile) {
        $pids = Get-Content $PidFile -Raw | ConvertFrom-Json
        foreach ($entry in $pids.PSObject.Properties) {
            $name = $entry.Name
            $id = [int]$entry.Value
            try {
                $p = [System.Diagnostics.Process]::GetProcessById($id)
                $p.Kill()
                $p.WaitForExit(2000)
                Write-Info "$name (PID $id) stopped"
                $stopped += $id
            } catch {
                Write-Info "$name (PID $id) already dead"
            }
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    }
    foreach ($name in @("surreal","uvicorn","surreal-commands-worker","node")) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        foreach ($p in $procs) {
            if ($p.Id -ne $PID -and $stopped -notcontains $p.Id) {
                $p.Kill()
                Write-Info "$name (PID $($p.Id)) stopped"
            }
        }
    }
    Write-Ok "All services stopped"
    exit 0
}

if ($Stop) { Stop-All }

# ===============================================================
# 1. CHECK PREREQUISITES
# ===============================================================
Write-Step "Checking prerequisites"
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User") + ";" + $env:Path

$surrealExe = (Get-Command "surreal" -ErrorAction SilentlyContinue).Source
if (-not $surrealExe) {
    foreach ($p in @("$env:LOCALAPPDATA\Programs\SurrealDB\surreal.exe","${env:ProgramFiles}\SurrealDB\bin\surreal.exe")) {
        if (Test-Path $p) { $surrealExe = $p; break }
    }
}
if (-not $surrealExe) {
    Write-Err "SurrealDB not found. Install via (Admin PowerShell):"
    Write-Err "  iwr https://windows.surrealdb.com -useb | iex"
    exit 1
}
Write-Ok "SurrealDB: $surrealExe"

$uvExe = (Get-Command "uv" -ErrorAction SilentlyContinue).Source
if (-not $uvExe) { Write-Err "uv not found!"; exit 1 }
Write-Ok "uv: $uvExe"

$nodeExe = (Get-Command "node" -ErrorAction SilentlyContinue).Source
if (-not $nodeExe) { Write-Err "Node.js not found!"; exit 1 }
Write-Ok "Node.js: $nodeExe"

# ===============================================================
# 2. ENV FILE
# ===============================================================
Write-Step "Configuring .env"
$envFile    = Join-Path $ProjectRoot ".env"
$envExample = Join-Path $ProjectRoot ".env.example"

if (-not (Test-Path $envFile)) {
    if (-not (Test-Path $envExample)) {
        Write-Err ".env.example not found! Clone incomplete."
        exit 1
    }
    Copy-Item $envExample $envFile
    (Get-Content $envFile) -replace 'ws://surrealdb:8000/rpc','ws://localhost:8000/rpc' | Set-Content $envFile
    $line = Get-Content $envFile | Select-String 'OPEN_NOTEBOOK_ENCRYPTION_KEY=change-me'
    if ($line) {
        $chars = [char[]]@(0x30..0x39) + @(0x41..0x5a) + @(0x61..0x7a)
        $key = -join ($chars | Get-Random -Count 32 | ForEach-Object { [char]$_ })
        (Get-Content $envFile) -replace 'OPEN_NOTEBOOK_ENCRYPTION_KEY=change-me-to-a-secret-string',"OPEN_NOTEBOOK_ENCRYPTION_KEY=$key" | Set-Content $envFile
        Write-Info "Generated encryption key"
    }
} else {
    Write-Info ".env already exists"
}

# ===============================================================
# 3. DEPENDENCIES
# ===============================================================
Write-Step "Python dependencies (uv sync)"
Push-Location $ProjectRoot
try {
    uv sync --no-progress 2>&1 | ForEach-Object { Write-Host "   $_" }
    Write-Ok "uv sync done"
} finally { Pop-Location }

Write-Step "Frontend dependencies (npm install)"
$nmDir = Join-Path $ProjectRoot "frontend\node_modules"
if (-not (Test-Path $nmDir)) {
    Push-Location (Join-Path $ProjectRoot "frontend")
    try {
        npm install 2>&1 | ForEach-Object { Write-Host "   $_" }
        Write-Ok "npm install done"
    } finally { Pop-Location }
} else {
    Write-Info "node_modules exists, skipping"
}

# ===============================================================
# 4. DATA DIR
# ===============================================================
$surrealData = Join-Path $ProjectRoot "surreal_data"
$null = New-Item -ItemType Directory -Path $surrealData -Force
$LogDir = Join-Path $ProjectRoot "logs"
$null = New-Item -ItemType Directory -Path $LogDir -Force

# ===============================================================
# 5. START SERVICES
# ===============================================================
Write-Step "Starting services"
$ServicePids = @{}

# 5.1 SurrealDB
Write-Info "[1/4] SurrealDB (port 8000)..."
$sdbDataFile = Join-Path $surrealData "mydatabase.db"
$sdbCmd = "`"$surrealExe`" start --log info --user root --pass root rocksdb:`"$sdbDataFile`""
$sdbProc = Start-CmdWindow -Title "SurrealDB" -Cmd $sdbCmd
$ServicePids["surrealdb"] = $sdbProc.Id
Write-Info "  PID $($sdbProc.Id)"
Start-Sleep -Seconds 2

# Wait for SurrealDB
Write-Info "  Waiting for SurrealDB (up to 20s)..."
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Seconds 1
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:8000/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
        if ($r.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    if ($i -eq 10) { Write-Info "  Still waiting..." }
}
if ($ready) { Write-Ok "  SurrealDB ready" }
else        { Write-Warn "  SurrealDB started (health check pending)" }

# 5.2 FastAPI
Write-Info "[2/4] FastAPI (port 5055)..."
$apiCmd = "`"$uvExe`" run --env-file `"$envFile`" uvicorn api.main:app --host 127.0.0.1 --port 5055 --reload"
$apiProc = Start-CmdWindow -Title "FastAPI" -Cmd $apiCmd
$ServicePids["api"] = $apiProc.Id
Write-Info "  PID $($apiProc.Id)"

# 5.3 Worker
Write-Info "[3/4] Worker (background jobs)..."
$workerCmd = "`"$uvExe`" run --env-file `"$envFile`" surreal-commands-worker --import-modules commands"
$workerProc = Start-CmdWindow -Title "Worker" -Cmd $workerCmd
$ServicePids["worker"] = $workerProc.Id
Write-Info "  PID $($workerProc.Id)"

# Save PIDs
$ServicePids | ConvertTo-Json | Set-Content $PidFile -Force

# ===============================================================
# 6. FRONTEND (current window)
# ===============================================================
Write-Ok ""
Write-Ok "============================================"
Write-Ok "  Frontend:  http://localhost:3000"
Write-Ok "  API:       http://localhost:5055"
Write-Ok "  API Docs:  http://localhost:5055/docs"
Write-Ok "  Ctrl+C to stop ALL services"
Write-Ok "============================================"
Write-Info ""

Push-Location (Join-Path $ProjectRoot "frontend")
try {
    npm run dev
} finally {
    Pop-Location
    Write-Info "Frontend stopped. Stopping other services..."
    Stop-All
}
