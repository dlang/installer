; Release Manager:
;
; Preliminary instructions
; ------------------------
;
; Please use the special build of NSIS that supports large strings.
; Updating the PATH will often not work or work incorrectly with the
; regular build of NSIS.
;
; http://nsis.sourceforge.net/Special_Builds
;
;
; Instructions
; ------------
;
; Two defines must be set to use the installer:
; - EmbedD2Dir: The path to the directory tree recursively embedded in the
;               generated installer.
; - Version2:   The DMD version number.
;
; The easiest way is to use the /D command line options for makensis
;   makensis /DEmbedD2Dir=<some path> /DVersion2=2.xxx
;
; The Extras that are downloaded should be updated to use the latest versions.

;--------------------------------------------------------
; Defines
;--------------------------------------------------------

; Required
; --------
; EmbedD2Dir. Can be specified here rather than on the makensis command line:
;!define EmbedD2Dir "<path to files to install>"

; Version2. Can be specified here rather than on the makensis command line:
;!define Version2 "2.0xx"


; Routinely Update
; ----------------
; Visual D
!define VersionVisualD "0.45.1"

; DMC
!define VersionDMC "857"

; D1
!define Version1 "1.076"
!define Version1ReleaseYear "2013" ; S3 file hosting includes the year in the URL so update this as needed


; Update Rarely Needed
; --------------------
; Files
!define VisualDFilename "VisualD-v${VersionVisualD}.exe"
!define DmcFilename "dmc-${VersionDMC}.exe"
!define Dmd1Filename "dmd-${Version1}.exe"
!define VS2013Filename "vs_community.exe"
!define VCRedistx86Filename "vcredist_x86.exe"
!define VCRedistx64Filename "vcredist_x64.exe"

; URLs
!define BaseURL "http://downloads.dlang.org"
!define BaseURLAlt "http://ftp.digitalmars.com"
!define VisualDBaseURL "https://github.com/dlang/visuald/releases/download"

!define VisualDUrl "${VisualDBaseURL}/v${VersionVisualD}/${VisualDFilename}"

!define DmcUrl  "${BaseURL}/other/${DmcFilename}"
!define DmcAltUrl "${BaseURLAlt}/${DmcFilename}"

!define Dmd1Url "${BaseURL}/releases/${Version1ReleaseYear}/${Dmd1Filename}"
!define Dmd1AltUrl "${BaseURLAlt}/${Dmd1Filename}"

!define VS2013Url "http://go.microsoft.com/fwlink/?LinkId=517284"

; see https://stackoverflow.com/questions/12206314/detect-if-visual-c-redistributable-for-visual-studio-2012-is-installed/14878248
; selecting VC2010
!define VCRedistx86Url "https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x86.exe"
!define VCRedistx64Url "https://download.microsoft.com/download/1/6/5/165255E7-1014-4D0A-B094-B6A430A6BFFC/vcredist_x64.exe"

!define VCRedistx86RegKey "SOFTWARE\Classes\Installer\Products\1926E8D15D0BCE53481466615F760A7F"
!define VCRedistx64RegKey "SOFTWARE\Classes\Installer\Products\1D5E3C0FEDA1E123187686FED06E995A"

; ----------------
; Publishing Details
!define DPublisher "Digital Mars"
!ifdef Light
!define DName "DMD-Light"
!else
!define DName "DMD"
!endif
!define ARP "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DName}"

; Version2 Fallback
; The version will be pulled from the VERSION file in the dmd repository if
; not specified with /D to makensis or defined above. Change the path to match.
!define D2VersionPath "..\..\dmd\VERSION"
!ifndef Version2
  !define /file Version2 ${D2VersionPath}
!endif


;--------------------------------------------------------
; Includes
;--------------------------------------------------------

!include "MUI.nsh"
!include "EnvVarUpdate.nsh"
!include "FileFunc.nsh"
!include "TextFunc.nsh"
!ifndef Light
!include "ReplaceInFile.nsh"
!endif

;------------------------------------------------------------
; Variables
;------------------------------------------------------------

Var I
Var J
Var K
Var InstanceCheck
Var VCVer
Var VCPath
Var WinSDKPath
Var UCRTPath
Var UCRTVersion


;--------------------------------------------------------
; General definitions
;--------------------------------------------------------

; Name of the installer
Name "D Programming Language"

; Name of the output file of the installer
!ifdef Light
!define InstallerFilename "dmd-light-${Version2}.exe"
!else
!define InstallerFilename "dmd-${Version2}.exe"
!endif
OutFile ${InstallerFilename}

