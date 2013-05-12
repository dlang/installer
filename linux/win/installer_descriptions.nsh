;--------------------------------------------------------
; English
;--------------------------------------------------------

; Sections

LangString DESC_DmdFiles ${LANG_ENGLISH} "Digital Mars D Programming Language compiler v${Version}"

LangString DESC_DmcFiles ${LANG_ENGLISH} "Digital Mars C/C++ compiler 8.50"

; Shortcuts
LangString SHORTCUT_Uninstall ${LANG_ENGLISH} "Uninstall"

;--------------------------------------------------------
; Assign texts to sections
;--------------------------------------------------------

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${DmdFiles} $(DESC_DmdFiles)
    !insertmacro MUI_DESCRIPTION_TEXT ${DmcFiles} $(DESC_DmcFiles)
!insertmacro MUI_FUNCTION_DESCRIPTION_END
