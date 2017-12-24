;--------------------------------------------------------
; English
;--------------------------------------------------------

; Sections
LangString DESC_Dmd2Files ${LANG_ENGLISH} "Digital Mars D version 2 compiler"
LangString DESC_SMShortcuts ${LANG_ENGLISH} "Add Shortcuts to the Start Menu to start the command interpreter with adjusted environment"
LangString DESC_AddD2ToPath ${LANG_ENGLISH} "Modify the PATH environment variable so DMD can be used from any command prompt"

LangString DESC_VisualDDownload ${LANG_ENGLISH} "Visual Studio package providing both project management and language services. It works with Visual Studio 2008-2017 (and the free VS Shells)"
LangString DESC_DmcDownload ${LANG_ENGLISH} "Digital Mars C/C++ compiler"
LangString DESC_Dmd1Download ${LANG_ENGLISH} "Digital Mars D version 1 compiler (discontinued)"

LangString DESC_VCRedistx86 ${LANG_ENGLISH} "Microsoft Visual C++ 2010 x86 Redistributable (only selectable if not installed)"
LangString DESC_VCRedistx64 ${LANG_ENGLISH} "Microsoft Visual C++ 2010 x64 Redistributable (only selectable if not installed)"


; Shortcuts
LangString SHORTCUT_Uninstall ${LANG_ENGLISH} "Uninstall"

;--------------------------------------------------------
; Assign texts to sections
;--------------------------------------------------------

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${Dmd2Files} $(DESC_Dmd2Files)
    !insertmacro MUI_DESCRIPTION_TEXT ${StartMenuShortcuts} $(DESC_SMShortcuts)
    !insertmacro MUI_DESCRIPTION_TEXT ${AddD2ToPath} $(DESC_AddD2ToPath)
!ifdef Light
    !insertmacro MUI_DESCRIPTION_TEXT ${VCRedistributable86} $(DESC_VCRedistx86)
    !insertmacro MUI_DESCRIPTION_TEXT ${VCRedistributable64} $(DESC_VCRedistx64)
!else
    !insertmacro MUI_DESCRIPTION_TEXT ${VisualDDownload} $(DESC_VisualDDownload)
    !insertmacro MUI_DESCRIPTION_TEXT ${DmcDownload} $(DESC_DmcDownload)
    !insertmacro MUI_DESCRIPTION_TEXT ${Dmd1Download} $(DESC_Dmd1Download)
!endif
!insertmacro MUI_FUNCTION_DESCRIPTION_END