; Where the program will be installed
InstallDir "C:\D"

; Take the installation directory from the registry, if possible
InstallDirRegKey HKCU "Software\${DName}" "InstallationFolder"

; This is so no one can corrupt the installer
CRCCheck force

SetCompressor /SOLID lzma


;------------------------------------------------------------
; Macros definition
;------------------------------------------------------------

; Check if a dmd installer instance is already running
!macro OneInstanceOnly
  System::Call 'kernel32::CreateMutexA(i 0, i 0, t "digital_mars_d_compiler_installer") ?e'
  Pop $R0
  StrCmp $R0 0 +3
    MessageBox MB_OK|MB_ICONSTOP "An instance of DMD installer is already running"
    Abort
!macroend


!macro DownloadAndRun Filename Url AltUrl
  inetc::get /CAPTION "Downloading ${Filename}..." /BANNER "" "${Url}" "$TEMP\${Filename}"
  Pop $0
  StrCmp $0 "OK" run
  !if `${AltUrl}` != ""
    inetc::get /CAPTION "Downloading ${Filename}..." /BANNER "" "${AltUrl}" "$TEMP\${Filename}"
    Pop $0
    StrCmp $0 "OK" run
  !endif

  ; failed
  MessageBox MB_OK|MB_ICONEXCLAMATION "Could not download ${Filename}$\r$\n$\r$\n${Url}"

  Goto dandr_done

  run:
  DetailPrint "Running ${Filename}"
  ExecWait "$TEMP\${Filename}"

  Delete "$TEMP\${Filename}"

  dandr_done:
!macroend

; Read SDK registry entry and check if kernel32.lib exists in the expected lib folder
!macro _DetectSDK REG_KEY VALUE LIBFOLDER
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\${REG_KEY}" ${VALUE}
    IfErrors +2 0
    IfFileExists "$0${LIBFOLDER}\kernel32.lib" +2
    SetErrors
!macroend

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

!define MUI_WELCOMEFINISHPAGE_BITMAP "d2-installer-image.bmp"
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


; Reserve files needed by the installation
!insertmacro MUI_RESERVEFILE_LANGDLL


;--------------------------------------------------------
; Sections
;--------------------------------------------------------

