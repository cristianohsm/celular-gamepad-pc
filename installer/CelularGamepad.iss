#ifndef StagingDir
  #error StagingDir must be supplied by build_installer.ps1
#endif
#ifndef OutputDir
  #error OutputDir must be supplied by build_installer.ps1
#endif

#define AppVersion "1.4.0-beta.2"
#define AppGuid "{8C41B45B-1E31-4B85-93F8-E829A1A2DC42}"

[Setup]
AppId={{#AppGuid}
AppName=Celular Gamepad para PC
AppVersion={#AppVersion}
AppVerName=Celular Gamepad para PC v{#AppVersion}
AppPublisher=Celular Gamepad Project
AppPublisherURL=https://github.com/cristianohsm/celular-gamepad-pc
AppSupportURL=https://github.com/cristianohsm/celular-gamepad-pc/issues
AppUpdatesURL=https://github.com/cristianohsm/celular-gamepad-pc/releases
DefaultDirName={autopf}\Celular Gamepad
DefaultGroupName=Celular Gamepad
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=CelularGamepad-Setup-v{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
SetupLogging=yes
CloseApplications=yes
RestartApplications=no
UsedUserAreasWarning=no
UninstallDisplayName=Celular Gamepad para PC
VersionInfoVersion=1.4.0.2
VersionInfoDescription=Celular Gamepad para PC - instalador experimental
VersionInfoCompany=Celular Gamepad Project
VersionInfoCopyright=Copyright (c) 2026 Celular Gamepad contributors

[Types]
Name: "full"; Description: "Instalação padrão (Emuladores e Jogos de PC)"
Name: "emulators"; Description: "Somente Emuladores"
Name: "custom"; Description: "Personalizada"; Flags: iscustom

[Components]
Name: "core"; Description: "Modo Emuladores, runtime portátil e documentação"; Types: full emulators custom; Flags: fixed
Name: "xinput"; Description: "Modo Jogos de PC (HIDMaestro v1.3.17)"; Types: full

[Tasks]
Name: "desktopemulators"; Description: "Criar atalho Emuladores na Área de Trabalho"; GroupDescription: "Atalhos opcionais:"
Name: "desktopxinput"; Description: "Criar atalho Jogos de PC na Área de Trabalho"; GroupDescription: "Atalhos opcionais:"; Components: xinput
Name: "startupemulators"; Description: "Iniciar com o Windows no modo Emuladores"; GroupDescription: "Inicialização:"; Flags: unchecked

[Files]
Source: "{#StagingDir}\*"; DestDir: "{app}"; Excludes: "bridge,bridge\*"; Flags: ignoreversion recursesubdirs; Components: core
Source: "{#StagingDir}\bridge\*"; DestDir: "{app}\bridge"; Flags: ignoreversion recursesubdirs createallsubdirs; Components: xinput

[Icons]
Name: "{group}\Celular Gamepad — Emuladores"; Filename: "{app}\scripts\launch_emulators.cmd"; WorkingDir: "{app}"
Name: "{group}\Celular Gamepad — Jogos de PC"; Filename: "{app}\scripts\launch_xinput.cmd"; WorkingDir: "{app}"; Components: xinput
Name: "{group}\Testar controles virtuais"; Filename: "{app}\scripts\test_controllers.cmd"; WorkingDir: "{app}"; Components: xinput
Name: "{group}\Verificar instalação"; Filename: "{app}\scripts\verify_installation.cmd"; WorkingDir: "{app}"
Name: "{group}\Documentação"; Filename: "{app}\docs\INSTALACAO_WINDOWS.md"
Name: "{group}\Desinstalar Celular Gamepad"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Celular Gamepad — Emuladores"; Filename: "{app}\scripts\launch_emulators.cmd"; WorkingDir: "{app}"; Tasks: desktopemulators
Name: "{autodesktop}\Celular Gamepad — Jogos de PC"; Filename: "{app}\scripts\launch_xinput.cmd"; WorkingDir: "{app}"; Tasks: desktopxinput; Components: xinput
Name: "{userstartup}\Celular Gamepad — Emuladores"; Filename: "{app}\scripts\launch_emulators.cmd"; WorkingDir: "{app}"; Tasks: startupemulators

[Run]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Celular Gamepad — Rede Local"""; Flags: runhidden waituntilterminated
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Celular Gamepad — Rede Local"" dir=in action=allow protocol=TCP localport=8765 profile=private program=""{app}\runtime\python.exe"" enable=yes"; Flags: runhidden waituntilterminated
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\install_hidmaestro.ps1"" -AppRoot ""{app}"""; Flags: runhidden waituntilterminated; Components: xinput

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\scripts\uninstall_cleanup.ps1"" -AppRoot ""{app}"""; Flags: runhidden waituntilterminated; RunOnceId: "CleanupProcesses"
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Celular Gamepad — Rede Local"""; Flags: runhidden waituntilterminated; RunOnceId: "RemoveFirewall"

[Code]
function InstalledBetaNumber(): Integer;
var
  InstalledVersion: String;
  Marker: Integer;
begin
  Result := 0;
  if RegQueryStringValue(HKLM64,
    'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppGuid}_is1',
    'DisplayVersion', InstalledVersion) then
  begin
    Marker := Pos('-beta.', InstalledVersion);
    if Marker > 0 then
      Result := StrToIntDef(Copy(InstalledVersion, Marker + 6, 8), 0);
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  if InstalledBetaNumber() > 2 then
  begin
    MsgBox('Uma beta mais recente já está instalada. O downgrade silencioso foi bloqueado.', mbError, MB_OK);
    Result := False;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    if not UninstallSilent then
    begin
      MsgBox('O componente HIDMaestro pode ser utilizado por outros programas e será preservado.', mbInformation, MB_OK);
      if MsgBox('Deseja remover separadamente os pacotes de driver HIDMaestro? Esta ação exige confirmação e pode afetar outros programas.', mbConfirmation, MB_YESNO) = IDYES then
        Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'),
          '-NoProfile -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\scripts\remove_hidmaestro.ps1') + '" -Confirmed',
          '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;
  end;
end;
