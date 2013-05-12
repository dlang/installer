;------------------------------------------------------------
; Defines
;------------------------------------------------------------

!define DPublisher "Digital Mars"
!define DProduct "D Compiler"
!define DName "${DPublisher} ${DProduct}"
!define ARP "Software\Microsoft\Windows\CurrentVersion\Uninstall\${DName}"

;------------------------------------------------------------
; Includes
;------------------------------------------------------------

!include "MUI2.nsh"
!include "EnvVarUpdate.nsh"
!include "FileFunc.nsh"
!include "Sections.nsh"
!include "LogicLib.nsh"

;------------------------------------------------------------
; Variables
;------------------------------------------------------------

Var GetInstalledSize.total
Var I
Var J
Var K
Var InstanceCheck

;------------------------------------------------------------
; General definitions
;------------------------------------------------------------

; Requested execution level for Windows 7
RequestExecutionLevel admin

; Name of the installer
Name "${DName} v${Version}"

; Name of the output file of the installer
OutFile "${ExeFile}"

; Where the program will be installed
InstallDir "C:\dmd"

; Take the instalation directory from the registry, if possible
InstallDirRegKey HKLM "SOFTWARE\${DName}" "Install Directory"

; This is so no one can corrupt the installer
CRCCheck force

; Compress with lzma algorithm
SetCompressor /SOLID lzma

;------------------------------------------------------------
; Functions definition
;------------------------------------------------------------

; Return the total size of the selected (installed) sections, formated as DWORD
; Assumes no more than 1024 sections are defined
Function GetInstalledSize
	StrCpy $GetInstalledSize.total 0
	${ForEach} $I 0 1024 + 1
		${if} ${SectionIsSelected} $I
			SectionGetSize $I $J
			IntOp $GetInstalledSize.total $GetInstalledSize.total + $J
		${Endif}
	${Next}
	IntFmt $GetInstalledSize.total "0x%08X" $GetInstalledSize.total
FunctionEnd

;------------------------------------------------------------
; Macros definition
;------------------------------------------------------------

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
	System::Call 'kernel32::CreateMutexA(i 0, i 0, t "digital_mars_d_compiler_installer") ?e'
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

	; Registry keys for dmd uninstaller
	WriteRegStr HKLM "${ARP}" "DisplayName" "${DName}"
	WriteRegStr HKLM "${ARP}" "DisplayVersion" "${Version}"
	WriteRegStr HKLM "${ARP}" "UninstallString" "$INSTDIR\uninstall.exe"
	WriteRegStr HKLM "${ARP}" "DisplayIcon" "$INSTDIR\uninstall.exe"
	WriteRegStr HKLM "${ARP}" "Publisher" "${DPublisher}"
	WriteRegStr HKLM "${ARP}" "HelpLink" "http://dlang.org/"
	WriteRegDWORD HKLM "${ARP}" "EstimatedSize" "$GetInstalledSize.total"
	WriteRegDWORD HKLM "${ARP}" "NoModify" 1
	WriteRegDWORD HKLM "${ARP}" "NoRepair" 1

	WriteUninstaller "$INSTDIR\uninstall.exe"
!macroend

;------------------------------------------------------------
; Interface settings
;------------------------------------------------------------

; Confirmation when exiting the installer
;!define MUI_ABORTWARNING

!define MUI_ICON "installer-icon.ico"
!define MUI_UNICON "uninstaller-icon.ico"

;------------------------------------------------------------
; Installer pages
;------------------------------------------------------------

!define MUI_WELCOMEFINISHPAGE_BITMAP "installer_image.bmp"
!insertmacro MUI_PAGE_WELCOME

; Define function to set "next" button state when loading "components" page.
!define MUI_PAGE_CUSTOMFUNCTION_SHOW SetNextButton
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

;------------------------------------------------------------
; Uninstaller pages
;------------------------------------------------------------

!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

;------------------------------------------------------------
; The languages
;------------------------------------------------------------

!insertmacro MUI_LANGUAGE "English"

;------------------------------------------------------------
; Reserve files needed by the installation
;------------------------------------------------------------

!insertmacro MUI_RESERVEFILE_LANGDLL

;------------------------------------------------------------
; Required section: main program files,
; registry entries, etc.
;------------------------------------------------------------

SectionGroup /e "dmd"

Section "-dmd" DmdFiles

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

	CreateDirectory "$SMPROGRAMS\${DName}"

	; install dmd documentation and command prompt
	SectionGetFlags ${DmdFiles} $0
	IntOp $0 $0 & ${SF_SELECTED}
	IntCmp $0 ${SF_SELECTED} +1 +3
	CreateShortCut "$SMPROGRAMS\${DName}\dmd Documentation.lnk" \
	"$INSTDIR\dmd2\html\d\index.html" "" "$INSTDIR\dmd2\html\d\index.html" 0
	CreateShortCut "$SMPROGRAMS\${DName}\dmd Command Prompt.lnk" '%comspec%' \
	'/k ""$INSTDIR\dmdvars.bat""' "" "" SW_SHOWNORMAL "" "Open dmd Command Prompt"

	; install dmc command prompt
	SectionGetFlags ${DmcFiles} $0
	IntOp $0 $0 & ${SF_SELECTED}
	IntCmp $0 ${SF_SELECTED} +1 +2
	CreateShortCut "$SMPROGRAMS\${DName}\dmc Command Prompt.lnk" '%comspec%' \
	'/k ""$INSTDIR\dmcvars.bat""' "" "" SW_SHOWNORMAL "" "Open dmc Command Prompt"


	CreateShortCut "$SMPROGRAMS\${DName}\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0

