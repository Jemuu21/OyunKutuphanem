; Oyun Kütüphanem kurulum betiği (Inno Setup 6)
; setup_yap.bat bu dosyayı kendisi derler, elle açmana gerek yok.

#define AppName "Oyun Kütüphanem"
; Sürüm SURUM.txt dosyasından gelir (setup_yap.bat /DAppVersion=... ile verir)
#ifndef AppVersion
  #define AppVersion "0.0"
#endif
#define AppExe "OyunKutuphanem.exe"

[Setup]
AppId={{987FED47-89D0-4F81-8B4C-B67858E97FCA}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Cem
; Sadece bu kullanıcı için kurulur, yönetici izni istemez
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\OyunKutuphanem
DisableProgramGroupPage=yes
DisableDirPage=auto
OutputDir=.
OutputBaseFilename=OyunKutuphanemKurulum
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Program açıksa kurulum ve kaldırma uyarır
AppMutex=OyunKutuphanem-Calisiyor
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstüne kısayol koy"; GroupDescription: "Kısayollar:"
Name: "autostart"; Description: "Windows açılınca başlat (pencere açmadan, saatin yanında)"; GroupDescription: "Başlangıç:"; Flags: unchecked

[InstallDelete]
; Güncellemede eski sürümün dosyaları karışmasın
Type: filesandordirs; Name: "{app}\_internal"

[Files]
Source: "dist\OyunKutuphanem\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "OyunKutuphanem"; ValueData: """{app}\{#AppExe}"" --tray"; Tasks: autostart

[Run]
Filename: "{app}\{#AppExe}"; Description: "{#AppName} şimdi açılsın"; Flags: nowait postinstall skipifsilent
; Program kendini güncellediğinde (sessiz kurulum) bittikten sonra yeniden açılsın
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: WizardSilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    { Program ayarlardan açtıysa bile "Windows açılınca başlat" kaydını temizle }
    RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', 'OyunKutuphanem');
    if not UninstallSilent then
      if MsgBox('Ayarların, favorilerin ve oynama sürelerin de silinsin mi?' + #13#10#13#10 +
                'Hayır dersen programı tekrar kurduğunda kaldığın yerden devam edersin.' + #13#10 +
                '(Epic hesabının girişi ve indirdiğin oyunlar her iki durumda da silinmez.)',
                mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
      begin
        DelTree(ExpandConstant('{userappdata}\OyunKutuphanem'), True, True, True);
        DelTree(ExpandConstant('{localappdata}\OyunKutuphanem'), True, True, True);
      end;
  end;
end;
