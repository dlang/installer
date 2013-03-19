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
; Variables
;--------------------------------------------------------

Var GetInstalledSize.total
Var I
Var J
Var InstanceCheck

;--------------------------------------------------------
; General definitions
;--------------------------------------------------------

; Requested execution level for Windows 7
RequestExecutionLevel admin

; Name of the installer
Name "${DName} v${Version}"

; Name of the output file of the installer
OutFile "${ExeFile}"

; Where the program will be installed
InstallDir "C:\dmd\"

; Take the instalation directory from the registry, if possible
InstallDirRegKey HKLM "SOFTWARE\${DName}" "Install Directory"

; This is so no one can corrupt the installer
CRCCheck force

; Compress with lzma algorithm
SetCompressor /SOLID lzma

;--------------------------------------------------------
; Functions definition
;--------------------------------------------------------

; Return the total size of the selected (installed) sections, formated as DWORD
; Assumes no more than 256 sections are defined
Function GetInstalledSize
	StrCpy $GetInstalledSize.total 0
	${ForEach} $I 0 256 + 1
		${if} ${SectionIsSelected} $I
			SectionGetSize $I $J
			IntOp $GetInstalledSize.total $GetInstalledSize.total + $J
		${Endif}
	${Next}
	IntFmt $GetInstalledSize.total "0x%08X" $GetInstalledSize.total
FunctionEnd

;--------------------------------------------------------
; Macros definition
;--------------------------------------------------------

; Verify if installer user has Administration rights
!macro VerifyUserIsAdmin
	UserInfo::GetAccountType
	pop $0
	${If} $0 != "admin" ;Require admin rights on NT4+
		messageBox mb_iconstop "Administrator rights required!"
		setErrorLevel 740 ;ERROR_ELEVATION_REQUIRED
		quit
	${EndIf}
!macroend

; Check if a dmd installer instance is already running
!macro OneInstanceOnly
	System::Call 'kernel32::CreateMutexA(i 0, i 0, t "dmd_installer_1362401722119187326") ?e'
	Pop $R0
	StrCmp $R0 0 +3
		MessageBox MB_OK|MB_ICONSTOP "An instance of ${DName} installer is already running"
		Abort
!macroend

; Write registry keys when installing
!macro WriteRegistryKeys
	; Computes the size of the installed files
	Call GetInstalledSize

	; Write installation dir in the registry
	WriteRegStr HKLM "SOFTWARE\${DName}" "Install Directory" "$INSTDIR"

	; Registry keys to make Windows uninstaller
	WriteRegStr HKLM "${ARP}" "DisplayName" "${DName}"
	WriteRegStr HKLM "${ARP}" "DisplayVersion" "${Version}"
	WriteRegStr HKLM "${ARP}" "UninstallString" "$INSTDIR\uninstall.exe"
	WriteRegStr HKLM "${ARP}" "DisplayIcon" "$INSTDIR\uninstall.exe"
	WriteRegStr HKLM "${ARP}" "Publisher" "${DPublisher}"
	WriteRegStr HKLM "${ARP}" "HelpLink" "http://dlang.org/"
	WriteRegDWORD HKLM "${ARP}" "EstimatedSize" "$GetInstalledSize.total"
	WriteRegDWORD HKLM "${ARP}" "NoModify" 1
	WriteRegDWORD HKLM "${ARP}" "NoRepair" 1
	WriteUninstaller "uninstall.exe"
!macroend

;--------------------------------------------------------
; Interface settings
;--------------------------------------------------------

; Confirmation when exiting the installer
;!define MUI_ABORTWARNING

!define MUI_ICON "installer-icon.ico"
!define MUI_UNICON "uninstaller-icon.ico"

;--------------------------------------------------------
; Langauge selection dialog settings
;--------------------------------------------------------

; Remember the installation language
;!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"
;!define MUI_LANGDLL_REGISTRY_KEY "Software\${DName}"
;!define MUI_LANGDLL_REGISTRY_VALUENAME "Installer Language"

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

	; Create command line batch file
	FileOpen $0 "$INSTDIR\dmdvars.bat" w
	FileWrite $0 "@echo.$\n"
	FileWrite $0 "@echo Setting up environment for using dmd from %~dp0dmd2\windows\bin.$\n"
	FileWrite $0 "@set PATH=%~dp0dmd2\windows\bin;%PATH%$\n"
	FileClose $0

	; Write registry keys
	!insertmacro WriteRegistryKeys

SectionEnd

Section "cURL support" cURLFiles

	; This section is mandatory
	;SectionIn RO

	SetOutPath $INSTDIR

	; curl directory to include
	File /r curl/dmd2

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

	; Create command line batch file
	FileOpen $0 "$INSTDIR\dmcvars.bat" w
	FileWrite $0 "@echo.$\n"
	FileWrite $0 "@echo Setting up environment for using dmc from %~dp0dm\bin.$\n"
	FileWrite $0 "@set PATH=%~dp0dm\bin;%PATH%$\n"
	FileClose $0

	; Write registry keys
	!insertmacro WriteRegistryKeys

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
	CreateShortCut "$SMPROGRAMS\${DName} v${Version}\dmc Command Prompt.lnk" '%comspec%' \
	'/k ""$INSTDIR\dmcvars.bat""' "" "" SW_SHOWNORMAL "" "Open dmc Command Prompt"


	CreateShortCut "$SMPROGRAMS\${DName} v${Version}\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0

SectionEnd

