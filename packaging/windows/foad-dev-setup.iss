; FOAD Dev Setup Windows Installer
; Build with Inno Setup on Windows:
;   iscc packaging\windows\foad-dev-setup.iss
;
; This EXE is a bootstrapper. It runs install-windows.ps1, which installs
; Git, Node.js/npm, Google Antigravity IDE, Claude Code, and starter files.

#define MyAppName "FOAD Dev Setup"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif
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
PrivilegesRequired=lowest
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

[Code]
function InitializeSetup(): Boolean;
begin
  MsgBox(
    'FOAD Dev Setup will install Git, Node.js/npm, Python, Google Antigravity IDE, Claude Code, and beginner setup files.' + #13#10#13#10 +
    'Allow 10-25 minutes and several gigabytes of disk space.' + #13#10 +
    'Individual package installers may request administrator permission.' + #13#10 +
    'Claude Code requires an eligible subscription, Console account, or supported provider.' + #13#10 +
    'Antigravity IDE sign-in may require a Google account.' + #13#10 +
    'WSL is not required; skip WSL prompts and use the PowerShell terminal profile.' + #13#10 +
    'The setup creates files under your .claude folder and Desktop and saves a setup log.' + #13#10#13#10 +
    'After setup, close and reopen PowerShell, then run: claude',
    mbInformation,
    MB_OK
  );
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    if not Exec(
      ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
      '-NoProfile -ExecutionPolicy Bypass -File "' +
        ExpandConstant('{tmp}\install-windows.ps1') + '" -AssumeYes',
      '', SW_SHOW, ewWaitUntilTerminated, ResultCode
    ) then
      RaiseException('Could not start the FOAD PowerShell setup.');

    if ResultCode <> 0 then
      RaiseException(
        'FOAD setup did not complete. Review FOAD-setup-log.txt on your Desktop, ' +
        'fix the reported item, and run the installer again.'
      );
  end;
end;
