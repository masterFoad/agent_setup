; FOAD Dev Setup Windows Installer
; Build with Inno Setup on Windows:
;   iscc packaging\windows\foad-dev-setup.iss
;
; This EXE is a bootstrapper. It runs install-windows.ps1, which installs
; Git, Node.js/npm, Google Antigravity IDE, Claude Code, and starter files.

#define MyAppName "FOAD Dev Setup"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "FOAD"
#define MyAppURL "https://github.com/masterFoad/agent_setup"

[Setup]
AppId={{9E7D978D-8D35-4B40-9F39-80D8C27DBB21}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\FOAD Dev Setup
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=admin
OutputDir=..\..\dist\windows
OutputBaseFilename=FOAD-Dev-Setup-Windows
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
Uninstallable=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\..\install-windows.ps1"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "..\..\README.md"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{tmp}\install-windows.ps1"""; StatusMsg: "Installing FOAD development tools..."; Flags: waituntilterminated

[Code]
function InitializeSetup(): Boolean;
begin
  MsgBox(
    'FOAD Dev Setup will install Git, Node.js/npm, Google Antigravity IDE, Claude Code, and beginner setup files.' + #13#10#13#10 +
    'Windows may ask for permission during installation. After setup, close and reopen PowerShell, then run: claude',
    mbInformation,
    MB_OK
  );
  Result := True;
end;
