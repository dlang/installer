# makefile to build dmd installer for windows

V1=$(\cbx\VERSION1)
V2=$(\cbx\VERSION)

#NSIS="\program files\nsis\makensis"
NSIS="\program files (x86)\nsis\makensis"

dmd-$(V2).exe : dinstaller.nsi dinstaller_descriptions.nsh EnvVarUpdate.nsh makefile
	$(NSIS) /DVersion1=$(V1) /DVersion2=$(V2) dinstaller.nsi

clean :
	del dmd-$(V2).exe

install:
	\putty\pscp -i \.ssh\colossus.ppk dmd-$(V2).exe walter@digitalmars.com:/var/pub/digitalmars.com

# URL for dlang.org/download: /usr/local/www/dlang.org/data/download/
