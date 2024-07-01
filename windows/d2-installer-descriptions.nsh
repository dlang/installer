;--------------------------------------------------------
; English
;--------------------------------------------------------

; Sections
LangString DESC_Dmd2Files ${LANG_ENGLISH} "Digital Mars D version 2 compiler"
LangString DESC_SMShortcuts ${LANG_ENGLISH} "Add Shortcuts to the Start Menu to start the command interpreter with adjusted environment"
LangString DESC_AddD2ToPath ${LANG_ENGLISH} "Modify the PATH environment variable so DMD can be used from any command prompt"

LangString DESC_VisualDDownload ${LANG_ENGLISH} "Visual Studio package providing both project management and language services. It works with Visual Studio 2008-2017 (and the free VS Shells)"


; Shortcuts
LangString SHORTCUT_Uninstall ${LANG_ENGLISH} "Uninstall"

;--------------------------------------------------------
; Assign texts to sections
;--------------------------------------------------------

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${Dmd2Files} $(DESC_Dmd2Files)
    !insertmacro MUI_DESCRIPTION_TEXT ${StartMenuShortcuts} $(DESC_SMShortcuts)
    !insertmacro MUI_DESCRIPTION_TEXT ${AddD2ToPath} $(DESC_AddD2ToPath)
    !insertmacro MUI_DESCRIPTION_TEXT ${VisualDDownload} $(DESC_VisualDDownload)
!insertmacro MUI_FUNCTION_DESCRIPTION_END
