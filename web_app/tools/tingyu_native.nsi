Unicode true
!include "MUI2.nsh"
Name "听隅"
OutFile "..\dist\native\windows\Tingyu-v2.0.0-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Tingyu"
InstallDirRegKey HKCU "Software\Tingyu" "InstallDir"
RequestExecutionLevel user
Icon "..\packaging\resources\icon.ico"
UninstallIcon "..\packaging\resources\icon.ico"
VIProductVersion "2.0.0.0"
VIAddVersionKey "ProductName" "Tingyu"
VIAddVersionKey "FileDescription" "Tingyu - Quiet Nook"
VIAddVersionKey "FileVersion" "2.0.0"
VIAddVersionKey "LegalCopyright" "Copyright (C) 2026 Citro"
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
Section "Install"
  SetOutPath "$INSTDIR"
  File /r "..\build\windows\x64\runner\Release\*.*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\听隅.lnk" "$INSTDIR\tingyu.exe"
  CreateShortcut "$SMPROGRAMS\听隅.lnk" "$INSTDIR\tingyu.exe"
  WriteRegStr HKCU "Software\Tingyu" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tingyu" "DisplayName" "听隅"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tingyu" "DisplayVersion" "2.0.0"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tingyu" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tingyu" "Publisher" "Citro"
SectionEnd
Section "Uninstall"
  Delete "$DESKTOP\听隅.lnk"
  Delete "$SMPROGRAMS\听隅.lnk"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\Tingyu"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tingyu"
SectionEnd
