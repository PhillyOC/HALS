; HALS Inno Setup installer
; Compiled by the GitHub release workflow (or local ISCC).

#define MyAppName "HALS"
#ifndef MyAppVersion
  #define MyAppVersion "1.0.7"
#endif
#define MyAppPublisher "HALS contributors"
#define MyAppURL "https://github.com/PhillyOC/HALS"
#define MyAppExeName "Start-HALS.cmd"
#define MyAppIcon "Assets\HALS.ico"

#ifndef SourceDir
  #define SourceDir "..\dist\HALS-1.0.7"
#endif

#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

[Setup]
AppId={{A7C2E5D1-4B8F-4F2A-9C1E-6D3B8A0F5E21}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={localappdata}\Programs\HALS
DefaultGroupName=HALS
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename=HALS-Setup-{#MyAppVersion}
SetupIconFile=..\Assets\HALS.ico
UninstallDisplayIcon={app}\{#MyAppIcon}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayName=HALS {#MyAppVersion}
InfoBeforeFile=
CloseApplications=force
RestartIfNeededByRun=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\HALS"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppIcon}"
Name: "{group}\Uninstall HALS"; Filename: "{uninstallexe}"; IconFilename: "{app}\{#MyAppIcon}"
Name: "{autodesktop}\HALS"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\{#MyAppIcon}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch HALS"; Flags: nowait postinstall skipifsilent unchecked

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    ForceDirectories(ExpandConstant('{app}\Secrets\OAuth'));
    ForceDirectories(ExpandConstant('{app}\Config'));
    ForceDirectories(ExpandConstant('{app}\Knowledge'));
    ForceDirectories(ExpandConstant('{app}\Snapshots'));
  end;
end;
