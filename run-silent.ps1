# run-silent.ps1 — Launch run.bat hidden (no CMD window visible)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir

$batPath = Join-Path $scriptDir "run.bat"
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "cmd.exe"
$psi.Arguments = "/c `"$batPath`" -silent"
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
$psi.WorkingDirectory = $scriptDir

$proc = [System.Diagnostics.Process]::Start($psi)
Write-Host "[+] Started run.bat silently (PID: $($proc.Id))"
