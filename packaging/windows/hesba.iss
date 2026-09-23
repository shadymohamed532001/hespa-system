#define MyAppName "Hesba"
#ifndef MyAppVersion
  #define MyAppVersion "1.1.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\frontend\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{F41B5A33-0A3F-4D57-9CCB-A2C19322E95B}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\Hesba
DefaultGroupName=Hesba
OutputDir=..\..\artifacts
OutputBaseFilename=Hesba-{#MyAppVersion}-windows-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
WizardStyle=modern

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Hesba"; Filename: "{app}\hesba_desktop.exe"
Name: "{autodesktop}\Hesba"; Filename: "{app}\hesba_desktop.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"

[Run]
Filename: "{app}\hesba_desktop.exe"; Description: "Launch Hesba"; Flags: nowait postinstall skipifsilent
