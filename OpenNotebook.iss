; Open Notebook Installer - Optimized
; Inno Setup 6 Script
; Includes ONLY runtime files (no dev, no node_modules, no data)

#define MyAppName "Open Notebook"
#define MyAppVersion "1.13.0"
#define MyAppExeName "OpenNotebook.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\OpenNotebook
DefaultGroupName={#MyAppName}
OutputDir=installer
OutputBaseFilename=OpenNotebook-Setup-{#MyAppVersion}
Compression=lzma2/normal
SolidCompression=no
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\OpenNotebook.exe

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; === Launcher ===
Source: "dist\OpenNotebook.exe"; DestDir: "{app}"; Flags: ignoreversion

; === Scripts ===
Source: "run.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "run-silent.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "run-silent.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "launch.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "stop-watcher.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: ".env.example"; DestDir: "{app}"; Flags: ignoreversion

; === Python packages (venv) ===
Source: ".venv\*"; DestDir: "{app}\.venv"; Flags: ignoreversion recursesubdirs createallsubdirs

; === Frontend: ONLY what's needed for standalone server ===
; --- .next/ build output (NO dev/, NO cache/) ---
Source: "frontend\.next\build\*"; DestDir: "{app}\frontend\.next\build"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "frontend\.next\server\*"; DestDir: "{app}\frontend\.next\server"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "frontend\.next\static\*"; DestDir: "{app}\frontend\.next\static"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "frontend\.next\standalone\*"; DestDir: "{app}\frontend\.next\standalone"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "frontend\.next\diagnostics\*"; DestDir: "{app}\frontend\.next\diagnostics"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "frontend\.next\types\*"; DestDir: "{app}\frontend\.next\types"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
; --- .next/ manifest files ---
Source: "frontend\.next\app-path-routes-manifest.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\build-manifest.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\BUILD_ID"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\export-marker.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\fallback-build-manifest.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\images-manifest.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\next-minimal-server.js.nft.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\next-server.js.nft.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\package.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\prerender-manifest.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\required-server-files.js"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\required-server-files.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
Source: "frontend\.next\routes-manifest.json"; DestDir: "{app}\frontend\.next"; Flags: ignoreversion
; --- start-server.js (entry point for standalone mode) ---
Source: "frontend\start-server.js"; DestDir: "{app}\frontend"; Flags: ignoreversion
; --- public/ (static assets) ---
Source: "frontend\public\*"; DestDir: "{app}\frontend\public"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; === Backend: Python source ===
Source: "open_notebook\*"; DestDir: "{app}\open_notebook"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "api\*"; DestDir: "{app}\api"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "commands\*"; DestDir: "{app}\commands"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "prompts\*"; DestDir: "{app}\prompts"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; === NOT included (and why) ===
; frontend/.next/dev/        - Turbopack dev cache (1069 MB) - not needed for production
; frontend/.next/cache/      - Build cache (0.3 MB) - not needed
; frontend/node_modules/     - npm packages (537 MB) - NOT needed when using standalone server
; frontend/src/              - TypeScript sources (1.8 MB) - compiled into .next/
; frontend/package.json      - npm config - not needed
; frontend/tsconfig.json     - TS config - not needed
; frontend/next.config.ts    - Next.js config - not needed (baked into server.js)
; frontend/AGENTS.md         - dev instructions
; frontend/CLAUDE.md         - dev instructions
; frontend/eslint.config.mjs - linter config
; frontend/postcss.config.mjs - CSS config
; frontend/vitest.config.ts  - test config
; frontend/next-env.d.ts     - TS declarations
; frontend/components.json   - UI config
; data/                      - Database files (7.3 MB) - user creates fresh
; .edge_profile/             - Browser profile (560 MB) - user creates fresh
; build/                     - PyInstaller builds (11 MB) - not needed
; installer/                 - Old installer files (203 MB) - not needed
; surreal_data/              - SurrealDB data (0.2 MB) - user creates fresh

[Dirs]
Name: "{app}\logs"; Flags: uninsalwaysuninstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{#MyAppName} (Console)"; Filename: "{app}\run.bat"; WorkingDir: "{app}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\run-silent.vbs"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if not FileExists(ExpandConstant('{app}\.env')) then
    begin
      CopyFile(ExpandConstant('{app}\.env.example'), ExpandConstant('{app}\.env'), False);
    end;
  end;
end;
