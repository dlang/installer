@setlocal
@echo on

:: Also See: https://www.appveyor.com/docs/build-environment
SET ROOT=%CD%
SET ORIG_PATH=%PATH%

mkdir "%ROOT%\artifacts"
set ARTIFACT=libcurl-%CURL_VER%-WinSSL-zlib-x86-x64.zip

REM Stop early if the artifact already exists
powershell -Command "Invoke-WebRequest downloads.dlang.org/other/%ARTIFACT% -OutFile %ROOT%\artifacts\%ARTIFACT%" && exit /B 0

:: --------------------------------------------------------------------
:: Download and Unpack

powershell -Command "Invoke-WebRequest https://zlib.net/zlib-%ZLIB_VER%.tar.xz -OutFile zlib.tar.xz" || exit /B 1
powershell -Command "Invoke-WebRequest https://curl.haxx.se/download/curl-%CURL_VER%.tar.xz -OutFile curl.tar.xz" || exit /B 1
powershell -Command "Invoke-WebRequest http://ftp.digitalmars.com/bup.zip -OutFile bup.zip" || exit /B 1
set PEXPORTS_URL=https://sourceforge.net/projects/mingw/files/MinGW/Extension/pexports/pexports-%PEXPORTS_VER%/pexports-%PEXPORTS_VER%-mingw32-bin.tar.xz
set PEXPORTS_REDIRECT=-UserAgent [Microsoft.PowerShell.Commands.PSUserAgent]::FireFox
powershell -Command "Invoke-WebRequest %PEXPORTS_URL% -OutFile pexports.tar.xz %PEXPORTS_REDIRECT%" || exit /B 1
powershell -Command "Invoke-WebRequest https://sourceforge.mirrorservice.org/m/mi/mingw-w64/Toolchains%%20targetting%%20Win32/Personal%%20Builds/mingw-builds/8.1.0/threads-posix/dwarf/i686-8.1.0-release-posix-dwarf-rt_v6-rev0.7z -OutFile mingw32.7z" || exit /B 1

:: e.g. from git installation
dos2unix "%ROOT%\windows\build_curl.sha256sums"
sha256sum -c "%ROOT%\windows\build_curl.sha256sums" || exit /B 1

7z x zlib.tar.xz || exit /B 1
7z x zlib.tar || exit /B 1
7z x curl.tar.xz || exit /B 1
7z x curl.tar || exit /B 1
7z x bup.zip || exit /B 1
7z x pexports.tar.xz || exit /B 1
7z x pexports.tar || exit /B 1
7z x mingw32.7z || exit /B 1

move zlib-%ZLIB_VER% zlib
move curl-%CURL_VER% curl

SET ZLIB_PATH=%ROOT%\zlib

:: --------------------------------------------------------------------
:: Build x64 DLL and import libs

call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x64
cd %ROOT%
echo on

mingw32-make -C zlib -f win32\Makefile.gcc || exit /B 1
mingw32-make -C curl\lib -f Makefile.m32 CFG=mingw32-winssl-zlib-ipv6 "LDFLAGS=-static -m64" ARCH=w64 CURL_CFLAG_EXTRAS=-DDONT_USE_RECV_BEFORE_SEND_WORKAROUND || exit /B 1
strip -s curl\lib\libcurl.dll

mkdir dmd2\windows\bin64 dmd2\windows\lib64
copy curl\lib\libcurl.dll dmd2\windows\bin64
bin\pexports curl\lib\libcurl.dll > curl.def || exit /B 1
lib /MACHINE:X64 /DEF:curl.def /OUT:dmd2\windows\lib64\curl.lib || exit /B 1
del dmd2\windows\lib64\curl.exp

mingw32-make -C zlib -fwin32/Makefile.gcc clean
mingw32-make -C curl\lib -f Makefile.m32 clean

:: --------------------------------------------------------------------
:: Build x86 DLL and import libs

call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x86
cd %ROOT%
echo on
set PATH=%ROOT%\mingw32\bin;%PATH%

mingw32-make -C zlib -f win32\Makefile.gcc || exit /B 1
mingw32-make -C curl\lib -f Makefile.m32 CFG=mingw32-winssl-zlib-ipv6 "LDFLAGS=-static -m32" ARCH=w32 CURL_CFLAG_EXTRAS=-DDONT_USE_RECV_BEFORE_SEND_WORKAROUND || exit /B 1
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
:: Zip it up

7z a %ROOT%\artifacts\%ARTIFACT% dmd2
