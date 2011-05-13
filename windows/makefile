# makefile to build dmd installer for windows

NSIS="\program files\nsis\makensis"

dinstaller.exe : dinstaller.nsi dinstaller_descriptions.nsh EnvVarUpdate.nsh makefile
	+$(NSIS) /DVersion1=1.068 /DVersion2=2.053 dinstaller.nsi

clean :
	del dinstaller.exe
