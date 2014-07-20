;--------------------------------------------------------
; English
;--------------------------------------------------------

; Sections
LangString DESC_Dmd1Files ${LANG_ENGLISH} "Digital Mars D version 1 compiler"
LangString DESC_AddD1ToPath ${LANG_ENGLISH} "Modify the PATH environment variable so DMD can be used from any command prompt"


; Shortcuts
LangString SHORTCUT_Uninstall ${LANG_ENGLISH} "Uninstall"

;--------------------------------------------------------
; Assign texts to sections
;--------------------------------------------------------

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${Dmd1Files} $(DESC_Dmd1Files)
    !insertmacro MUI_DESCRIPTION_TEXT ${AddD1ToPath} $(DESC_AddD1ToPath)
!insertmacro MUI_FUNCTION_DESCRIPTION_END