SectionGroup /e "D2"
  Section "-D2" Dmd2Files
    ; This section is mandatory
    SectionIn RO

    SetOutPath $INSTDIR
    CreateDirectory "$INSTDIR"

    ; Embed the directory specified
  !ifdef Light
    SetOutPath $INSTDIR\dmd2
    File /r ${EmbedD2Dir}\windows
    File    ${EmbedD2Dir}\license.txt
    SetOutPath $INSTDIR\dmd2\src\druntime
    File /r ${EmbedD2Dir}\src\druntime\import
    File    ${EmbedD2Dir}\src\druntime\license.txt
    SetOutPath $INSTDIR\dmd2\src
    File /r ${EmbedD2Dir}\src\phobos
    SetOutPath $INSTDIR\dmd2\windows\bin
    ; replace sc.ini with the shrinked down version
    File /oname=sc.ini ${EmbedD2Dir}\windows\bin\sc-light.ini
  !else
    File /r ${EmbedD2Dir}
  !endif
  
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
    WriteRegStr HKLM "SOFTWARE\${DName}" "InstallationFolder" "$INSTDIR"

    ; Registry keys for dmd uninstaller
    WriteRegStr HKLM "${ARP}" "DisplayName" "${DName}"
    WriteRegStr HKLM "${ARP}" "DisplayVersion" "${Version2}"
    WriteRegStr HKLM "${ARP}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "${ARP}" "DisplayIcon" "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "${ARP}" "Publisher" "${DPublisher}"
    WriteRegStr HKLM "${ARP}" "HelpLink" "http://dlang.org/"
    WriteRegDWORD HKLM "${ARP}" "NoModify" 1
    WriteRegDWORD HKLM "${ARP}" "NoRepair" 1
    WriteUninstaller "uninstall.exe"

  !ifndef Light
    StrCmp $VCVer "" no_vc_detected write_vc_path

    no_vc_detected:
      MessageBox MB_OK "Could not detect Visual Studio (2008-2017 are supported). No 64-bit support."
      goto finish_vc_path

    write_vc_path:
      !insertmacro _ReplaceInFile "$INSTDIR\dmd2\windows\bin\sc.ini" ";VCINSTALLDIR=" "VCINSTALLDIR=$VCPath"
      !insertmacro _ReplaceInFile "$INSTDIR\dmd2\windows\bin\sc.ini" ";$VCVer " ""

    finish_vc_path:
      ClearErrors

    StrCmp $WinSDKPath "" no_sdk_detected write_sdk_path

    no_sdk_detected:
      MessageBox MB_OK "Could not detect Windows SDK (6.0A-10.0 are supported). No 64-bit support."
      goto finish_sdk_path

    write_sdk_path:
      !insertmacro _ReplaceInFile "$INSTDIR\dmd2\windows\bin\sc.ini" ";WindowsSdkDir=" "WindowsSdkDir=$WinSDKPath"

    finish_sdk_path:
      ClearErrors
	  
    StrCmp $UCRTVersion "" no_ucrt_detected
      !insertmacro _ReplaceInFile "$INSTDIR\dmd2\windows\bin\sc.ini" ";UniversalCRTSdkDir=" "UniversalCRTSdkDir=$UCRTPath"
      !insertmacro _ReplaceInFile "$INSTDIR\dmd2\windows\bin\sc.ini" ";UCRTVersion=" "UCRTVersion=$UCRTVersion"
    no_ucrt_detected:
      ClearErrors
  !endif

  SectionEnd


  Section "Add to PATH" AddD2ToPath
    ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\dmd2\windows\bin"
  SectionEnd


  Section "Start Menu" StartMenuShortcuts
    CreateDirectory "$SMPROGRAMS\D"

  !ifndef Light
    CreateShortCut "$SMPROGRAMS\D\D2 HTML Documentation.lnk" "$INSTDIR\dmd2\html\d\index.html"
    CreateShortCut "$SMPROGRAMS\D\D2 Documentation.lnk" "$INSTDIR\dmd2\windows\bin\d.chm"
  !endif
    CreateShortCut "$SMPROGRAMS\D\D2 32-bit Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmd2vars32.bat""' "" "" SW_SHOWNORMAL "" "Open D2 32-bit Command Prompt"
    CreateShortCut "$SMPROGRAMS\D\D2 64-bit Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmd2vars64.bat""' "" "" SW_SHOWNORMAL "" "Open D2 64-bit Command Prompt"
  SectionEnd
SectionGroupEnd


SectionGroup /e "Extras"
!ifndef Light
  Section /o "Download Visual D" VisualDDownload
    !insertmacro DownloadAndRun ${VisualDFilename} ${VisualDUrl} ""
  SectionEnd


  Section /o "Download DMC" DmcDownload
    !insertmacro DownloadAndRun ${DmcFilename} ${DmcUrl} ${DmcAltUrl}
  SectionEnd


  Section /o "Download D1" Dmd1Download
    !insertmacro DownloadAndRun ${Dmd1Filename} ${Dmd1Url} ${Dmd1AltUrl}
  SectionEnd
!else
  Section "VC2010 x86 Redistributable Runtime" VCRedistributable86
    !insertmacro DownloadAndRun ${VCRedistx86Filename} ${VCRedistx86Url} ""
  SectionEnd


  Section "VC2010 x64 Redistributable Runtime" VCRedistributable64
    !insertmacro DownloadAndRun ${VCRedistx64Filename} ${VCRedistx64Url} ""
  SectionEnd
!endif
SectionGroupEnd

;--------------------------------------------------------
; Helper functions
;--------------------------------------------------------

!ifdef Light
Function DetectVCRedistributable

    SetRegView 64 ; look at the 64-bit registry hive if available
    ClearErrors
    ReadRegStr $0 HKLM "${VCRedistx86RegKey}" "ProductName"
    IfErrors vcredistx86_notinstalled
        SectionSetFlags ${VCRedistributable86} 16 ; unselected and read only
    vcredistx86_notinstalled:

    ClearErrors
    ReadRegStr $0 HKLM "${VCRedistx64RegKey}" "ProductName"
    IfErrors vcredistx64_notinstalled
        SectionSetFlags ${VCRedistributable64} 16 ; unselected and read only
    vcredistx64_notinstalled:
    SetRegView 32 ; retore default

FunctionEnd

