# Create GitHub Release with Installer
# Usage: .\create-release.ps1 YOUR_GITHUB_TOKEN

param(
    [Parameter(Mandatory=$true)]
    [string]$Token
)

$ErrorActionPreference = "Stop"
$Repo = "Zxcvb2521/open-notebook"
$Tag = "win-v1.12.0"
$Installer = "F:\XTTS\zxcvb2521\Open_Notebook\installer\OpenNotebook-Setup-1.12.0.exe"

Write-Host "Creating release $Tag on $Repo..."

# Create release
$releaseBody = @{
    tag_name = $Tag
    name = "Windows Installer v1.12.0"
    body = @"
## Open Notebook - Windows Installer

### What's New
- Auto-detect tool paths (uv, surreal, npm, Edge) - works on any machine
- Russian UI installer
- Desktop shortcut + Start Menu group

### Installation
1. Download ``OpenNotebook-Setup-1.12.0.exe``
2. Run it, follow the wizard
3. Launch via "Open Notebook" desktop shortcut

### Requirements
- Windows 10/11 (x64)
- Internet (for Python/Node setup on first run)
"@
    draft = $false
    prerelease = $false
} | ConvertTo-Json

$headers = @{
    "Authorization" = "token $Token"
    "Accept" = "application/vnd.github.v3+json"
}

$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -Method Post -Headers $headers -Body $releaseBody
Write-Host "Release created: $($release.html_url)"

# Upload asset
Write-Host "Uploading installer..."
$uploadHeaders = @{
    "Authorization" = "token $Token"
    "Content-Type" = "application/octet-stream"
}
$uploadUrl = "$($release.upload_url)?name=OpenNotebook-Setup-1.12.0.exe"
Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $uploadHeaders -InFile $Installer

Write-Host "Done! Release: $($release.html_url)"
