;--------------------------------------------------------
; Defines
;--------------------------------------------------------

!define DPublisher "Digital Mars"
!define DProduct "D Compiler"
!define DName "${DPublisher} ${DProduct}"
!define ARP "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DName}"

;--------------------------------------------------------
; Includes
;--------------------------------------------------------

!include "MUI.nsh"
!include "EnvVarUpdate.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"
!include "LogicLib.nsh"

;--------------------------------------------------------
; General definitions
;--------------------------------------------------------

; Name of the installer
Name "${DName} v${Version}"

; Name of the output file of the installer
OutFile "${ExeFile}"

; Where the program will be installed
InstallDir "C:\dmd\"

; Take the instalation directory from the registry, if possible
InstallDirRegKey HKLM "SOFTWARE\${DName}" "Install_Dir"

; This is so no one can corrupt the installer
CRCCheck force

; Compress with lzma algorithm
SetCompressor /SOLID lzma

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
!define MUI_LANGDLL_REGISTRY_KEY "Software\${DName}"
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

;--------------------------------------------------------
; Reserve files needed by the installation
;--------------------------------------------------------

!insertmacro MUI_RESERVEFILE_LANGDLL

;--------------------------------------------------------
; Required section: main program files,
; registry entries, etc.
;--------------------------------------------------------

SectionGroup /e "dmd"

