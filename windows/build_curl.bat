@setlocal
@echo on

SET ROOT=%CD%
SET ORIG_PATH=%PATH%
SET MINGW_PATH=C:\tools\mingw32\bin
set USER_AGENT=[Microsoft.PowerShell.Commands.PSUserAgent]::FireFox

:: --------------------------------------------------------------------
:: Download and Unpack

powershell -Command "Invoke-WebRequest https://zlib.net/zlib-%ZLIB_VER%.tar.xz -OutFile zlib.tar.xz" || exit /B 1
powershell -Command "Invoke-WebRequest https://curl.haxx.se/download/curl-%CURL_VER%.tar.xz" -OutFile curl.tar.xz || exit /B 1
powershell -Command "Invoke-WebRequest http://ftp.digitalmars.com/bup.zip -OutFile bup.zip" || exit /B 1
powershell -Command "Invoke-WebRequest https://sourceforge.net/projects/mingw/files/MinGW/Extension/pexports/pexports-%PEXPORTS_VER%/pexports-%PEXPORTS_VER%-mingw32-bin.tar.xz -OutFile pexports.tar.xz -UserAgent %User_Agent%" || exit /B 1

:: e.g. from git installation
dos2unix "%ROOT%\windows/build_curl.sha256sums"
sha256sum -c "%ROOT%\windows/build_curl.sha256sums" || exit /B 1

7z x zlib.tar.xz || exit /B 1
7z x zlib.tar || exit /B 1
7z x curl.tar.xz || exit /B 1
7z x curl.tar || exit /B 1
7z x bup.zip || exit /B 1
7z x pexports.tar.xz || exit /B 1
7z x pexports.tar || exit /B 1

move zlib-%ZLIB_VER% zlib
move curl-%CURL_VER% curl

SET ZLIB_PATH=%ROOT%\zlib

:: --------------------------------------------------------------------
:: Build x86 DLL and import libs

choco install mingw --x86 --force --params "/exception:sjlj"

SET PATH=%MINGW_PATH%;%ORIG_PATH%
call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x86

mingw32-make -C zlib -f win32\Makefile.gcc || exit /B 1
mingw32-make -C curl\lib -f Makefile.m32 CFG=mingw32-winssl-zlib-ipv6 LDFLAGS=-static || exit /B 1
strip -s curl\lib\libcurl.dll

mkdir dmd2\windows\bin dmd2\windows\lib
copy curl\lib\libcurl.dll dmd2\windows\bin
dm\bin\implib /system dmd2\windows\lib\curl.lib curl\lib\libcurl.dll || exit /B 1
mkdir dmd2\windows\lib32mscoff
bin\pexports curl\lib\libcurl.dll > curl.def || exit /B 1
lib /MACHINE:X86 /DEF:curl.def /OUT:dmd2\windows\lib32mscoff\curl.lib || exit /B 1
del dmd2\windows\lib32mscoff\curl.exp

mingw32-make -C zlib -fwin32/Makefile.gcc clean
mingw32-make -C curl\lib -f Makefile.m32 clean

:: --------------------------------------------------------------------
:: Build x64 DLL and import libs

call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x86_amd64

SET PATH=%ORIG_PATH%

make -C zlib -f win32\Makefile.gcc || exit /B 1
make -C curl\lib -f Makefile.m32 CFG=mingw32-winssl-zlib-ipv6 LDFLAGS=-static || exit /B 1
strip -s curl\lib\libcurl.dll

mkdir dmd2\windows\bin64 dmd2\windows\lib64
copy curl\lib\libcurl.dll dmd2\windows\bin64
bin\pexports curl\lib\libcurl.dll > curl.def || exit /B 1
lib /MACHINE:X64 /DEF:curl.def /OUT:dmd2\windows\lib64\curl.lib || exit /B 1
del dmd2\windows\lib64\curl.exp

make -C zlib -fwin32/Makefile.gcc clean
make -C curl\lib -f Makefile.m32 clean



:: --------------------------------------------------------------------
:: Zip it up

mkdir "%ROOT%\artifacts"
7z a "%ROOT%\artifacts\libcurl-%CURL_VER%-WinSSL-zlib-x86-x64.zip" dmd2
