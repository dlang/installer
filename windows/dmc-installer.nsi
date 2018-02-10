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
; - EmbedDmcDir: The path to the directory tree recursively embedded in the
;                generated installer.
; - VersionDmc:  The DMC version number.
;
; The easiest way is to use the /D command line options for makensis
;   makensis /DEmbedDmcDir=<some path> /DVersionDmc=8xx

;--------------------------------------------------------
; Defines
;--------------------------------------------------------

; Required
; --------
; EmbedDmcDir. Can be specified here rather than on the makensis command line:
;!define EmbedDmcDir "<path to files to install>"

; VersionDmc. Can be specified here rather than on the makensis command line:
;!define VersionDmc "8xx"


; Publishing Details
!define DmcPublisher "Digital Mars"
!define DmcName "DMC"
!define ARP "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DmcName}"


;--------------------------------------------------------
; Includes
;--------------------------------------------------------

!include "MUI.nsh"
!include "FileFunc.nsh"


;------------------------------------------------------------
; Variables
;------------------------------------------------------------

Var I
Var J
Var K
Var InstanceCheck



;--------------------------------------------------------
; General definitions
;--------------------------------------------------------

; Name of the installer
Name "Digital Mars Compiler"

; Name of the output file of the installer
!define InstallerFilename "dmc-${VersionDmc}.exe"
OutFile ${InstallerFilename}

; Where the program will be installed
InstallDir "C:\DMC"

; Take the installation directory from the registry, if possible
InstallDirRegKey HKCU "Software\${DmcName}" "InstallationFolder"

; This is so no one can corrupt the installer
CRCCheck force

SetCompressor /SOLID lzma


;------------------------------------------------------------
; Macros definition
;------------------------------------------------------------

; Check if a dmc installer instance is already running
!macro OneInstanceOnly
  System::Call 'kernel32::CreateMutexA(i 0, i 0, t "digital_mars_dmc_compiler_installer") ?e'
  Pop $R0
  StrCmp $R0 0 +3
    MessageBox MB_OK|MB_ICONSTOP "An instance of DMC installer is already running"
    Abort
!macroend


;--------------------------------------------------------
; Interface settings
;--------------------------------------------------------

; Confirmation when exiting the installer
!define MUI_ABORTWARNING

;!define MUI_ICON "dmc-installer-icon.ico"
;!define MUI_UNICON "dmc-uninstaller-icon.ico"


;--------------------------------------------------------
; Language selection dialog settings
;--------------------------------------------------------

; Remember the installation language
!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"
!define MUI_LANGDLL_REGISTRY_KEY "Software\DMC"
!define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"


;--------------------------------------------------------
; Installer pages
;--------------------------------------------------------

!define MUI_WELCOMEFINISHPAGE_BITMAP "dmc-installer-image.bmp"
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

SectionGroup /e "DMC"
  Section "-DMC" DmcFiles
    ; This section is mandatory
    SectionIn RO

    SetOutPath $INSTDIR
    CreateDirectory "$INSTDIR"

    ; Embed the directory specified
    File /r ${EmbedDmcDir}

    ; Write installation dir in the registry
    WriteRegStr HKLM "SOFTWARE\${DmcName}" "InstallationFolder" "$INSTDIR"

    ; Registry keys for dmc uninstaller
    WriteRegStr HKLM "${ARP}" "DisplayName" "${DmcName}"
    WriteRegStr HKLM "${ARP}" "DisplayVersion" "${VersionDmc}"
    WriteRegStr HKLM "${ARP}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "${ARP}" "DisplayIcon" "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "${ARP}" "Publisher" "${DmcPublisher}"
    WriteRegStr HKLM "${ARP}" "HelpLink" "http://www.digitalmars.com/features.html"
    WriteRegDWORD HKLM "${ARP}" "NoModify" 1
    WriteRegDWORD HKLM "${ARP}" "NoRepair" 1
    WriteUninstaller "uninstall.exe"
  SectionEnd

SectionGroupEnd


;--------------------------------------------------------
; Installer functions
;--------------------------------------------------------

Function .onInit
  ; Check if a dmc installer instance is already running
  !insertmacro OneInstanceOnly


  ; Force install without uninstall (useful if uninstall is broken)
  ${GetParameters} $R0
  StrCmp $R0 "/f" done


  ; Remove if dmc is already installed
  ReadRegStr $R0 HKLM "${ARP}" "UninstallString"
  StrCmp $R0 "" done

  ReadRegStr $I HKLM "${ARP}" "DisplayName"
  ReadRegStr $J HKLM "${ARP}" "DisplayVersion"
  MessageBox MB_OKCANCEL|MB_ICONQUESTION \
  "$I v$J is installed on your system$\n$\nPress 'OK' to replace it with ${DmcName} ${VersionDmc}" \
  IDOK uninst
  Abort

  uninst:
    ClearErrors
    ; Run uninstaller from installed directory
    ExecWait '$R0 /IC False _?=$INSTDIR' $K
    ; Exit if uninstaller return an error
    IfErrors 0 +3
      MessageBox MB_OK|MB_ICONSTOP \
      "An error occurred when removing $I v$J$\n$\nRun '${InstallerFilename} /f' to force install ${DmcName} ${VersionDmc}"
      Abort
    ; Exit if uninstaller is cancelled by user
    StrCmp $K 0 +2
      Abort
    ; Remove in background the remaining uninstaller program itself
    Exec '$R0 /IC False /S'

  done:
FunctionEnd


; Contains descriptions of components and other stuff
!include dmc-installer-descriptions.nsh


;--------------------------------------------------------
; Uninstaller
;--------------------------------------------------------

Section "Uninstall"
  ; Remove stuff from registry
  DeleteRegKey HKLM "${ARP}"
  DeleteRegKey HKLM "SOFTWARE\${DmcName}"

  ; Remove the uninstaller
  Delete $INSTDIR\uninstall.exe

  ; Remove used directories
  RMDir /r /REBOOTOK "$INSTDIR\dm"
  RMDir /REBOOTOK "$INSTDIR"
SectionEnd


;--------------------------------------------------------
; Uninstaller functions
;--------------------------------------------------------

Function un.onInit
  ; Check if a dmc installer instance is already running
  ; Do not check if "/IC False" argument is passed to uninstaller
  ${GetOptions} $CMDLINE "/IC" $InstanceCheck
  ${IfNot} "$InstanceCheck" == "False"
    !insertmacro OneInstanceOnly
  ${EndIf}
FunctionEnd

