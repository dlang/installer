;--------------------------------------------------------
; English
;--------------------------------------------------------

; Sections
LangString DESC_DmcFiles ${LANG_ENGLISH} "Digital Mars Compiler"


; Shortcuts
LangString SHORTCUT_Uninstall ${LANG_ENGLISH} "Uninstall"

;--------------------------------------------------------
; Assign texts to sections
;--------------------------------------------------------

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${DmcFiles} $(DESC_DmcFiles)
!insertmacro MUI_FUNCTION_DESCRIPTION_END
