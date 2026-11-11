#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif

[Setup]
AppId={{C4030F88-2B13-4D6D-B6F5-5873AC943B87}
AppName=Schattenbund
AppVersion={#MyAppVersion}
AppPublisher=PeHAB
DefaultDirName={autopf}\Schattenbund
DefaultGroupName=Schattenbund
DisableProgramGroupPage=yes
OutputDir=..\build
OutputBaseFilename=Schattenbund-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\Schattenbund.exe

[Languages]
Name: "german"; MessagesFile: "compiler:Languages\German.isl"

[Tasks]
Name: "desktopicon"; Description: "Desktop-Verknüpfung erstellen"; GroupDescription: "Zusätzliche Symbole:"; Flags: unchecked

[Files]
Source: "..\build\Schattenbund.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Schattenbund"; Filename: "{app}\Schattenbund.exe"
Name: "{autodesktop}\Schattenbund"; Filename: "{app}\Schattenbund.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Schattenbund.exe"; Description: "Schattenbund starten"; Flags: postinstall nowait skipifsilent