!else
Function DetectVSAndSDK
    ClearErrors

    ReadRegStr $0 HKLM "SOFTWARE\Microsoft\VisualStudio\SxS\VS7" "15.0"
    StrCpy $1 "VC2017"
    IfErrors not_vc2017
        ${LineRead} "$0\VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt" "1" $2
        IfErrors not_vc2017
        StrCpy $0 "$0\VC\Tools\MSVC\$2"
        Goto done_vs
    not_vc2017:
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\VisualStudio\14.0\Setup\VC" "ProductDir"
    StrCpy $1 "VC2015"
    IfErrors 0 done_vs
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\VisualStudio\12.0\Setup\VC" "ProductDir"
    StrCpy $1 "VC2013"
    IfErrors 0 done_vs
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\VisualStudio\11.0\Setup\VC" "ProductDir"
    StrCpy $1 "VC2012"
    IfErrors 0 done_vs
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\VisualStudio\10.0\Setup\VC" "ProductDir"
    StrCpy $1 "VC2010"
    IfErrors 0 done_vs
    ClearErrors
    ReadRegStr $0 HKLM "Software\Microsoft\VisualStudio\9.0\Setup\VC" "ProductDir"
    StrCpy $1 "VC2008"
    IfErrors done done_vs

    done_vs:
    StrCpy $VCPath $0
    StrCpy $VCVer $1

    ; detect ucrt
    ReadRegStr $0 HKLM "Software\Microsoft\Windows Kits\Installed Roots" "KitsRoot10"
    IfErrors done done_ucrt

    done_ucrt:
    StrCpy $UCRTPath $0

      StrCpy $UCRTVersion ""
      FindFirst $0 $1 $UCRTPath\Lib\*.*
      loop_ff:
        StrCmp $1 "" done_ff
        StrCpy $UCRTVersion $1 ; hoping the directory is retrieved in ascending order (done by NTFS)
        FindNext $0 $1
        Goto loop_ff
      done_ff:
      FindClose $0

    done:

    !insertmacro _DetectSDK "Windows Kits\Installed Roots" "KitsRoot10" "Lib\$UCRTVersion\um\x64"
    IfErrors 0 done_sdk
    !insertmacro _DetectSDK "Windows Kits\Installed Roots" "KitsRoot81" "Lib\winv6.3\um\x64" 
    IfErrors 0 done_sdk
    !insertmacro _DetectSDK "Microsoft SDKs\Windows\v8.1" "InstallationFolder" "Lib\winv6.3\um\x64"
    IfErrors 0 done_sdk
    !insertmacro _DetectSDK "Microsoft SDKs\Windows\v8.1A" "InstallationFolder" "Lib\winv6.3\um\x64"
    IfErrors 0 done_sdk
    !insertmacro _DetectSDK "Windows Kits\Installed Roots" "KitsRoot" "Lib\win8\um\x64"
    IfErrors 0 done_sdk
    !insertmacro _DetectSDK "Microsoft SDKs\Windows\v8.0" "InstallationFolder" "Lib\win8\um\x64"
    IfErrors 0 done_sdk
    !insertmacro _DetectSDK "Microsoft SDKs\Windows\v8.0A" "InstallationFolder" "Lib\win8\um\x64"
    IfErrors 0 done_sdk
    !insertmacro _DetectSDK "Microsoft SDKs\Windows\v7.1A" "InstallationFolder" "Lib\x64"
    IfErrors 0 done_sdk
    !insertmacro _DetectSDK "Microsoft SDKs\Windows\v7.0A" "InstallationFolder" "Lib\x64"
    IfErrors 0 done_sdk
    !insertmacro _DetectSDK "Microsoft SDKs\Windows\v6.0A" "InstallationFolder" "Lib\x64"
    IfErrors no_sdk done_sdk

    done_sdk:
    StrCpy $WinSDKPath $0

    no_sdk:

FunctionEnd
!endif

;--------------------------------------------------------
; Installer functions
;--------------------------------------------------------