;--------------------------------------------------------
; Installer functions
;--------------------------------------------------------

Function .onInit

	SetShellVarContext all

	; Verify if user is Administrator
	!insertmacro VerifyUserIsAdmin

	; Check if a dmd installer instance is already running
	!insertmacro OneInstanceOnly

	; This is commented because there's only one language
	; (for now)
	;!insertmacro MUI_LANGDLL_DISPLAY

	; Force install without uninstall
	; Usefull if uninstall is broken
	${GetParameters} $R0
	StrCmp $R0 "/F" done

	; Remove if dmd is already installed
	ReadRegStr $R0 HKLM "${ARP}" "UninstallString"
	StrCmp $R0 "" done

	ReadRegStr $4 HKLM "${ARP}" "DisplayName"
	ReadRegStr $5 HKLM "${ARP}" "DisplayVersion"
	MessageBox MB_OKCANCEL|MB_ICONQUESTION \
	"$4 v$5 is installed on your system$\n$\nPress 'OK' to replace by ${DName} v${Version}" \
	IDOK uninst
	Abort

	uninst:
		; Run uninstaller fron installed directory
		ExecWait '$R0 /IC False _?=$INSTDIR' $I
		; Exit if uninstaller is cancelled by user
		StrCmp $I 0 +2
		Abort
		; Remove in background the remaining uninstaller program itself
		ExecWait '$R0 /IC False /S'

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
		${If} $R1 == ${SF_RO}
			!insertmacro SetSectionFlag ${cURLFiles} ${SF_SELECTED}
		${EndIf}
		${If} $R2 == ${SF_RO}
			!insertmacro SetSectionFlag ${AddDmdToPath} ${SF_SELECTED}
		${EndIf}
		!insertmacro ClearSectionFlag ${cURLFiles} ${SF_RO}
		!insertmacro ClearSectionFlag ${AddDmdToPath} ${SF_RO}
	${Else}
		!insertmacro ClearSectionFlag ${cURLFiles} ${SF_SELECTED}
		!insertmacro SetSectionFlag ${cURLFiles} ${SF_RO}
		!insertmacro ClearSectionFlag ${AddDmdToPath} ${SF_SELECTED}
		!insertmacro SetSectionFlag ${AddDmdToPath} ${SF_RO}
	${EndIf}

	${If} ${SectionIsSelected} ${DmcFiles}
		${If} $R3 == ${SF_RO}
			!insertmacro SetSectionFlag ${AddDmcToPath} ${SF_SELECTED}
		${EndIf}
		!insertmacro ClearSectionFlag ${AddDmcToPath} ${SF_RO}
	${Else}
		!insertmacro ClearSectionFlag ${AddDmcToPath} ${SF_SELECTED}
		!insertmacro SetSectionFlag ${AddDmcToPath} ${SF_RO}
	${EndIf}

	GetDlgItem $1 $HWNDPARENT 1

	${IfNot} ${SectionIsSelected} ${DmdFiles}
		${IfNot} ${SectionIsSelected} ${DmcFiles}
			!insertmacro ClearSectionFlag ${StartMenuItems} ${SF_SELECTED}
			!insertmacro SetSectionFlag ${StartMenuItems} ${SF_RO}
			EnableWindow $1 0
		${Else}
			${If} $R4 == ${SF_RO}
				!insertmacro SetSectionFlag ${StartMenuItems} ${SF_SELECTED}
			${EndIf}
			!insertmacro ClearSectionFlag ${StartMenuItems} ${SF_RO}
			EnableWindow $1 1
		${EndIf}
	${Else}
		${If} $R4 == ${SF_RO}
			!insertmacro SetSectionFlag ${StartMenuItems} ${SF_SELECTED}
		${EndIf}
		!insertmacro ClearSectionFlag ${StartMenuItems} ${SF_RO}
		EnableWindow $1 1
	${EndIf}

FunctionEnd

; Contains descriptions of components and other stuff
!include installer_descriptions.nsh

;--------------------------------------------------------
; Uninstaller
;--------------------------------------------------------

Section "Uninstall"

	; Remove directories to path (for all users)
	; (if for the current user, use HKCU)
	${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\dm\bin"
	${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\dmd2\windows\bin"

	; Remove stuff from registry
	DeleteRegKey HKLM "${ARP}"
	DeleteRegKey HKLM "SOFTWARE\${DName}"

	; This is for deleting the remembered language of the installation
	;DeleteRegKey HKCU "Software\${DName}"

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
	RMDir /r /REBOOTOK "$SMPROGRAMS\${DName} v${Version}"
	RMDir /r /REBOOTOK "$INSTDIR\dm"
	RMDir /r /REBOOTOK "$INSTDIR\dmd2"
	RMDir "$INSTDIR"

SectionEnd

;--------------------------------------------------------
; Uninstaller functions
;--------------------------------------------------------

Function un.onInit

	SetShellVarContext all

	; Verify if user is Administrator
	!insertmacro VerifyUserIsAdmin

	; Check if a dmd installer instance is already running
	; Do not check if "/IC False" argument is passed to uninstaller
	${GetOptions} $CMDLINE "/IC" $InstanceCheck
	${IfNot} "$InstanceCheck" == "False"
		!insertmacro OneInstanceOnly
	${EndIf}

	; Ask language before starting the uninstall

	; This is commented because there's only one language
	; (for now)
	;!insertmacro MUI_UNGETLANGUAGE

FunctionEnd

