; Open Notebook - Inno Setup Installer
; Build: "C:\Program Files (x86)\Inno Setup 6\iscc.exe" "OpenNotebook.iss"

#define MyAppName "Open Notebook"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Open Notebook"
#define MyAppURL "https://github.com/Zxcvb2521/open-notebook"
#define ProjectRoot "F:\XTTS\zxcvb2521\Open_Notebook"
#define DistDir ProjectRoot + "\dist"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\OpenNotebook
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir={#ProjectRoot}
OutputBaseFilename=OpenNotebook-Setup
;SetupIconFile={#ProjectRoot}\icon.ico
Compression=lzma2/max
SolidCompression=yes
UninstallDisplayIcon={app}\OpenNotebook.exe
UninstallDisplayName={#MyAppName}

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Ярлыки:"

[Files]
Source: "{#DistDir}\OpenNotebook.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#DistDir}\run.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#DistDir}\start-all.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#DistDir}\install.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#DistDir}\uninstall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#DistDir}\desktop\app.py"; DestDir: "{app}\desktop"; Flags: ignoreversion
Source: "{#DistDir}\api\*"; DestDir: "{app}\api"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#DistDir}\open_notebook\*"; DestDir: "{app}\open_notebook"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#DistDir}\frontend\*"; DestDir: "{app}\frontend"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#DistDir}\prompts\*"; DestDir: "{app}\prompts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#DistDir}\.env.example"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#DistDir}\pyproject.toml"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\OpenNotebook.exe"; WorkingDir: "{app}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\OpenNotebook.exe"; WorkingDir: "{app}"; Tasks: desktopicon
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

[Run]
; Install Python dependencies
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Set-Location '{app}'; uv sync --no-progress"""; StatusMsg: "Установка Python-зависимостей..."; Flags: runhidden waituntilterminated
; Install Frontend dependencies
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Set-Location '{app}\frontend'; npm install --silent"""; StatusMsg: "Установка Frontend-зависимостей..."; Flags: runhidden waituntilterminated
; Create .env file
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""if(!(Test-Path '{app}\.env')){{Copy-Item '{app}\.env.example' '{app}\.env'; $k=-join((48..57)+(65..90)+(97..122)|Get-Random -Count 32|%{{[char]$_}}); (Get-Content '{app}\.env')-replace 'change-me',$k|Set-Content '{app}\.env'; (Get-Content '{app}\.env')-replace 'ws://surrealdb:8000/rpc','ws://localhost:8000/rpc'|Set-Content '{app}\.env'}}"""; StatusMsg: "Настройка конфигурации..."; Flags: runhidden waituntilterminated
; Check SurrealDB
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""if(!(Get-Command 'surreal'-ErrorAction SilentlyContinue)){{Write-Host 'SurrealDB not found. Install manually: iwr https://windows.surrealdb.com -useb | iex'}}"""; StatusMsg: "Проверка SurrealDB..."; Flags: runhidden waituntilterminated

; Launch app after install
Filename: "{app}\OpenNotebook.exe"; Description: "Запустить Open Notebook"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/im OpenNotebook.exe /f"; Flags: runhidden
Filename: "taskkill.exe"; Parameters: "/im surreal.exe /f"; Flags: runhidden