Function .onInit
  ; Check if a dmd installer instance is already running
  !insertmacro OneInstanceOnly


  ; Force install without uninstall (useful if uninstall is broken)
  ${GetParameters} $R0
  StrCmp $R0 "/f" done_uninst


  ; Remove previous dmd installation if any
  ; this section is for previous dmd installer only
  ReadRegStr $R5 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "UninstallString"
  ReadRegStr $R6 HKLM "SOFTWARE\D" "Install_Dir"
  StrCmp $R5 "" done_uninst_prev
  MessageBox MB_OKCANCEL|MB_ICONQUESTION \
  "A previous DMD is installed on your system$\n$\nPress 'OK' to replace by ${DName} ${Version2}" \
  IDOK +2
  Abort
  ClearErrors
  ; Run uninstaller fron installed directory
  ExecWait '$R5 /S _?=$R6' $K
  ; Exit if uninstaller return an error
  IfErrors 0 +3
    MessageBox MB_OK|MB_ICONSTOP \
    "An error occurred when removing DMD$\n$\nRun '${InstallerFilename} /f' to force install ${DName} ${Version2}"
    Abort
  ; Remove in background the remaining uninstaller program itself
  Sleep 1000
  Exec '$R5 /S'
  ; MessageBox MB_OK|MB_ICONINFORMATION "Previous DMD uninstalled"

  done_uninst_prev:
  ; End of removing previous dmd installation section


  ; Remove if dmd is already installed
  ReadRegStr $R0 HKLM "${ARP}" "UninstallString"
  StrCmp $R0 "" done_uninst

  ReadRegStr $I HKLM "${ARP}" "DisplayName"
  ReadRegStr $J HKLM "${ARP}" "DisplayVersion"
  MessageBox MB_OKCANCEL|MB_ICONQUESTION \
  "$I v$J is installed on your system$\n$\nPress 'OK' to replace by ${DName} ${Version2}" \
  IDOK uninst
  Abort

  uninst:
    ${GetParent} $R0 $INSTDIR

    ClearErrors
    ; Run uninstaller from installed directory
    ExecWait '$R0 /IC False _?=$INSTDIR' $K
    ; Exit if uninstaller return an error
    IfErrors 0 +3
      MessageBox MB_OK|MB_ICONSTOP \
      "An error occurred when removing $I v$J$\n$\nRun '${InstallerFilename} /f' to force install ${DName} ${Version2}"
      Abort
    ; Exit if uninstaller is cancelled by user
    StrCmp $K 0 +2
      Abort
    ; Remove in background the remaining uninstaller program itself
    Exec '$R0 /IC False /S'

  done_uninst:

!ifdef Light
  Call DetectVCRedistributable
!else
  Call DetectVSAndSDK
  StrCmp $VCVer "" ask_vs
  StrCmp $WinSDKPath "" ask_vs
  Goto done_vs

  ask_vs:
    MessageBox MB_YESNO|MB_ICONQUESTION \
    "For 64-bit support MSVC and the Windows SDK are needed but no compatible versions were found. Do you want to install VS2013?" \
    IDYES install_vs IDNO done_vs

  install_vs:
    !insertmacro DownloadAndRun ${VS2013Filename} ${VS2013Url} ""
    Call DetectVSAndSDK

  done_vs:
!endif

FunctionEnd


; Contains descriptions of components and other stuff
!include d2-installer-descriptions.nsh


;--------------------------------------------------------
; Uninstaller
;--------------------------------------------------------

Section "Uninstall"
  ; Remove directories from PATH (for all users)
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\dmd2\windows\bin"

  ; Remove stuff from registry
  DeleteRegKey HKLM "${ARP}"
  DeleteRegKey HKLM "SOFTWARE\${DName}"

  ; Remove the uninstaller
  Delete $INSTDIR\uninstall.exe

  ; Remove the generated batch files
  Delete $INSTDIR\dmd2vars32.bat
  Delete $INSTDIR\dmd2vars64.bat

  ; Remove shortcuts
!ifndef Light
  Delete "$SMPROGRAMS\D\D2 HTML Documentation.lnk"
  Delete "$SMPROGRAMS\D\D2 Documentation.lnk"
!endif
  Delete "$SMPROGRAMS\D\D2 32-bit Command Prompt.lnk"
  Delete "$SMPROGRAMS\D\D2 64-bit Command Prompt.lnk"
  RMDir "$SMPROGRAMS\D"

  ${GetOptions} $CMDLINE "/S" $R0
  IfErrors 0 rmdir
  MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
  "The uninstaller will now recursively delete ALL files and directories under '$INSTDIR\dmd2'. Continue?" \
  /SD IDOK IDOK rmdir
  Abort

  rmdir:
  ; Remove used directories
  RMDir /r "$INSTDIR\dmd2"
  RMDir "$INSTDIR"
SectionEnd


;--------------------------------------------------------
; Uninstaller functions
;--------------------------------------------------------

Function un.onInit
  ; Check if a dmd installer instance is already running
  ; Do not check if "/IC False" argument is passed to uninstaller
  ${GetOptions} $CMDLINE "/IC" $InstanceCheck
  ${IfNot} "$InstanceCheck" == "False"
    !insertmacro OneInstanceOnly
  ${EndIf}
FunctionEnd

