# makefile to build dmd installer for windows

#NSIS="\program files\nsis\makensis"
NSIS="\program files (x86)\nsis\makensis"

dinstaller.exe : dinstaller.nsi dinstaller_descriptions.nsh EnvVarUpdate.nsh makefile
	$(NSIS) /DVersion1=1.076 /DVersion2=2.061 dinstaller.nsi

clean :
	del dinstaller.exe

install:
	\putty\pscp -i \.ssh\colossus.ppk dinstaller.exe walter@digitalmars.com:/var/pub/digitalmars.com

