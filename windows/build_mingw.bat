@setlocal
@echo on

set ROOT=%CD%
mkdir "%ROOT%\artifacts"

set TAG=mingw-libs-%MINGW_VER%
set ARTIFACT=%TAG%.zip
set ARTIFACTPATH=%ROOT%\artifacts\%ARTIFACT%
set GITHUB_RELEASE=https://github.com/dlang/installer/releases/download/%TAG%/%ARTIFACT%

REM Stop early if the artifact already exists
powershell -Command "Invoke-WebRequest %GITHUB_RELEASE% -OutFile %ARTIFACTPATH%" && exit /B 0

set DMD_URL=https://downloads.dlang.org/releases/2.x/%D_VERSION%/dmd.%D_VERSION%.windows.7z
echo DMD_URL=%DMD_URL%
powershell -Command "Invoke-WebRequest %DMD_URL% -OutFile dmd2.7z" || exit /B 1
7z x dmd2.7z || exit /B 1
set PATH=%ROOT%\dmd2\windows\bin;%PATH%

set MINGW_URL=https://netix.dl.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v%MINGW_VER%.tar.bz2
set USER_AGENT=[Microsoft.PowerShell.Commands.PSUserAgent]::FireFox

powershell -Command "Invoke-WebRequest %MINGW_URL% -OutFile mingw-w64.tar.bz2 -UserAgent %User_Agent%"  || exit /B 1

:: e.g. from git installation
dos2unix "%ROOT%\windows\build_mingw.sha256sums"
sha256sum -c "%ROOT%\windows\build_mingw.sha256sums" || exit /B 1

7z x mingw-w64.tar.bz2 || exit /B 1
7z x mingw-w64.tar || exit /B 1

move mingw-w64-v%MINGW_VER% mingw-w64

call "%VSINSTALLDIR%\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x86
@echo on
rem CWD might be changed by vcvars64.bat
cd %ROOT%\windows\mingw
dmd -run buildsdk.d x64 %ROOT%\mingw-w64 dmd2\windows\lib64\mingw || exit /B 1

call "%VSINSTALLDIR%\Common7\Tools\VsDevCmd.bat" -arch=x86
@echo on
cd %ROOT%\windows\mingw
dmd -run buildsdk.d x86 %ROOT%\mingw-w64 dmd2\windows\lib32mscoff\mingw || exit /B 1

md dmd2\windows\bin
copy "%WINDIR%\SysWow64\msvcr120.dll" dmd2\windows\bin
md dmd2\windows\bin64
copy "%WINDIR%\System32\msvcr120.dll" dmd2\windows\bin64

7z a "%ARTIFACTPATH%" dmd2\windows
