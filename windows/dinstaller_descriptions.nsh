;--------------------------------------------------------
; English
;--------------------------------------------------------

; Sections
LangString DESC_Dmd1Files ${LANG_ENGLISH} "Digital Mars D Programming Language compiler ${Version1}"

LangString DESC_Dmd2Files ${LANG_ENGLISH} "Digital Mars D Programming Language compiler ${Version2}"

LangString DESC_DmcFiles ${LANG_ENGLISH} "Digital Mars C/C++ compiler 8.50"

; Shortcuts
LangString SHORTCUT_Uninstall ${LANG_ENGLISH} "Uninstall"

;--------------------------------------------------------
; Assign texts to sections
;--------------------------------------------------------

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${Dmd1Files} $(DESC_Dmd1Files)
    !insertmacro MUI_DESCRIPTION_TEXT ${Dmd2Files} $(DESC_Dmd2Files)
    !insertmacro MUI_DESCRIPTION_TEXT ${DmcFiles} $(DESC_DmcFiles)
!insertmacro MUI_FUNCTION_DESCRIPTION_END
