;--------------------------------------------------------
; Defines
;--------------------------------------------------------

; Version
;!define Version1 "1.046"
;!define Version2 "2.031"
!define VersionCurl "7.24.0"

; Download zip from website, or include the compressed zip?
!define Download

; If Download, the urls of the dmd.zip and dmc.zip
!define DownloadDmd1ZipUrl "http://ftp.digitalmars.com/dmd.${Version1}.zip"
;!define DownloadDmd2ZipUrl "https://github.com/downloads/D-Programming-Language/dmd/dmd.${Version2}.zip"
!define DownloadDmd2ZipUrl "http://ftp.digitalmars.com/dmd.${Version2}.zip"
!define DownloadDmcZipUrl "http://ftp.digitalmars.com/dmc.zip"
!define DownloadCurlZipUrl "https://github.com/downloads/D-Programming-Language/dmd/curl-${VersionCurl}-dmd-win32.zip"

; If not Download, the paths of dmd.zip and dmc.zip
!define DmdZipPath1 "dmd.${Version1}.zip"
!define DmdZipPath2 "dmd.${Version2}.zip"
!define DmcZipPath "dmc.zip"
!define CurlZipPath "curl-${VersionCurl}-dmd-win32.zip"

;--------------------------------------------------------
; Includes
;--------------------------------------------------------

!include "MUI.nsh"
!include "EnvVarUpdate.nsh"

;--------------------------------------------------------
; General definitions
;--------------------------------------------------------

; Name of the installer
Name "D Programming Language"

; Name of the output file of the installer
OutFile "dinstaller.exe"

; Where the program will be installed
InstallDir "C:\D"

; Take the instalation directory from the registry, if possible
InstallDirRegKey HKCU "Software\D" ""

; This is so no one can corrupt the installer
CRCCheck force

;--------------------------------------------------------
; Interface settings
;--------------------------------------------------------

; Confirmation when exiting the installer
!define MUI_ABORTWARNING

!define MUI_ICON "installer-icon.ico"
!define MUI_UNICON "uninstaller-icon.ico"

;--------------------------------------------------------
; Langauge selection dialog settings
;--------------------------------------------------------

; Remember the installation language
!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"
!define MUI_LANGDLL_REGISTRY_KEY "Software\D"
!define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"

;--------------------------------------------------------
; Installer pages
;--------------------------------------------------------

!define MUI_WELCOMEFINISHPAGE_BITMAP "installer_image.bmp"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

;--------------------------------------------------------
; The languages
;--------------------------------------------------------

!insertmacro MUI_LANGUAGE "English"
;!insertmacro MUI_LANGUAGE "Spanish"

;--------------------------------------------------------
; Reserve files needed by the installation
;--------------------------------------------------------

!insertmacro MUI_RESERVEFILE_LANGDLL

;--------------------------------------------------------
; Required section: main program files,
; registry entries, etc.
;--------------------------------------------------------
;
SectionGroup /e "D2"

Section "-D2" Dmd2Files

    ; This section is mandatory
    ;SectionIn RO
    
    SetOutPath $INSTDIR
    
    ; Create installation directory
    CreateDirectory "$INSTDIR"
    
    !ifdef Download
        ; Download the zip files
        inetc::get /caption "Downloading dmd.${Version2}.zip..." /popup "" "${DownloadDmd2ZipUrl}" "$INSTDIR\dmd2.zip" /end
        Pop $0 # return value = exit code, "OK" means OK
    !else
        FILE "/oname=$INSTDIR\dmd2.zip" "${DmdZipPath2}"
    !endif
    
    ; Unzip them right there
    nsisunz::Unzip "$INSTDIR\dmd2.zip" "$INSTDIR"
    
    ; Delete the zip files
    Delete "$INSTDIR\dmd2.zip"

    ; Create command line batch file
    FileOpen $0 "$INSTDIR\dmd2vars.bat" w
    FileWrite $0 "@echo.$\n"
    FileWrite $0 "@echo Setting up environment for using DMD 2 from %~dp0dmd2\windows\bin.$\n"
    FileWrite $0 "@set PATH=%~dp0dmd2\windows\bin;%PATH%$\n"
    FileClose $0

    ; Write installation dir in the registry
    WriteRegStr HKLM SOFTWARE\D "Install_Dir" "$INSTDIR"

    ; Write registry keys to make uninstall from Windows
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "DisplayName" "D"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "NoRepair" 1
    WriteUninstaller "uninstall.exe"

