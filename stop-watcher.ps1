# stop-watcher.ps1 — Monitor Edge and stop services when it closes
param(
    [int]$EdgePID = 0,
    [string]$ProjectRoot = ""
)

if (-not $ProjectRoot) { exit 1 }

# Wait for Edge PID to exit
if ($EdgePID -gt 0) {
    try {
        $proc = Get-Process -Id $EdgePID -ErrorAction SilentlyContinue
        if ($proc) { $proc.WaitForExit() }
    } catch {}
}

# Also check if any msedge with our profile is still running
Start-Sleep -Seconds 2

# Stop all services
$procsToKill = @("surreal.exe", "uvicorn.exe", "surreal-commands-worker.exe")
foreach ($name in $procsToKill) {
    Get-Process -Name $name -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

# Kill node processes on port 3000 (frontend)
$nodePids = netstat -ano | Select-String ":3000\s" | Select-String "LISTENING" | ForEach-Object { ($_ -split "\s+")[-1] } | Sort-Object -Unique
foreach ($pid in $nodePids) {
    if ($pid -and $pid -ne "0") {
        Stop-Process -Id ([int]$pid) -Force -ErrorAction SilentlyContinue
    }
}

# Cleanup Edge profile
$edgeData = Join-Path $ProjectRoot ".edge_profile"
if (Test-Path $edgeData) {
    Remove-Item -Path $edgeData -Recurse -Force -ErrorAction SilentlyContinue
}

# Log
$logFile = Join-Path $ProjectRoot "logs\launcher.log"
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$timestamp = Get-Date -Format "HH:mm:ss"
Add-Content -Path $logFile -Value "$timestamp [*] Edge closed, all services stopped"
