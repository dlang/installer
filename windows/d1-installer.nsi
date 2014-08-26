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
; - EmbedD1Dir: The path to the directory tree recursively embedded in the
;               generated installer.
; - Version1:   The DMD version number.
;
; The easiest way is to use the /D command line options for makensis
;   makensis /DEmbedD1Dir=<some path> /DVersion1=1.xxx

;--------------------------------------------------------
; Defines
;--------------------------------------------------------

; Required
; --------
; EmbedD1Dir. Can be specified here rather than on the makensis command line:
;!define EmbedD1Dir "<path to files to install>"

; Version1. Can be specified here rather than on the makensis command line:
;!define Version1 "1.076"


; Publishing Details
!define DPublisher "Digital Mars"
!define DName "DMD 1"
!define ARP "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DName}"


;--------------------------------------------------------
; Includes
;--------------------------------------------------------

!include "MUI.nsh"
!include "EnvVarUpdate.nsh"
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
Name "D1 Programming Language"

; Name of the output file of the installer
!define InstallerFilename "dmd-${Version1}.exe"
OutFile ${InstallerFilename}

; Where the program will be installed
InstallDir "C:\D1"

; Take the installation directory from the registry, if possible
InstallDirRegKey HKCU "Software\${DName}" "InstallationFolder"

; This is so no one can corrupt the installer
CRCCheck force

SetCompressor /SOLID lzma


;------------------------------------------------------------
; Macros definition
;------------------------------------------------------------

; Check if a dmd 1 installer instance is already running
!macro OneInstanceOnly
  System::Call 'kernel32::CreateMutexA(i 0, i 0, t "digital_mars_d1_compiler_installer") ?e'
  Pop $R0
  StrCmp $R0 0 +3
    MessageBox MB_OK|MB_ICONSTOP "An instance of DMD 1 installer is already running"
    Abort
!macroend


;--------------------------------------------------------
; Interface settings
;--------------------------------------------------------

; Confirmation when exiting the installer
!define MUI_ABORTWARNING

;!define MUI_ICON "d1-installer-icon.ico"
;!define MUI_UNICON "d1-uninstaller-icon.ico"


;--------------------------------------------------------
; Language selection dialog settings
;--------------------------------------------------------

; Remember the installation language
!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"
!define MUI_LANGDLL_REGISTRY_KEY "Software\D1"
!define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"


;--------------------------------------------------------
; Installer pages
;--------------------------------------------------------

!define MUI_WELCOMEFINISHPAGE_BITMAP "d1-installer-image.bmp"
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

SectionGroup /e "D1"
  Section "-D1" Dmd1Files
    ; This section is mandatory
    SectionIn RO

    SetOutPath $INSTDIR
    CreateDirectory "$INSTDIR"

    ; Embed the directory specified
    File /r ${EmbedD1Dir}

    ; Create command line batch file
    FileOpen $0 "$INSTDIR\dmd1vars.bat" w
    FileWrite $0 "@echo.$\n"
    FileWrite $0 "@echo Setting up environment for using DMD 1 from %~dp0dmd\windows\bin.$\n"
    FileWrite $0 "@set PATH=%~dp0dmd\windows\bin;%PATH%$\n"
    FileClose $0

    ; Write installation dir in the registry
    WriteRegStr HKLM "SOFTWARE\${DName}" "InstallationFolder" "$INSTDIR"

    ; Registry keys for dmd 1 uninstaller
    WriteRegStr HKLM "${ARP}" "DisplayName" "${DName}"
    WriteRegStr HKLM "${ARP}" "DisplayVersion" "${Version1}"
    WriteRegStr HKLM "${ARP}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "${ARP}" "DisplayIcon" "$INSTDIR\uninstall.exe"
    WriteRegStr HKLM "${ARP}" "Publisher" "${DPublisher}"
    WriteRegStr HKLM "${ARP}" "HelpLink" "http://www.digitalmars.com/d/1.0/index.html"
    WriteRegDWORD HKLM "${ARP}" "NoModify" 1
    WriteRegDWORD HKLM "${ARP}" "NoRepair" 1
    WriteUninstaller "uninstall.exe"
  SectionEnd


  Section /o "Add to PATH" AddD1ToPath
    ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\dmd\windows\bin"
  SectionEnd


  Section "Start Menu" StartMenuShortcuts
    CreateDirectory "$SMPROGRAMS\D"

    CreateShortCut "$SMPROGRAMS\D\D1 HTML Documentation.lnk" "$INSTDIR\dmd\html\d\index.html"
    CreateShortCut "$SMPROGRAMS\D\D1 Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmd1vars.bat""' "" "" SW_SHOWNORMAL "" "Open D1 Command Prompt"
  SectionEnd
SectionGroupEnd


;--------------------------------------------------------
; Installer functions
;--------------------------------------------------------

Function .onInit
  ; Check if a dmd 1 installer instance is already running
  !insertmacro OneInstanceOnly


  ; Force install without uninstall (useful if uninstall is broken)
  ${GetParameters} $R0
  StrCmp $R0 "/f" done


  ; Remove if dmd 1 is already installed
  ReadRegStr $R0 HKLM "${ARP}" "UninstallString"
  StrCmp $R0 "" done

  ReadRegStr $I HKLM "${ARP}" "DisplayName"
  ReadRegStr $J HKLM "${ARP}" "DisplayVersion"
  MessageBox MB_OKCANCEL|MB_ICONQUESTION \
  "$I v$J is installed on your system$\n$\nPress 'OK' to replace by ${DName} ${Version1}" \
  IDOK uninst
  Abort

  uninst:
    ClearErrors
    ; Run uninstaller from installed directory
    ExecWait '$R0 /IC False _?=$INSTDIR' $K
    ; Exit if uninstaller return an error
    IfErrors 0 +3
      MessageBox MB_OK|MB_ICONSTOP \
      "An error occurred when removing $I v$J$\n$\nRun '${InstallerFilename} /f' to force install ${DName} ${Version1}"
      Abort
    ; Exit if uninstaller is cancelled by user
    StrCmp $K 0 +2
      Abort
    ; Remove in background the remaining uninstaller program itself
    Exec '$R0 /IC False /S'

  done:
FunctionEnd


; Contains descriptions of components and other stuff
!include d1-installer-descriptions.nsh


;--------------------------------------------------------
; Uninstaller
;--------------------------------------------------------

Section "Uninstall"
  ; Remove directories from PATH (for all users)
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\dmd\windows\bin"

  ; Remove stuff from registry
  DeleteRegKey HKLM "${ARP}"
  DeleteRegKey HKLM "SOFTWARE\${DName}"

  ; Remove the uninstaller
  Delete $INSTDIR\uninstall.exe

  ; Remove the generated batch files
  Delete $INSTDIR\dmd1vars.bat

  ; Remove shortcuts
  Delete "$SMPROGRAMS\D\D1 HTML Documentation.lnk"
  RMDir /r /REBOOTOK "$SMPROGRAMS\D"

  ; Remove used directories
  RMDir /r /REBOOTOK "$INSTDIR\dmd"
  RMDir /REBOOTOK "$INSTDIR"
SectionEnd


;--------------------------------------------------------
; Uninstaller functions
;--------------------------------------------------------

Function un.onInit
  ; Check if a dmd 1 installer instance is already running
  ; Do not check if "/IC False" argument is passed to uninstaller
  ${GetOptions} $CMDLINE "/IC" $InstanceCheck
  ${IfNot} "$InstanceCheck" == "False"
    !insertmacro OneInstanceOnly
  ${EndIf}
FunctionEnd