SectionEnd

Section "cURL support" cURLFiles

    ; This section is mandatory
    ;SectionIn RO
    
    SetOutPath $INSTDIR
    
    ; Create installation directory
    CreateDirectory "$INSTDIR"
    
    !ifdef Download
        ; Download the zip files
        inetc::get /caption "Downloading ${CurlZipPath}..." /popup "" "${DownloadCurlZipUrl}" "$INSTDIR\curl.zip" /end
        Pop $0 # return value = exit code, "OK" means OK
    !else
        FILE "/oname=$INSTDIR\curl.zip" "${CurlZipPath}"
    !endif
    
    ; Unzip them right there
    nsisunz::Unzip "$INSTDIR\curl.zip" "$INSTDIR"
    
    ; Delete the zip files
    Delete "$INSTDIR\curl.zip"

SectionEnd

Section "Add to PATH" AddD2ToPath

    ; Add dmd 2 directories to path (for all users)
    SectionGetFlags ${Dmd2Files} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +2
        ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\dmd2\windows\bin"

SectionEnd

SectionGroupEnd


SectionGroup "D1"

Section /o "-D1" Dmd1Files

    ; This section is mandatory
    ;SectionIn RO
    
    SetOutPath $INSTDIR
    
    ; Create installation directory
    CreateDirectory "$INSTDIR"
    
    !ifdef Download
        ; Download the zip files
        inetc::get /caption "Downloading dmd.${Version1}.zip..." /popup "" "${DownloadDmd1ZipUrl}" "$INSTDIR\dmd.zip" /end
        Pop $0 # return value = exit code, "OK" means OK
    !else
        FILE "/oname=$INSTDIR\dmd.zip" "${DmdZipPath1}"
    !endif
    
    ; Unzip them right there
    nsisunz::Unzip "$INSTDIR\dmd.zip" "$INSTDIR"
    
    ; Delete the zip files
    Delete "$INSTDIR\dmd.zip"

    ; Create command line batch file
    FileOpen $0 "$INSTDIR\dmd1vars.bat" w
    FileWrite $0 "@echo.$\n"
    FileWrite $0 "@echo Setting up environment for using DMD 1 from %~dp0dmd\windows\bin.$\n"
    FileWrite $0 "@set PATH=%~dp0dmd\windows\bin;%PATH%$\n"
    FileClose $0

    ; Write installation dir in the registry
    WriteRegStr HKLM SOFTWARE\D "Install_Dir" "$INSTDIR"

    ; Write registry keys to make uninstall from Windows
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "DisplayName" "D"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "NoRepair" 1
    WriteUninstaller "uninstall.exe"

SectionEnd

Section /o "Add to PATH" AddD1ToPath

    ; Add dmd 1 directories to path (for all users)
    SectionGetFlags ${Dmd1Files} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +2
        ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\dmd\windows\bin"

SectionEnd

SectionGroupEnd

SectionGroup "dmc"

Section "-dmc" DmcFiles

    ; This section is mandatory
    ;SectionIn RO
    
    SetOutPath $INSTDIR
    
    ; Create installation directory
    CreateDirectory "$INSTDIR"
    
    !ifdef Download
        ; Download the zip files
        inetc::get /caption "Downloading dmc.zip..." /popup "" "${DownloadDmcZipUrl}" "$INSTDIR\dmc.zip" /end
        Pop $0 # return value = exit code, "OK" means OK
    !else
        FILE "/oname=$INSTDIR\dmc.zip" "${DmcZipPath}"
    !endif
    
    ; Unzip them right there
    nsisunz::Unzip "$INSTDIR\dmc.zip" "$INSTDIR"
    
    ; Delete the zip files
    Delete "$INSTDIR\dmc.zip"
    
    ; Create command line batch file
    FileOpen $0 "$INSTDIR\dmcvars.bat" w
    FileWrite $0 "@echo.$\n"
    FileWrite $0 "@echo Setting up environment for using dmc from %~dp0dm\bin.$\n"
    FileWrite $0 "@set PATH=%~dp0dm\bin;%PATH%$\n"
    FileClose $0

    ; Write installation dir in the registry
    WriteRegStr HKLM SOFTWARE\D "Install_Dir" "$INSTDIR"

    ; Write registry keys to make uninstall from Windows
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "DisplayName" "D"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "NoRepair" 1
    WriteUninstaller "uninstall.exe"

