;--------------------------------------------------------
; English
;--------------------------------------------------------

; Sections
LangString DESC_Dmd2Files ${LANG_ENGLISH} "Digital Mars D version 2 compiler"
LangString DESC_cURLFiles ${LANG_ENGLISH} "Install DMD compatible libcurl"
LangString DESC_DetectMSVC ${LANG_ENGLISH} "Configure DMD to use the version of Visual C++ and Windows SDK that is installed"
LangString DESC_AddD2ToPath ${LANG_ENGLISH} "Modify the PATH environment variable so DMD can be used from any command prompt"
LangString DESC_Dmd1Files ${LANG_ENGLISH} "Digital Mars D version 1 compiler (discontinued)"
LangString DESC_DmcFiles ${LANG_ENGLISH} "Digital Mars C/C++ compiler"


; Shortcuts
LangString SHORTCUT_Uninstall ${LANG_ENGLISH} "Uninstall"

;--------------------------------------------------------
; Assign texts to sections
;--------------------------------------------------------

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${Dmd2Files} $(DESC_Dmd2Files)
    !insertmacro MUI_DESCRIPTION_TEXT ${cURLFiles} $(DESC_cURLFiles)
    !insertmacro MUI_DESCRIPTION_TEXT ${DetectMSVC} $(DESC_DetectMSVC)
    !insertmacro MUI_DESCRIPTION_TEXT ${AddD2ToPath} $(DESC_AddD2ToPath)
    !insertmacro MUI_DESCRIPTION_TEXT ${Dmd1Files} $(DESC_Dmd1Files)
    !insertmacro MUI_DESCRIPTION_TEXT ${DmcFiles} $(DESC_DmcFiles)
!insertmacro MUI_FUNCTION_DESCRIPTION_END
