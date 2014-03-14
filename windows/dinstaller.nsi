; Release Manager:
; Please use the special build of NSIS that supports large strings.
; Updating the PATH will often not work or work incorrectly with the
; regular build of NSIS.
;
; http://nsis.sourceforge.net/Special_Builds

;--------------------------------------------------------
; Defines
;--------------------------------------------------------

; Installer Type
; --------------

; Download zip from website. Comment out to embed zip instead (be sure to set
; paths below).
!define Download


; Versions
; --------

; D2
; The version will be pulled from the VERSION file in the dmd
; repository. Change the path to match.
!define D2VersionPath "..\..\dmd\VERSION"
!define /file Version2 ${D2VersionPath}

; or manually the verison manually:
;!define Version2 "2.065"

!define Version2ReleaseYear "2014" ; S3 file hosting includes the year in the URL so update this as needed


; D1
!define Version1 "1.076"
!define Version1ReleaseYear "2013" ; S3 file hosting includes the year in the URL so update this as needed


; DMC
!define VersionDMC "857"


; Extras
!define VersionCurl "7.34.0"
!define VersionVisualD "0.3.37"



; URLS
; ----

!define BaseURL "http://downloads.dlang.org"
!define BaseURLAlt "http://ftp.digitalmars.com"
!define VisualDBaseURL "https://github.com/D-Programming-Language/visuald/releases/download"


; The URLs to the release zips (used when Download is defined)
!define DownloadDmd1ZipUrl "${BaseURL}/releases/${Version1ReleaseYear}/dmd.${Version1}.zip"
!define DownloadDmd2ZipUrl "${BaseURL}/releases/${Version2ReleaseYear}/dmd.${Version2}.zip"
!define DownloadDmd2ZipUrlAlt "${BaseURLAlt}/dmd.${Version2}.zip"
!define DownloadDmcZipUrl  "${BaseURL}/other/dm${VersionDMC}c.zip"
!define DownloadCurlZipUrl "${BaseURL}/other/libcurl-${VersionCurl}-WinSSL-zlib-x86-x64.zip"
!define DownloadVisualDUrl "${VisualDBaseURL}/v${VersionVisualD}/VisualD-v${VersionVisualD}.exe"