Section "-dmd" DmdFiles

    ; Remove previous installation if same directory
    ;Exec $INSTDIR\uninstall.exe

    ; This section is mandatory
    ;SectionIn RO
    
    SetOutPath $INSTDIR
    
    ; Create installation directory
    CreateDirectory "$INSTDIR"
    
	; dmd directory to include
	File /r dmd/dmd2

	; Computes the size of the installed files (in KB)
	${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
	IntFmt $3 "0x%08X" $0

    ; Create command line batch file
    FileOpen $0 "$INSTDIR\dmdvars.bat" w
    FileWrite $0 "@echo.$\n"
    FileWrite $0 "@echo Setting up environment for using DMD 2 from %~dp0dmd2\windows\bin.$\n"
    FileWrite $0 "@set PATH=%~dp0dmd2\windows\bin;%PATH%$\n"
    FileClose $0

    ; Write installation dir in the registry
    WriteRegStr HKLM "SOFTWARE\${DName}" "Install_Dir" "$INSTDIR"

    ; Write registry keys to make uninstall from Windows
    WriteRegStr HKLM "${ARP}" "DisplayName" "${DName}"
    WriteRegStr HKLM "${ARP}" "DisplayVersion" "${Version}"
    WriteRegStr HKLM "${ARP}" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegStr HKLM "${ARP}" "DisplayIcon" '"$INSTDIR\uninstall.exe"'
    WriteRegStr HKLM "${ARP}" "Publisher" "${DPublisher}"
    WriteRegStr HKLM "${ARP}" "HelpLink" "http://dlang.org/"
	WriteRegDWORD HKLM "${ARP}" "EstimatedSize" "$3"
    WriteRegDWORD HKLM "${ARP}" "NoModify" 1
    WriteRegDWORD HKLM "${ARP}" "NoRepair" 1
    WriteUninstaller "uninstall.exe"

SectionEnd

Section "cURL support" cURLFiles

    ; This section is mandatory
    ;SectionIn RO
    
    SetOutPath $INSTDIR
    
    ; Create installation directory
    CreateDirectory "$INSTDIR"
    
	; curl directory to include
	File /r curl/dmd2

	; Computes the size of the installed files (in KB)
	${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
	IntFmt $3 "0x%08X" $0

    ; Write installation dir in the registry
    WriteRegStr HKLM "SOFTWARE\${DName}" "Install_Dir" "$INSTDIR"

    ; Write registry keys to make uninstall from Windows
    WriteRegStr HKLM "${ARP}" "DisplayName" "${DName}"
    WriteRegStr HKLM "${ARP}" "DisplayVersion" "${Version}"
    WriteRegStr HKLM "${ARP}" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegStr HKLM "${ARP}" "DisplayIcon" '"$INSTDIR\uninstall.exe"'
    WriteRegStr HKLM "${ARP}" "Publisher" "${DPublisher}"
    WriteRegStr HKLM "${ARP}" "HelpLink" "http://dlang.org/"
	WriteRegDWORD HKLM "${ARP}" "EstimatedSize" "$3"
    WriteRegDWORD HKLM "${ARP}" "NoModify" 1
    WriteRegDWORD HKLM "${ARP}" "NoRepair" 1
    WriteUninstaller "uninstall.exe"

SectionEnd

Section "Add to PATH" AddDmdToPath

    ; Add dmd 2 directories to path (for all users)
    SectionGetFlags ${DmdFiles} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +2
        ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\dmd2\windows\bin"

SectionEnd

SectionGroupEnd


SectionGroup /e "dmc"

Section "-dmc" DmcFiles

    ; This section is mandatory
    ;SectionIn RO

    SetOutPath $INSTDIR

    ; Create installation directory
    CreateDirectory "$INSTDIR"

	; dmc directory to include
	File /r dm

	; Computes the size of the installed files (in KB)
	${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
	IntFmt $3 "0x%08X" $0

    ; Create command line batch file
    FileOpen $0 "$INSTDIR\dmcvars.bat" w
    FileWrite $0 "@echo.$\n"
    FileWrite $0 "@echo Setting up environment for using dmc from %~dp0dm\bin.$\n"
    FileWrite $0 "@set PATH=%~dp0dm\bin;%PATH%$\n"
    FileClose $0

    ; Write installation dir in the registry
    WriteRegStr HKLM "SOFTWARE\${DName}" "Install_Dir" "$INSTDIR"

    ; Write registry keys to make uninstall from Windows
    WriteRegStr HKLM "${ARP}" "DisplayName" "${DName}"
    WriteRegStr HKLM "${ARP}" "DisplayVersion" "${Version}"
    WriteRegStr HKLM "${ARP}" "UninstallString" '"$INSTDIR\uninstall.exe"'
    WriteRegStr HKLM "${ARP}" "DisplayIcon" '"$INSTDIR\uninstall.exe"'
    WriteRegStr HKLM "${ARP}" "Publisher" "${DPublisher}"
    WriteRegStr HKLM "${ARP}" "HelpLink" "http://dlang.org/"
	WriteRegDWORD HKLM "${ARP}" "EstimatedSize" "$3"
    WriteRegDWORD HKLM "${ARP}" "NoModify" 1
    WriteRegDWORD HKLM "${ARP}" "NoRepair" 1
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

Section "Start menu items" StartMenuItems
    CreateDirectory "$SMPROGRAMS\${DName} v${Version}"

    ; install dmd documentation and command prompt
    SectionGetFlags ${DmdFiles} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +3
		CreateShortCut "$SMPROGRAMS\${DName} v${Version}\dmd Documentation.lnk" \
		"$INSTDIR\dmd2\html\d\index.html" "" "$INSTDIR\dmd2\html\d\index.html" 0
		CreateShortCut "$SMPROGRAMS\${DName} v${Version}\dmd Command Prompt.lnk" '%comspec%' \
		'/k ""$INSTDIR\dmdvars.bat""' "" "" SW_SHOWNORMAL "" "Open dmd Command Prompt"

    ; install dmc command prompt
    SectionGetFlags ${DmcFiles} $0
    IntOp $0 $0 & ${SF_SELECTED}
    IntCmp $0 ${SF_SELECTED} +1 +2
        CreateShortCut "$SMPROGRAMS\${DName} v${Version}\dmc Command Prompt.lnk" '%comspec%' '/k ""$INSTDIR\dmcvars.bat""' "" "" SW_SHOWNORMAL "" "Open dmc Command Prompt"


    CreateShortCut "$SMPROGRAMS\${DName} v${Version}\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0
SectionEnd

;--------------------------------------------------------
; Installer functions
;--------------------------------------------------------

Function .onInit

	SetShellVarContext all

    ; This is commented because there's only one language
    ; (for now)
    ;!insertmacro MUI_LANGDLL_DISPLAY

	; Remove if already installed
	ReadRegStr $R0 HKLM "${ARP}" "UninstallString"
	StrCmp $R0 "" done

	ReadRegStr $4 HKLM "${ARP}" "DisplayName"
    ReadRegStr $5 HKLM "${ARP}" "DisplayVersion"
	MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION \
	"$4 v$5 is installed in your system$\n$\nClick 'OK' to replace it by ${DName} v${Version}" \
	IDOK uninst
	Abort
	 
	;Run the uninstaller
	uninst:
	ExecWait '$R0 /S'

	done:

FunctionEnd

;--------------------------------------------------------
; Enable and disable "sections" and "next" button
;--------------------------------------------------------

Function .onSelChange

	SectionGetFlags ${cURLFiles} $R1
	SectionGetFlags ${AddDmdToPath} $R2
	SectionGetFlags ${AddDmcToPath} $R3
	SectionGetFlags ${StartMenuItems} $R4

	${If} ${SectionIsSelected} ${DmdFiles}
		${If} $R1 == 16
			!insertmacro SetSectionFlag ${cURLFiles} 1
		${EndIf}
		${If} $R2 == 16
			!insertmacro SetSectionFlag ${AddDmdToPath} 1
		${EndIf}
		!insertmacro ClearSectionFlag ${cURLFiles} 16
		!insertmacro ClearSectionFlag ${AddDmdToPath} 16
	${Else}
		!insertmacro ClearSectionFlag ${cURLFiles} 1
		!insertmacro SetSectionFlag ${cURLFiles} 16
		!insertmacro ClearSectionFlag ${AddDmdToPath} 1
		!insertmacro SetSectionFlag ${AddDmdToPath} 16
	${EndIf}

	${If} ${SectionIsSelected} ${DmcFiles}
		${If} $R3 == 16
			!insertmacro SetSectionFlag ${AddDmcToPath} 1
		${EndIf}
		!insertmacro ClearSectionFlag ${AddDmcToPath} 16
	${Else}
		!insertmacro ClearSectionFlag ${AddDmcToPath} 1
		!insertmacro SetSectionFlag ${AddDmcToPath} 16
	${EndIf}

	GetDlgItem $1 $HWNDPARENT 1

	${IfNot} ${SectionIsSelected} ${DmdFiles}
		${IfNot} ${SectionIsSelected} ${DmcFiles}
			!insertmacro ClearSectionFlag ${StartMenuItems} 1
			!insertmacro SetSectionFlag ${StartMenuItems} 16
			EnableWindow $1 0
		${Else}
			${If} $R4 == 16
				!insertmacro SetSectionFlag ${StartMenuItems} 1
			${EndIf}
			!insertmacro ClearSectionFlag ${StartMenuItems} 16
			EnableWindow $1 1
		${EndIf}
	${Else}
		${If} $R4 == 16
			!insertmacro SetSectionFlag ${StartMenuItems} 1
		${EndIf}
		!insertmacro ClearSectionFlag ${StartMenuItems} 16
		EnableWindow $1 1
	${EndIf}
	

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
    DeleteRegKey HKLM "${ARP}"
    DeleteRegKey HKLM "SOFTWARE\${DName}"
    DeleteRegKey /ifempty HKLM "SOFTWARE\${DName}"

    ; This is for deleting the remembered language of the installation
    DeleteRegKey HKCU "Software\${DName}"
    DeleteRegKey /ifempty HKCU "Software\${DName}"

    ; Remove the uninstaller
    Delete $INSTDIR\uninstall.exe
    
    ; Remove shortcuts
    Delete "$SMPROGRAMS\${DName} v${Version}\dmd Documentation.lnk"
    Delete "$SMPROGRAMS\${DName} v${Version}\dmd Command Prompt.lnk"
    Delete "$SMPROGRAMS\${DName} v${Version}\dmc Command Prompt.lnk"
    Delete "$SMPROGRAMS\${DName} v${Version}\Uninstall.lnk"

	; Remove files
	Delete "$INSTDIR\dmdvars.bat"
	Delete "$INSTDIR\dmcvars.bat"

    ; Remove used directories
    RMDir /r /REBOOTOK "$INSTDIR\dm"
    RMDir /r /REBOOTOK "$INSTDIR\dmd2"
    RMDir "$INSTDIR"
    RMDir /r /REBOOTOK "$SMPROGRAMS\${DName} v${Version}"

SectionEnd

;--------------------------------------------------------
; Uninstaller functions
;--------------------------------------------------------

Function un.onInit

	SetShellVarContext all

    ; Ask language before starting the uninstall

    ; This is commented because there's only one language
    ; (for now)
    ;!insertmacro MUI_UNGETLANGUAGE
FunctionEnd