SectionEnd

Section "Add to PATH" AddDmcToPath

    ; Add dmc directories to path (for all users)
    SectionGetFlags ${DmcFiles} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +2
        ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\dm\bin"

SectionEnd

SectionGroupEnd

Section "Start Menu Shortcuts" StartMenuShortcuts
    CreateDirectory "$SMPROGRAMS\D"

    ; install dmd 2 documentation and command prompt
    SectionGetFlags ${Dmd2Files} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +3
        CreateShortCut "$SMPROGRAMS\D\D2 Documentation.lnk" "$INSTDIR\dmd2\html\d\index.html" "" "$INSTDIR\dmd2\html\d\index.html" 0
        CreateShortCut "$SMPROGRAMS\D\D2 Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmd2vars.bat""' "" "" SW_SHOWNORMAL "" "Open D2 Command Prompt"

    ; install dmd 1 documentation and command prompt
    SectionGetFlags ${Dmd1Files} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +3
        CreateShortCut "$SMPROGRAMS\D\D1 Documentation.lnk" "$INSTDIR\dmd\html\d\index.html" "" "$INSTDIR\dmd\html\d\index.html" 0
        CreateShortCut "$SMPROGRAMS\D\D1 Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmd1vars.bat""' "" "" SW_SHOWNORMAL "" "Open D1 Command Prompt"

    ; install dmc command prompt
    SectionGetFlags ${DmcFiles} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +2
        CreateShortCut "$SMPROGRAMS\D\dmc Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmcvars.bat""' "" "" SW_SHOWNORMAL "" "Open dmc Command Prompt"


    CreateShortCut "$SMPROGRAMS\D\$(SHORTCUT_Uninstall).lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
SectionEnd

;--------------------------------------------------------
; Installer functions
;--------------------------------------------------------

Function .onInit
    ; This is commented because there's only one language
    ; (for now)
    ;!insertmacro MUI_LANGDLL_DISPLAY
FunctionEnd

; Contains descriptions of components and other stuff
!include dinstaller_descriptions.nsh

;--------------------------------------------------------
; Uninstaller
;--------------------------------------------------------

Section "Uninstall"

    ; Remove directories to path (for all users)
    ; (if for the current user, use HKCU)
    ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\dm\bin"
    ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\dmd\windows\bin"
    ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\dmd2\windows\bin"

    ; Remove stuff from registry
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D"
    DeleteRegKey HKLM SOFTWARE\D
    DeleteRegKey /ifempty HKLM SOFTWARE\D

    ; This is for deleting the remembered language of the installation
    DeleteRegKey HKCU Software\D
    DeleteRegKey /ifempty HKCU Software\D

    ; Remove the uninstaller
    Delete $INSTDIR\uninstall.exe
    
    ; Remove shortcuts
    Delete "$SMPROGRAMS\D\D1 Documentation.lnk"
    Delete "$SMPROGRAMS\D\D2 Documentation.lnk"
    Delete "$SMPROGRAMS\D\$(SHORTCUT_Uninstall).lnk"

    ; Remove used directories
    RMDir /r /REBOOTOK "$INSTDIR\dm"
    RMDir /r /REBOOTOK "$INSTDIR\dmd"
    RMDir /r /REBOOTOK "$INSTDIR\dmd2"
    RMDir /r /REBOOTOK "$INSTDIR"
    RMDir /r /REBOOTOK "$SMPROGRAMS\D"

SectionEnd

;--------------------------------------------------------
; Uninstaller functions
;--------------------------------------------------------

Function un.onInit
    ; Ask language before starting the uninstall

    ; This is commented because there's only one language
    ; (for now)
    ;!insertmacro MUI_UNGETLANGUAGE
FunctionEnd
