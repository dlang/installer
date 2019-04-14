@setlocal

set ROOT=%CD%

set DMD_URL=http://downloads.dlang.org/releases/2.x/%D_VERSION%/dmd.%D_VERSION%.windows.7z
echo DMD_URL=%DMD_URL%
powershell -Command "Invoke-WebRequest %DMD_URL% -OutFile dmd2.7z" || exit /B 1
7z x dmd2.7z || exit /B 1
set PATH=%ROOT%\dmd2\windows\bin;%PATH%

set MINGW_BASEURL=https://netix.dl.sourceforge.net/project/mingw/MinGW/Base/
set W32API_URL=%MINGW_BASEURL%/w32api/w32api-%MINGW_VER%/w32api-%MINGW_VER%-mingw32-src.tar.xz
set MINGWRT_URL=%MINGW_BASEURL%/mingwrt/mingwrt-%MINGW_VER%/mingwrt-%MINGW_VER%-mingw32-src.tar.xz
set USER_AGENT=[Microsoft.PowerShell.Commands.PSUserAgent]::FireFox

powershell -Command "Invoke-WebRequest %W32API_URL% -OutFile w32api.src.tar.xz -UserAgent %User_Agent%"  || exit /B 1
powershell -Command "Invoke-WebRequest %MINGWRT_URL% -OutFile mingwrt.src.tar.xz -UserAgent %User_Agent%"  || exit /B 1

:: e.g. from git installation
dos2unix "%ROOT%\windows\build_mingw.sha256sums"
sha256sum -c "%ROOT%\windows\build_mingw.sha256sums" || exit /B 1

7z x w32api.src.tar.xz || exit /B 1
7z x w32api.src.tar || exit /B 1

7z x mingwrt.src.tar.xz || exit /B 1
7z x mingwrt.src.tar || exit /B 1

move w32api-%MINGW_VER% w32api
move mingwrt-%MINGW_VER% mingwrt

cd windows\mingw
set w32api_lib=../../w32api/lib
set msvcrt_def_in=../../mingwrt/msvcrt-xref/msvcrt.def.in

call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x86_amd64
rem CWD might be changed by vcvars64.bat
cd %ROOT%\windows\mingw
dmd -run buildsdk.d x64 %w32api_lib% dmd2\windows\lib64\mingw %msvcrt_def_in% || exit /B 1

call "%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat" x86
cd %ROOT%\windows\mingw
dmd -run buildsdk.d x86 %w32api_lib% dmd2\windows\lib32mscoff\mingw %msvcrt_def_in% || exit /B 1

mkdir "%ROOT%\artifacts"
7z a %ROOT%\artifacts\mingw-libs-%MINGW_VER%.zip dmd2\windows
