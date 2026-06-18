<#
.SYNOPSIS
    Open Notebook Launcher - tray icon, hidden services, one-click control
.DESCRIPTION
    Starts all 4 services hidden, shows tray icon, manages lifecycle.
    Run via: OpenNotebook.ps1
    Stop via: Right-click tray icon -> Stop All, or run .\run.bat -stop
#>

$ProjectRoot = Split-Path -Parent $PSCommandPath

# ===================== Import WinForms =====================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===================== Service Management =====================
$global:Processes = @{}  # "name" -> process object
$global:Running = $false
$global:TrayIcon = $null

function Start-ServiceHidden {
    param([string]$Name, [string]$Title, [string]$Command, [string]$WorkDir)

    $logFile = "$ProjectRoot\logs\$Name.log"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/c title $Title && $Command"
    $psi.WorkingDirectory = $WorkDir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true  # COMPLETELY HIDDEN

    $p = [System.Diagnostics.Process]::Start($psi)
    
    $global:Processes[$Name] = $p
    Write-Host "  [+] $Name started (PID: $($p.Id))"
}

function Start-AllServices {
    if ($global:Running) { return }
    $global:Running = $true

    Write-Host "Starting Open Notebook..."
    Write-Host ""

    # 1. SurrealDB
    Write-Host "[1/4] SurrealDB..."
    Start-ServiceHidden "SurrealDB" "SurrealDB" "surreal start --log info --user root --pass root rocksdb:$ProjectRoot\surreal_data\mydatabase.db" $ProjectRoot

    # Wait for SurrealDB
    Write-Host "  Wait for SurrealDB..."
    $dbOk = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Seconds 1
        try {
            $r = Invoke-WebRequest "http://localhost:8000/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
            if ($r.StatusCode -eq 200) { $dbOk = $true; break }
        } catch {}
    }
    if ($dbOk) { Write-Host "  [+] SurrealDB ready" } else { Write-Host "  [*] SurrealDB started" }

    # 2. FastAPI
    Write-Host "[2/4] FastAPI..."
    Start-ServiceHidden "FastAPI" "FastAPI" "cd /d $ProjectRoot && uvicorn api.main:app --host 127.0.0.1 --port 5055" $ProjectRoot

    # Wait for FastAPI
    Write-Host "  Wait for FastAPI..."
    Start-Sleep -Seconds 3
    $apiOk = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        try {
            $r = Invoke-WebRequest "http://localhost:5055/docs" -TimeoutSec 1 -ErrorAction SilentlyContinue
            if ($r.StatusCode -eq 200) { $apiOk = $true; break }
        } catch {}
    }
    if ($apiOk) { Write-Host "  [+] FastAPI ready" } else { Write-Host "  [*] FastAPI might not be ready" }

    # 3. Worker
    Write-Host "[3/4] Worker..."
    Start-ServiceHidden "Worker" "Worker" "cd /d $ProjectRoot && uv run --env-file .env surreal-commands-worker --import-modules commands" $ProjectRoot

    # 4. Frontend
    Write-Host "[4/4] Frontend..."
    Start-ServiceHidden "Frontend" "Frontend" "cd /d $ProjectRoot\frontend && npm run dev" $ProjectRoot

    # Wait for Frontend
    Write-Host "  Wait for Frontend..."
    $feOk = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Seconds 1
        try {
            $r = Invoke-WebRequest "http://localhost:3000" -TimeoutSec 1 -ErrorAction SilentlyContinue
            if ($r.StatusCode -eq 200) { $feOk = $true; break }
        } catch {}
    }
    if ($feOk) { Write-Host "  [+] Frontend ready" } else { Write-Host "  [*] Frontend might not be ready" }

    Write-Host ""
    Write-Host "============================================"
    Write-Host "  Open Notebook is RUNNING"
    Write-Host "  Frontend: http://localhost:3000"
    Write-Host "  API:      http://localhost:5055"
    Write-Host "============================================"
    Write-Host "  Right-click tray icon to Stop All"
    Write-Host "============================================"

    # Open browser
    Start-Process "http://localhost:3000"
}

function Stop-AllServices {
    Write-Host "Stopping all services..."
    $global:Running = $false

    # Stop in reverse order
    $names = @("Frontend", "Worker", "FastAPI", "SurrealDB")
    foreach ($name in $names) {
        if ($global:Processes[$name] -and !$global:Processes[$name].HasExited) {
            try {
                $global:Processes[$name].Kill()
                $global:Processes[$name].WaitForExit(3000)
                Write-Host "  [+] $name stopped"
            } catch {
                Write-Host "  [*] $name already stopped"
            }
        }
    }

    # Kill any remaining by window title
    taskkill /fi "WINDOWTITLE eq SurrealDB" /f > $null 2>&1
    taskkill /fi "WINDOWTITLE eq FastAPI" /f > $null 2>&1
    taskkill /fi "WINDOWTITLE eq Worker" /f > $null 2>&1
    taskkill /fi "WINDOWTITLE eq Frontend" /f > $null 2>&1
    taskkill /im surreal.exe /f > $null 2>&1

    Write-Host "[+] All services stopped"
}

# ===================== Tray Icon =====================
function Show-TrayIcon {
    $icon = New-Object System.Windows.Forms.NotifyIcon
    $icon.Text = "Open Notebook"

    # Create a simple icon programmatically (green circle)
    $bmp = New-Object System.Drawing.Bitmap(16, 16)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = "HighQuality"
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Point(0,0)),
        (New-Object System.Drawing.Point(16,16)),
        [System.Drawing.Color]::LimeGreen,
        [System.Drawing.Color]::DarkGreen
    )
    $g.FillEllipse($brush, 0, 0, 15, 15)
    $g.Dispose()
    $icon.Icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())

    # Context menu
    $menu = New-Object System.Windows.Forms.ContextMenuStrip

    $openItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $openItem.Text = "Open Frontend"
    $openItem.Add_Click({ Start-Process "http://localhost:3000" })
    $menu.Items.Add($openItem)

    $apiItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $apiItem.Text = "Open API Docs"
    $apiItem.Add_Click({ Start-Process "http://localhost:5055/docs" })
    $menu.Items.Add($apiItem)

    $menu.Items.Add("-")

    $stopItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $stopItem.Text = "Stop All"
    $stopItem.Add_Click({
        $icon.Visible = $false
        Stop-AllServices
        [System.Windows.Forms.Application]::Exit()
    })
    $menu.Items.Add($stopItem)

    $exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitItem.Text = "Exit"
    $exitItem.Add_Click({
        $icon.Visible = $false
        Stop-AllServices
        [System.Windows.Forms.Application]::Exit()
    })
    $menu.Items.Add($exitItem)

    # Double-click opens frontend
    $icon.Add_MouseDoubleClick({
        Start-Process "http://localhost:3000"
    })

    $icon.ContextMenuStrip = $menu
    $icon.Visible = $true
    $global:TrayIcon = $icon

    # Run message loop (keeps script alive)
    [System.Windows.Forms.Application]::Run()
}

# ===================== Main =====================
try {
    Start-AllServices
    Show-TrayIcon
} catch {
    Write-Host "ERROR: $_"
    Stop-AllServices
    Read-Host "Press Enter to exit"
}

# Cleanup on exit
if ($global:TrayIcon) { $global:TrayIcon.Dispose() }
Stop-AllServices
