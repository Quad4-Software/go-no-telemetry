; Inno Setup script for go-no-telemtry offline kit.
; Build with: scripts/build-windows-installer.ps1 -KitDir path\to\extracted-kit

#ifndef KitDir
  #define KitDir "..\offline-kit-staging"
#endif

#ifndef KitTag
  #define KitTag "dev"
#endif

[Setup]
AppId={{A7B3C9D1-4E2F-4A8B-9C1D-2E3F4A5B6C7D}
AppName=go-no-telemtry
AppVersion={#KitTag}
AppVerName=go-no-telemtry {#KitTag}
DefaultDirName={autopf}\go-no-telemtry-offline
DefaultGroupName=go-no-telemtry
DisableProgramGroupPage=yes
OutputBaseFilename=go-no-telemtry-setup-{#KitTag}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut to Setup wizard"; GroupDescription: "Additional shortcuts:"; Flags: unchecked
Name: "addpath"; Description: "Add go to user PATH after install (via wizard)"; GroupDescription: "Options:"; Flags: checkedonce

[Files]
Source: "{#KitDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\go-no-telemtry Setup"; Filename: "{app}\Setup.bat"; WorkingDir: "{app}"
Name: "{autodesktop}\go-no-telemtry Setup"; Filename: "{app}\Setup.bat"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\Setup.bat"; Description: "Launch setup wizard"; Flags: postinstall nowait skipifsilent

[Messages]
WelcomeLabel2=This will install the go-no-telemtry offline kit on your computer.%n%nNo network connection is required.%n%nAfter files are copied, the setup wizard will guide you through installing Go without telemetry.
