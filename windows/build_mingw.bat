@setlocal

set ROOT=%CD%

echo b80b0c9d0158f9125e482b50fe00b70dde11d7a015ee687ca455fe2ea2ec8733 *w32api.src.tar.xz> sha256sums
echo 77233333f5440287840d134804bcecf3144ec3efc7fd7f7c6dce318e4e7146ee *mingwrt.src.tar.xz>> sha256sums

set MINGW_BASEURL=https://10gbps-io.dl.sourceforge.net/project/mingw/MinGW/Base
set W32API_URL=%MINGW_BASEURL%/w32api/w32api-%MINGW_VER%/w32api-%MINGW_VER%-mingw32-src.tar.xz
set MINGWRT_URL=%MINGW_BASEURL%/mingwrt/mingwrt-%MINGW_VER%/mingwrt-%MINGW_VER%-mingw32-src.tar.xz

appveyor DownloadFile %W32API_URL%  -FileName w32api.src.tar.xz  || exit /B 1
appveyor DownloadFile %MINGWRT_URL%  -FileName mingwrt.src.tar.xz  || exit /B 1

:: e.g. from git installation
sha256sum -c sha256sums || exit /B 1

7z x w32api.src.tar.xz || exit /B 1
7z x w32api.src.tar || exit /B 1

7z x mingwrt.src.tar.xz || exit /B 1
7z x mingwrt.src.tar || exit /B 1

move w32api-%MINGW_VER% w32api
move mingwrt-%MINGW_VER% mingwrt

cd windows\mingw
set w32api_lib=../../w32api/lib
set msvcrt_def_in=../../mingwrt/msvcrt-xref/msvcrt.def.in

call "c:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars64.bat"
rem CWD might be changed by vcvars64.bat
cd %ROOT%\windows\mingw
dmd -run buildsdk.d x64 %w32api_lib% lib64 %msvcrt_def_in% || exit /B 1

call "c:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Auxiliary\Build\vcvars32.bat"
cd %ROOT%\windows\mingw
dmd -run buildsdk.d x86 %w32api_lib% lib32mscoff %msvcrt_def_in% || exit /B 1

7z a %ROOT%\mingw-libs-%MINGW_VER%.zip lib64\*.* lib32mscoff\*.*