SectionEnd

;------------------------------------------------------------
; Installer functions
;------------------------------------------------------------

Function .onInit

	SetShellVarContext all

	; Verify if user is Administrator
	!insertmacro VerifyUserIsAdmin

	; Check if a dmd installer instance is already running
	!insertmacro OneInstanceOnly

	; Force install without uninstall
	; Usefull if uninstall is broken
	${GetParameters} $R0
	StrCmp $R0 "/f" done


	; Remove previous dmd installation if any
	; this section is for previous dmd installer only
	ReadRegStr $R5 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\D" "UninstallString"
	ReadRegStr $R6 HKLM "SOFTWARE\D" "Install_Dir"
	StrCmp $R5 "" done2
	MessageBox MB_OKCANCEL|MB_ICONQUESTION \
	"A previous DMD is installed on your system$\n$\nPress 'OK' to replace by ${DName} v${Version}" \
	IDOK +2
	Abort
	ClearErrors
	; Run uninstaller fron installed directory
	ExecWait '$R5 /S _?=$R6' $K
	; Exit if uninstaller return an error
	IfErrors 0 +3
		MessageBox MB_OK|MB_ICONSTOP \
		"An error occurred when removing DMD$\n$\nRun 'dmd-${Version}.exe /f' to force install ${DName} v${Version}"
		Abort
	; Remove in background the remaining uninstaller program itself
	Sleep 1000
	Exec '$R5 /S'
	MessageBox MB_OK|MB_ICONINFORMATION "Previous DMD uninstalled"

	done2:
	; End of removing previous dmd installation section


	; Remove if dmd is already installed
	ReadRegStr $R0 HKLM "${ARP}" "UninstallString"
	StrCmp $R0 "" done

	ReadRegStr $I HKLM "${ARP}" "DisplayName"
	ReadRegStr $J HKLM "${ARP}" "DisplayVersion"
	MessageBox MB_OKCANCEL|MB_ICONQUESTION \
	"$I v$J is installed on your system$\n$\nPress 'OK' to replace by ${DName} v${Version}" \
	IDOK uninst
	Abort

	uninst:
		ClearErrors
		; Run uninstaller fron installed directory
		ExecWait '$R0 /IC False _?=$INSTDIR' $K
		; Exit if uninstaller return an error
		IfErrors 0 +3
			MessageBox MB_OK|MB_ICONSTOP \
			"An error occurred when removing $I v$J$\n$\nRun 'dmd-${Version}.exe /f' to force install ${DName} v${Version}"
			Abort
		; Exit if uninstaller is cancelled by user
		StrCmp $K 0 +2
			Abort
		; Remove in background the remaining uninstaller program itself
		Exec '$R0 /IC False /S'

	done:

FunctionEnd

;------------------------------------------------------------
; Enable and disable "sections" and "next" button
;------------------------------------------------------------

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
			; disable "next" button
			EnableWindow $1 0
		${Else}
			; enable "next" button
			EnableWindow $1 1
		${EndIf}
	${Else}
		; enable "next" button
		EnableWindow $1 1
	${EndIf}

FunctionEnd

; Contains descriptions of components and other stuff
!include installer_descriptions.nsh

;------------------------------------------------------------
; Set "next" button state when entering "Components" page
;------------------------------------------------------------

Function SetNextButton

	Call .onSelChange

FunctionEnd

;------------------------------------------------------------
; Uninstaller
;------------------------------------------------------------

Section "Uninstall"

	; Remove directories to path (for all users)
	; (if for the current user, use HKCU)
	${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\dm\bin"
	${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\dmd2\windows\bin"

	; Remove stuff from registry
	DeleteRegKey HKLM "${ARP}"
	DeleteRegKey HKLM "SOFTWARE\${DName}"

	; Remove the uninstaller
	Delete $INSTDIR\uninstall.exe

	; Remove shortcuts
	Delete "$SMPROGRAMS\${DName}\dmd Documentation.lnk"
	Delete "$SMPROGRAMS\${DName}\dmd Command Prompt.lnk"
	Delete "$SMPROGRAMS\${DName}\dmc Command Prompt.lnk"
	Delete "$SMPROGRAMS\${DName}\Uninstall.lnk"

	; Remove files
	Delete "$INSTDIR\dmdvars.bat"
	Delete "$INSTDIR\dmcvars.bat"

	; Remove used directories
	RMDir /r /REBOOTOK "$SMPROGRAMS\${DName}"
	RMDir /r /REBOOTOK "$INSTDIR\dm"
	RMDir /r /REBOOTOK "$INSTDIR\dmd2"
	RMDir "$INSTDIR"

SectionEnd

;------------------------------------------------------------
; Uninstaller functions
;------------------------------------------------------------

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

FunctionEnd