; The paths to the release zips (used when Download isn't defined)
!define DmdZipPath1 "dmd.${Version1}.zip"
!define DmdZipPath2 "dmd.${Version2}.zip"
!define DmcZipPath "dm${VersionDMC}c.zip"
!define CurlZipPath "libcurl-${VersionCurl}-WinSSL-zlib-x86-x64.zip"
!define VisualDPath "VisualD-v${VersionVisualD}.exe"



;--------------------------------------------------------
; Includes
;--------------------------------------------------------

!include "MUI.nsh"
!include "EnvVarUpdate.nsh"
!include "ReplaceInFile.nsh"


;--------------------------------------------------------
; General definitions
;--------------------------------------------------------

; Name of the installer
Name "D Programming Language"

; Name of the output file of the installer
OutFile "dmd-${Version2}.exe"

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
; Language selection dialog settings
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


; Reserve files needed by the installation
!insertmacro MUI_RESERVEFILE_LANGDLL


;--------------------------------------------------------
; Sections
;--------------------------------------------------------

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
        Pop $R0
        StrCmp $R0 "OK" done
        inetc::get /caption "Downloading dmd.${Version2}.zip..." /popup "" "${DownloadDmd2ZipUrlAlt}" "$INSTDIR\dmd2.zip" /end
        Pop $R0
        StrCmp $R0 "OK" done
        MessageBox MB_OK|MB_ICONSTOP "Failed to download dmd.${Version2}.zip"
        done:
    !else
        FILE "/oname=$INSTDIR\dmd2.zip" "${DmdZipPath2}"
    !endif

    ; Unzip them right there
    nsisunz::Unzip "$INSTDIR\dmd2.zip" "$INSTDIR"

    ; Delete the zip files
    Delete "$INSTDIR\dmd2.zip"

    ; Create 32-bit command line batch file
    FileOpen $0 "$INSTDIR\dmd2vars32.bat" w
    FileWrite $0 "@echo.$\n"
    FileWrite $0 "@echo Setting up 32-bit environment for using DMD 2 from %~dp0dmd2\windows\bin.$\n"
    FileWrite $0 "@set PATH=%~dp0dmd2\windows\bin;%PATH%$\n"
    FileClose $0

    ; Create 64-bit command line batch file
    FileOpen $0 "$INSTDIR\dmd2vars64.bat" w
    FileWrite $0 "@echo.$\n"
    FileWrite $0 "@echo Setting up 64-bit environment for using DMD 2 from %~dp0dmd2\windows\bin.$\n"
    FileWrite $0 "@echo.$\n"
    FileWrite $0 "@echo dmd must still be called with -m64 in order to generate 64-bit code.$\n"
    FileWrite $0 "@echo This command prompt adds the path of extra 64-bit DLLs so generated programs$\n"
    FileWrite $0 "@echo which use the extra DLLs (notably libcurl) can be executed.$\n"
    FileWrite $0 "@set PATH=%~dp0dmd2\windows\bin;%PATH%$\n"
    FileWrite $0 "@set PATH=%~dp0dmd2\windows\bin64;%PATH%$\n"
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


Section "Detect MSVC" DetectMSVC
    ClearErrors

    ReadRegStr $0 HKLM "Software\Microsoft\VisualStudio\12.0\Setup\VC" "ProductDir"
    StrCpy $1 ";VC2013 "
    IfErrors 0 write_vc_path
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\VisualStudio\11.0\Setup\VC" "ProductDir"
    StrCpy $1 ";VC2012 "
    IfErrors 0 write_vc_path
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\VisualStudio\10.0\Setup\VC" "ProductDir"
    StrCpy $1 ";VC2010 "
    IfErrors 0 write_vc_path
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\VisualStudio\9.0\Setup\VC" "ProductDir"
    StrCpy $1 ";VC2008 "
    IfErrors no_vc_detected write_vc_path

    write_vc_path:
    !insertmacro _ReplaceInFile "$INSTDIR\dmd2\windows\bin\sc.ini" ";VCINSTALLDIR=" "VCINSTALLDIR=$0"
    !insertmacro _ReplaceInFile "$INSTDIR\dmd2\windows\bin\sc.ini" "$1" ""
    goto finish_vc_path

    no_vc_detected:
    MessageBox MB_OK "Could not detect Visual Studio (2008-2013 are supported). Using defaults."


    finish_vc_path:
    ClearErrors

    ReadRegStr $0 HKLM "Software\Microsoft\Windows Kits\Installed Roots" "KitsRoot81"
    IfErrors 0 write_sdk_path
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\Windows Kits\Installed Roots" "KitsRoot" ; 8.0
    IfErrors 0 write_sdk_path
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\Microsoft SDKs\Windows\v7.1A" "InstallationFolder"
    IfErrors 0 write_sdk_path
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\Microsoft SDKs\Windows\v7.0A" "InstallationFolder"
    IfErrors 0 write_sdk_path
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\Microsoft SDKs\Windows\v6.0A" "InstallationFolder"
    IfErrors no_sdk_detected write_sdk_path

    write_sdk_path:
    !insertmacro _ReplaceInFile "$INSTDIR\dmd2\windows\bin\sc.ini" ";WindowsSdkDir=" "WindowsSdkDir=$0"
    goto finish_sdk_path

    no_sdk_detected:
    MessageBox MB_OK "Could not detect Windows SDK (6.0A-8.1 are supported). Using defaults."


    finish_sdk_path:
    ClearErrors

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
        inetc::get /caption "Downloading dm${VersionDMC}c.zip..." /popup "" "${DownloadDmcZipUrl}" "$INSTDIR\dmc.zip" /end
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
    IntCmp $0 ${SF_SELECTED} +1 +4
        CreateShortCut "$SMPROGRAMS\D\D2 HTML Documentation.lnk" "$INSTDIR\dmd2\html\d\index.html"
        CreateShortCut "$SMPROGRAMS\D\D2 Documentation.lnk" "$INSTDIR\dmd2\windows\bin\d.chm"
        CreateShortCut "$SMPROGRAMS\D\D2 32-bit Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmd2vars32.bat""' "" "" SW_SHOWNORMAL "" "Open D2 32-bit Command Prompt"
        CreateShortCut "$SMPROGRAMS\D\D2 64-bit Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmd2vars64.bat""' "" "" SW_SHOWNORMAL "" "Open D2 64-bit Command Prompt"

    ; install dmd 1 documentation and command prompt
    SectionGetFlags ${Dmd1Files} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +3
        CreateShortCut "$SMPROGRAMS\D\D1 HTML Documentation.lnk" "$INSTDIR\dmd\html\d\index.html"
        CreateShortCut "$SMPROGRAMS\D\D1 Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmd1vars.bat""' "" "" SW_SHOWNORMAL "" "Open D1 Command Prompt"

    ; install dmc command prompt
    SectionGetFlags ${DmcFiles} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +2
        CreateShortCut "$SMPROGRAMS\D\dmc Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmcvars.bat""' "" "" SW_SHOWNORMAL "" "Open dmc Command Prompt"


    CreateShortCut "$SMPROGRAMS\D\$(SHORTCUT_Uninstall).lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
SectionEnd



Section "Visual D" VisualD

    SetOutPath $INSTDIR

    !ifdef Download
        ; Download the zip files
        inetc::get /caption "Downloading VisualD-v${VersionVisualD}.exe..." /popup "" "${DownloadVisualDUrl}" "$INSTDIR\${VisualDPath}" /end
        Pop $0 # return value = exit code, "OK" means OK
    !else
        FILE "/oname=$INSTDIR\${VisualDPath}" "${VisualDPath}"
    !endif

    DetailPrint "Running Visual D installer"
    ExecWait "$INSTDIR\${VisualDPath}"

    Delete "$INSTDIR\${VisualDPath}"

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

    Delete $INSTDIR\dmcvars.bat
    Delete $INSTDIR\dmd1vars.bat
    Delete $INSTDIR\dmd2vars.bat
    Delete $INSTDIR\dmd2vars32.bat
    Delete $INSTDIR\dmd2vars64.bat
    Delete $INSTDIR\README.txt

    ; Remove shortcuts
    Delete "$SMPROGRAMS\D\D1 HTML Documentation.lnk"
    Delete "$SMPROGRAMS\D\D2 HTML Documentation.lnk"
    Delete "$SMPROGRAMS\D\D2 Documentation.lnk"
    Delete "$SMPROGRAMS\D\$(SHORTCUT_Uninstall).lnk"

    ; Remove used directories
    RMDir /r /REBOOTOK "$INSTDIR\dm"
    RMDir /r /REBOOTOK "$INSTDIR\dmd"
    RMDir /r /REBOOTOK "$INSTDIR\dmd2"
    RMDir /REBOOTOK "$INSTDIR"
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
